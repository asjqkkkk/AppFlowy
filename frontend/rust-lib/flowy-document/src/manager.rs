use std::sync::Arc;
use std::sync::Weak;
use std::time::{Duration, Instant};

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
use crate::entities::{
  DocumentSnapshotData, DocumentSnapshotMeta, DocumentSnapshotMetaPB, DocumentSnapshotPB,
};
use crate::reminder::DocumentReminderAction;
use collab_plugins::CollabKVDB;
use dashmap::DashMap;
use flowy_document_pub::cloud::DocumentCloudService;
use flowy_error::{ErrorCode, FlowyError, FlowyResult, internal_error};
use flowy_storage_pub::storage::{CreatedUpload, StorageService};
use flowy_user_pub::workspace_collab::adaptor::{CollabPersistenceImpl, WorkspaceCollabAdaptor};
use lib_infra::util::timestamp;
use tracing::{debug, event, instrument};
use tracing::{info, trace};
use uuid::Uuid;

pub trait DocumentUserService: Send + Sync {
  fn user_id(&self) -> Result<i64, FlowyError>;
  fn device_id(&self) -> Result<String, FlowyError>;
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError>;
  fn collab_client_id(&self, workspace_id: &Uuid) -> ClientID;
}

pub trait DocumentSnapshotService: Send + Sync {
  fn get_document_snapshot_metas(
    &self,
    document_id: &str,
  ) -> FlowyResult<Vec<DocumentSnapshotMeta>>;
  fn get_document_snapshot(&self, snapshot_id: &str) -> FlowyResult<DocumentSnapshotData>;
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
  snapshot_service: Arc<dyn DocumentSnapshotService>,
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
    snapshot_service: Arc<dyn DocumentSnapshotService>,
  ) -> Self {
    let manager = Self {
      user_service,
      collab_builder,
      documents: Arc::new(Default::default()),
      cloud_service,
      storage_service,
      snapshot_service,
      base_removal_timeout: Duration::from_secs(60),
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
      self.cache_and_initialize_document(*doc_id, document).await;
      Ok(())
    }
  }

  #[instrument(level = "debug", skip(self))]
  pub async fn open_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    self.get_document_internal(doc_id).await
  }

  pub async fn close_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    if let Some(mut entry) = self.documents.get_mut(doc_id) {
      Self::clean_document_awareness(&entry).await;
      entry.mark_for_removal();
    }
    Ok(())
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

  /// Helper function to clean document awareness state
  async fn clean_document_awareness(entry: &DocumentEntry) {
    if let Some(document) = entry.get_document() {
      let mut lock = document.write().await;
      lock.clean_awareness_local_state();
    }
  }

  async fn cache_and_initialize_document(&self, doc_id: Uuid, document: Arc<RwLock<Document>>) {
    let mut document_entry = DocumentEntry::new_initializing(doc_id);
    document_entry.set_document(document.clone());
    self.documents.insert(doc_id, document_entry);
    self.setup_document_subscriptions(&doc_id, &document).await;
  }

  async fn setup_document_subscriptions(&self, doc_id: &Uuid, document: &Arc<RwLock<Document>>) {
    let mut lock = document.write().await;
    subscribe_document_changed(doc_id, &mut lock);
    subscribe_document_snapshot_state(&lock);
    subscribe_document_sync_state(&lock);
  }

  async fn get_document_internal(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    // Check if we have an active document
    if let Some(mut entry) = self.documents.get_mut(doc_id) {
      entry.reactivate();
      if let Some(doc) = entry.get_document() {
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

  /// Return the list of snapshots of the document.
  pub async fn get_document_snapshot_meta(
    &self,
    document_id: &Uuid,
    _limit: usize,
  ) -> FlowyResult<Vec<DocumentSnapshotMetaPB>> {
    let metas = self
      .snapshot_service
      .get_document_snapshot_metas(document_id.to_string().as_str())?
      .into_iter()
      .map(|meta| DocumentSnapshotMetaPB {
        snapshot_id: meta.snapshot_id,
        object_id: meta.object_id,
        created_at: meta.created_at,
      })
      .collect::<Vec<_>>();

    Ok(metas)
  }

  pub async fn get_document_snapshot(&self, snapshot_id: &str) -> FlowyResult<DocumentSnapshotPB> {
    let snapshot = self
      .snapshot_service
      .get_document_snapshot(snapshot_id)
      .map(|snapshot| DocumentSnapshotPB {
        object_id: snapshot.object_id,
        encoded_v1: snapshot.encoded_v1,
      })?;
    Ok(snapshot)
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
    self.open_document(doc_id).await
  }

  /// Returns Document for given object id
  /// If the document does not exist in local disk, try get the doc state from the cloud.
  /// If the document exists, open the document and cache it
  #[tracing::instrument(level = "info", skip(self), err)]
  async fn create_document_instance(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    let should_initialize = self.try_start_document_initialization(doc_id);
    if !should_initialize {
      return self.wait_for_document_initialization(doc_id).await;
    }

    trace!("Initializing document: {}", doc_id);
    match self.initialize_document(doc_id).await {
      Ok(document) => {
        // Store the document in the entry
        if let Some(mut entry) = self.documents.get_mut(doc_id) {
          entry.set_document(document.clone());
          Ok(document)
        } else {
          // This shouldn't happen since we inserted it earlier
          Err(
            FlowyError::internal().with_context("Document entry disappeared during initialization"),
          )
        }
      },
      Err(err) => {
        if let Some(mut entry) = self.documents.get_mut(doc_id) {
          entry.mark_initialization_failed();
        }

        if err.is_invalid_data() {
          self.delete_document(doc_id).await?;
        }
        Err(err)
      },
    }
  }

  /// Try to start document initialization, returns true if this task should proceed
  fn try_start_document_initialization(&self, doc_id: &Uuid) -> bool {
    let entry = self.documents.entry(*doc_id);
    match entry {
      dashmap::mapref::entry::Entry::Occupied(mut entry) => {
        let document_entry = entry.get_mut();
        document_entry.reactivate();

        // If document already exists, no need to initialize
        if document_entry.get_document().is_some() {
          return false;
        }

        document_entry.try_start_initialize()
      },
      dashmap::mapref::entry::Entry::Vacant(entry) => {
        let holder = DocumentEntry::new_initializing(*doc_id);
        entry.insert(holder);
        true
      },
    }
  }

  async fn wait_for_document_initialization(
    &self,
    doc_id: &Uuid,
  ) -> FlowyResult<Arc<RwLock<Document>>> {
    tokio::time::sleep(Duration::from_secs(5)).await;
    if let Some(entry) = self.documents.get(doc_id) {
      if let Some(doc) = entry.get_document() {
        return Ok(doc);
      }
    }
    Err(FlowyError::internal().with_context("Document initialization failed"))
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
          let now = Instant::now();
          let mut to_remove = Vec::new();
          let timeout = base_timeout;

          for entry in documents.iter() {
            let (doc_id, document_entry) = entry.pair();
            if let Some(removal_time) = document_entry.removal_time() {
              if now.duration_since(removal_time) >= timeout {
                to_remove.push(*doc_id);
              }
            }
          }

          // Remove expired entries
          for doc_id in to_remove {
            if let Some((_, entry)) = documents.remove(&doc_id) {
              trace!("[Document]: Periodic cleanup removing document: {}", doc_id);
              if let Some(document) = entry.get_document() {
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

#[derive(Clone, Debug)]
enum DocumentState {
  Initializing,
  Active,
  PendingRemoval {
    removal_time: Instant,
    last_access: Instant,
  },
}

#[derive(Clone)]
struct DocumentEntry {
  id: Uuid,
  document: Option<Arc<RwLock<Document>>>,
  state: DocumentState,
}

impl DocumentEntry {
  fn new_initializing(id: Uuid) -> Self {
    Self {
      id,
      document: None,
      state: DocumentState::Initializing,
    }
  }

  fn mark_for_removal(&mut self) {
    debug!("[Document]: mark document as removal {}", self.id);
    let now = Instant::now();

    // Preserve last_access if already pending removal, otherwise use current time
    let last_access = match self.state {
      DocumentState::PendingRemoval { last_access, .. } => last_access,
      _ => now,
    };

    self.state = DocumentState::PendingRemoval {
      removal_time: now,
      last_access,
    };
  }

  fn reactivate(&mut self) {
    debug!("[Document]: Reactivating document {}", self.id);
    match self.state {
      DocumentState::PendingRemoval { .. } => {
        self.state = DocumentState::Active;
      },
      DocumentState::Initializing | DocumentState::Active => {
        // Keep current state
      },
    }
  }

  fn removal_time(&self) -> Option<Instant> {
    match self.state {
      DocumentState::Initializing => None,
      DocumentState::Active => None,
      DocumentState::PendingRemoval { removal_time, .. } => Some(removal_time),
    }
  }

  fn get_document(&self) -> Option<Arc<RwLock<Document>>> {
    self.document.clone()
  }

  fn set_document(&mut self, document: Arc<RwLock<Document>>) {
    self.document = Some(document);
    self.state = DocumentState::Active;
  }

  /// Try to mark as initializing. Returns true if successful (was not already initializing)
  fn try_start_initialize(&mut self) -> bool {
    match self.state {
      DocumentState::Initializing => false, // Already initializing
      DocumentState::Active => {
        self.state = DocumentState::Initializing;
        true
      },
      DocumentState::PendingRemoval { .. } => {
        self.state = DocumentState::Initializing;
        true
      },
    }
  }

  fn mark_initialization_failed(&mut self) {
    if let DocumentState::Initializing = self.state {
      self.state = DocumentState::Active;
    }
  }
}
