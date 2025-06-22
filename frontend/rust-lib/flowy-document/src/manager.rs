use std::sync::Arc;
use std::sync::Weak;
use std::time::Duration;

use collab::core::collab::{CollabOptions, DataSource};
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::lock::RwLock;
use collab::preclude::{ClientID, Collab};
use collab_document::blocks::DocumentData;
use collab_document::document::Document;
use collab_document::document_awareness::DocumentAwarenessState;
use collab_document::document_awareness::DocumentAwarenessUser;
use collab_document::document_data::default_document_data;
use collab_entity::CollabType;

use crate::document::{
  subscribe_document_changed, subscribe_document_snapshot_state, subscribe_document_sync_state,
};
use crate::entities::UpdateDocumentAwarenessStatePB;
use crate::reminder::DocumentReminderAction;
use collab_plugins::CollabKVDB;
use dashmap::DashMap;
use flowy_document_pub::cloud::DocumentCloudService;
use flowy_error::{ErrorCode, FlowyError, FlowyResult, internal_error};
use flowy_storage_pub::storage::{CreatedUpload, StorageService};
use flowy_user_pub::workspace_collab::adaptor::{CollabPersistenceImpl, WorkspaceCollabAdaptor};
use lib_infra::async_entry::AsyncEntry;
use lib_infra::util::timestamp;
use tracing::{event, instrument};
use tracing::{info, trace};
use uuid::Uuid;

pub trait DocumentUserService: Send + Sync {
  fn user_id(&self) -> Result<i64, FlowyError>;
  fn device_id(&self) -> Result<String, FlowyError>;
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError>;
  fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID;
}

/// Struct to hold commonly needed user context
struct UserContext {
  uid: i64,
  workspace_id: Uuid,
}

pub struct DocumentManager {
  pub user_service: Arc<dyn DocumentUserService>,
  collab_builder: Weak<WorkspaceCollabAdaptor>,
  documents: Arc<DashMap<Uuid, DocumentEntry>>,
  cloud_service: Arc<dyn DocumentCloudService>,
  storage_service: Weak<dyn StorageService>,
  base_removal_timeout: Duration,
}

impl Drop for DocumentManager {
  fn drop(&mut self) {
    trace!("[Drop] drop document manager");
  }
}

impl DocumentManager {
  pub fn new(
    user_service: Arc<dyn DocumentUserService>,
    collab_builder: Weak<WorkspaceCollabAdaptor>,
    cloud_service: Arc<dyn DocumentCloudService>,
    storage_service: Weak<dyn StorageService>,
  ) -> Self {
    let base_removal_timeout = if cfg!(debug_assertions) {
      Duration::from_secs(10) // Shorter timeout for debug builds
    } else {
      Duration::from_secs(60 * 10)
    };
    let manager = Self {
      user_service,
      collab_builder,
      documents: Arc::new(Default::default()),
      cloud_service,
      storage_service,
      base_removal_timeout,
    };

    // Start periodic cleanup task
    manager.start_periodic_cleanup();
    manager
  }

  pub fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID {
    self.user_service.collab_client_id(workspace_id)
  }

  /// Get user context (uid and workspace_id) - helper method to reduce duplication
  fn get_user_context(&self) -> FlowyResult<UserContext> {
    let uid = self.user_service.user_id()?;
    let workspace_id = self.user_service.workspace_id()?;
    Ok(UserContext { uid, workspace_id })
  }

  fn collab_builder(&self) -> FlowyResult<Arc<WorkspaceCollabAdaptor>> {
    self
      .collab_builder
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)
  }

  /// Get the encoded collab of the document.
  pub async fn get_encoded_collab_with_view_id(&self, doc_id: &Uuid) -> FlowyResult<EncodedCollab> {
    let UserContext { uid, workspace_id } = self.get_user_context()?;
    let doc_state =
      CollabPersistenceImpl::new(self.user_service.collab_db(uid)?, uid, workspace_id)
        .into_data_source();

    let document = self
      .collab_builder()?
      .create_document(workspace_id, *doc_id, doc_state)
      .await?;

    let encoded_collab = document
      .try_read()
      .unwrap()
      .encode_collab_v1(|collab| CollabType::Document.validate_require_data(collab))
      .map_err(internal_error)?;
    Ok(encoded_collab)
  }

  pub async fn initialize(&self, _uid: i64) -> FlowyResult<()> {
    trace!("initialize document manager");
    self.clear_all_documents().await;
    Ok(())
  }

  #[instrument(
    name = "document_initialize_after_sign_up",
    level = "debug",
    skip_all,
    err
  )]
  pub async fn initialize_after_sign_up(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await
  }

  pub async fn initialize_after_open_workspace(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await
  }

  #[instrument(level = "debug", skip_all, err)]
  pub async fn initialize_after_sign_in(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await
  }

  pub async fn handle_reminder_action(&self, action: DocumentReminderAction) {
    match action {
      DocumentReminderAction::Add { reminder: _ } => {},
      DocumentReminderAction::Remove { reminder_id: _ } => {},
      DocumentReminderAction::Update { reminder: _ } => {},
    }
  }

  fn persistence(&self) -> FlowyResult<CollabPersistenceImpl> {
    let UserContext { uid, workspace_id } = self.get_user_context()?;
    let db = self.user_service.collab_db(uid)?;
    Ok(CollabPersistenceImpl::new(db, uid, workspace_id))
  }

  pub async fn get_document_data(&self, doc_id: &Uuid) -> FlowyResult<DocumentData> {
    let document = self.get_document_internal(doc_id).await?;
    let document = document.read().await;
    document.get_document_data().map_err(internal_error)
  }

  pub async fn get_document_text(&self, doc_id: &Uuid) -> FlowyResult<String> {
    let document = self.get_document_internal(doc_id).await?;
    let document = document.read().await;
    let text = document.paragraphs().join("\n");
    Ok(text)
  }

  #[instrument(level = "info", skip(self, data))]
  pub async fn create_document(
    &self,
    _uid: i64,
    doc_id: &Uuid,
    data: Option<DocumentData>,
  ) -> FlowyResult<()> {
    if self.is_doc_exist(doc_id).await.unwrap_or(false) {
      Err(FlowyError::new(
        ErrorCode::RecordAlreadyExists,
        format!("document {} already exists", doc_id),
      ))
    } else {
      let workspace_id = self.user_service.workspace_id()?;
      let client_id = self.user_service.collab_client_id(&workspace_id);
      let encoded_collab = doc_state_from_document_data(doc_id, data, client_id).await?;
      let document = self
        .collab_builder()?
        .create_document(workspace_id, *doc_id, encoded_collab.into())
        .await?;

      let document_entry = DocumentEntry::new_with_resource(*doc_id, document.clone());
      self.documents.insert(*doc_id, document_entry);
      self.setup_document_subscriptions(doc_id, &document).await;
      Ok(())
    }
  }

  #[instrument(level = "debug", skip(self))]
  pub async fn open_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    self.get_document_internal(doc_id).await
  }

  pub async fn close_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    if let Some(entry) = self.documents.get(doc_id) {
      Self::clean_document_awareness(&entry).await;
    }
    Ok(())
  }

  /// Helper function to clean document awareness state
  async fn clean_document_awareness(entry: &DocumentEntry) {
    if let Some(document) = entry.get_resource().await {
      let mut lock = document.write().await;
      lock.clean_awareness_local_state();
    }
  }

  pub async fn delete_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    let UserContext { uid, workspace_id } = self.get_user_context()?;
    if let Some(db) = self.user_service.collab_db(uid)?.upgrade() {
      db.delete_doc(uid, &workspace_id.to_string(), &doc_id.to_string())
        .await?;
      // When deleting a document, we need to remove it from the cache.
      self.documents.remove(doc_id);
    }
    Ok(())
  }

  async fn setup_document_subscriptions(&self, doc_id: &Uuid, document: &Arc<RwLock<Document>>) {
    let mut lock = document.write().await;
    subscribe_document_changed(doc_id, &mut lock);
    subscribe_document_snapshot_state(&lock);
    subscribe_document_sync_state(&lock);
  }

  async fn get_document_internal(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    let entry = self.documents.get(doc_id).map(|e| e.value().clone());
    // Check if we have an active document
    if let Some(entry) = entry {
      if let Some(doc) = entry.get_resource().await {
        return Ok(doc);
      }
    }
    self.create_document_instance(doc_id).await
  }

  async fn clear_all_documents(&self) {
    trace!("[DocumentManager]: Clearing all documents");
    for entry in self.documents.iter() {
      Self::clean_document_awareness(entry.value()).await;
    }
    self.documents.clear();
  }

  #[instrument(level = "debug", skip_all, err)]
  pub async fn set_document_awareness_local_state(
    &self,
    doc_id: &Uuid,
    state: UpdateDocumentAwarenessStatePB,
  ) -> FlowyResult<bool> {
    let uid = self.user_service.user_id()?;
    let device_id = self.user_service.device_id()?;
    if let Ok(doc) = self.editable_document(doc_id).await {
      let doc = doc.write().await;
      let user = DocumentAwarenessUser { uid, device_id };
      let selection = state.selection.map(|s| s.into());
      let state = DocumentAwarenessState {
        version: 1,
        user,
        selection,
        metadata: state.metadata,
        timestamp: timestamp(),
      };
      doc.set_awareness_local_state(state);
      return Ok(true);
    }
    Ok(false)
  }

  #[instrument(level = "debug", skip_all, err)]
  pub async fn upload_file(
    &self,
    workspace_id: String,
    document_id: &str,
    local_file_path: &str,
  ) -> FlowyResult<CreatedUpload> {
    let storage_service = self.storage_service_upgrade()?;
    let upload = storage_service
      .create_upload(&workspace_id, document_id, local_file_path)
      .await?
      .0;
    Ok(upload)
  }

  pub async fn download_file(&self, local_file_path: String, url: String) -> FlowyResult<()> {
    let storage_service = self.storage_service_upgrade()?;
    storage_service.download_object(url, local_file_path)?;
    Ok(())
  }

  pub async fn delete_file(&self, url: String) -> FlowyResult<()> {
    let storage_service = self.storage_service_upgrade()?;
    storage_service.delete_object(url).await?;
    Ok(())
  }

  async fn is_doc_exist(&self, doc_id: &Uuid) -> FlowyResult<bool> {
    let UserContext { uid, workspace_id } = self.get_user_context()?;
    if let Some(collab_db) = self.user_service.collab_db(uid)?.upgrade() {
      trace!(
        "Check {}/Workspace, if {}/Document exist",
        workspace_id, doc_id
      );
      let is_exist = collab_db
        .is_exist(uid, &workspace_id.to_string(), &doc_id.to_string())
        .await?;
      Ok(is_exist)
    } else {
      Ok(false)
    }
  }

  fn storage_service_upgrade(&self) -> FlowyResult<Arc<dyn StorageService>> {
    let storage_service = self.storage_service.upgrade().ok_or_else(|| {
      FlowyError::internal().with_context("The file storage service is already dropped")
    })?;
    Ok(storage_service)
  }

  /// Only expose this method for testing
  #[cfg(debug_assertions)]
  pub fn get_cloud_service(&self) -> &Arc<dyn DocumentCloudService> {
    &self.cloud_service
  }
  /// Only expose this method for testing
  #[cfg(debug_assertions)]
  pub fn get_file_storage_service(&self) -> &Weak<dyn StorageService> {
    &self.storage_service
  }

  /// Return a document instance if the document is already opened.
  pub async fn editable_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    self.get_document_internal(doc_id).await
  }

  /// Returns Document for given object id
  /// If the document does not exist in local disk, try get the doc state from the cloud.
  /// If the document exists, open the document and cache it
  #[tracing::instrument(level = "info", skip(self), err)]
  async fn create_document_instance(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    let entry = {
      self
        .documents
        .entry(*doc_id)
        .or_insert_with(|| DocumentEntry::new_initializing(*doc_id))
        .clone()
    };

    if let Some(document) = entry.get_resource().await {
      trace!("document already initialized: {}", doc_id);
      return Ok(document);
    }

    if entry.should_initialize().await {
      trace!("Initializing document: {}", doc_id);
      match self.initialize_document(doc_id).await {
        Ok(document) => {
          entry.set_resource(document.clone()).await;
          Ok(document)
        },
        Err(err) => {
          entry
            .mark_initialization_failed(
              "Document entry disappeared during initialization".to_string(),
            )
            .await;

          if err.is_invalid_data() {
            self.delete_document(doc_id).await?;
          }
          Err(err)
        },
      }
    } else {
      entry
        .wait_for_initialization(Duration::from_secs(10))
        .await
        .map_err(|err| FlowyError::internal().with_context(err))
    }
  }

  // Helper method to create the document data and initialize subscriptions
  async fn initialize_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    let mut doc_state = self.persistence()?.into_data_source();
    // If the document does not exist in local disk, try get the doc state from the cloud. This happens
    // When user_device_a create a document and user_device_b open the document.
    if !self.is_doc_exist(doc_id).await? {
      info!(
        "{}/Document not found in local disk, try to get the doc state from the cloud",
        doc_id
      );
      doc_state = DataSource::DocStateV1(
        self
          .cloud_service
          .get_document_doc_state(doc_id, &self.user_service.workspace_id()?)
          .await?,
      );

      // the doc_state should not be empty if remote return the doc state without error.
      if doc_state.is_empty() {
        return Err(FlowyError::new(
          ErrorCode::RecordNotFound,
          format!("document {} not found", doc_id),
        ));
      }
    }

    event!(
      tracing::Level::DEBUG,
      "Initialize document: {}, workspace_id: {:?}",
      doc_id,
      self.user_service.workspace_id()
    );

    let workspace_id = self.user_service.workspace_id()?;
    let document = self
      .collab_builder()?
      .create_document(workspace_id, *doc_id, doc_state)
      .await?;
    self.setup_document_subscriptions(doc_id, &document).await;

    Ok(document)
  }

  /// Start a periodic cleanup task to remove old entries
  fn start_periodic_cleanup(&self) {
    let weak_documents = Arc::downgrade(&self.documents);
    let cleanup_interval = Duration::from_secs(30); // Check every 30 seconds
    let base_timeout = self.base_removal_timeout;
    tokio::spawn(async move {
      let mut interval = tokio::time::interval(cleanup_interval);
      interval.tick().await;

      loop {
        interval.tick().await;
        if let Some(documents) = weak_documents.upgrade() {
          let mut to_remove = Vec::new();
          let timeout = base_timeout;
          for entry in documents.iter() {
            let (doc_id, document_entry) = entry.pair();
            if document_entry.can_be_removed(timeout).await {
              trace!(
                "[Document]: Periodic cleanup document: {} can be removed, timeout duration: {}",
                doc_id,
                timeout.as_secs()
              );
              to_remove.push(*doc_id);
            }
          }

          // Remove expired entries
          for doc_id in to_remove {
            if let Some((_, entry)) = documents.remove(&doc_id) {
              if let Some(document) = entry.get_resource().await {
                let mut lock = document.write().await;
                lock.clean_awareness_local_state();
              }
            }
          }
        } else {
          break;
        }
      }
    });
  }
}

async fn doc_state_from_document_data(
  doc_id: &Uuid,
  data: Option<DocumentData>,
  client_id: ClientID,
) -> Result<EncodedCollab, FlowyError> {
  let doc_id = doc_id.to_string();
  let data = data.unwrap_or_else(|| {
    trace!(
      "{} document data is None, use default document data",
      doc_id.to_string()
    );
    default_document_data(&doc_id)
  });
  // spawn_blocking is used to avoid blocking the tokio thread pool if the document is large.
  let encoded_collab = tokio::task::spawn_blocking(move || {
    let options = CollabOptions::new(doc_id.clone(), client_id);
    let collab = Collab::new_with_options(CollabOrigin::Empty, options).map_err(internal_error)?;
    let document = Document::create_with_data(collab, data).map_err(internal_error)?;
    let encode_collab = document.encode_collab()?;
    Ok::<_, FlowyError>(encode_collab)
  })
  .await??;
  Ok(encoded_collab)
}

// Type alias for document-specific usage
type DocumentEntry = AsyncEntry<Arc<RwLock<Document>>, Uuid>;
