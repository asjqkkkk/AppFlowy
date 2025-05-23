use std::sync::Arc;
use std::sync::Weak;
use std::sync::atomic::{AtomicBool, Ordering};

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
use tracing::{event, instrument};
use tracing::{info, trace};
use uuid::Uuid;

pub trait DocumentUserService: Send + Sync {
  fn user_id(&self) -> Result<i64, FlowyError>;
  fn device_id(&self) -> Result<String, FlowyError>;
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn collab_db(&self, uid: i64) -> Result<Weak<CollabKVDB>, FlowyError>;
  fn collab_client_id(&self, workspace_id: &Uuid) -> Result<ClientID, FlowyError>;
}

pub trait DocumentSnapshotService: Send + Sync {
  fn get_document_snapshot_metas(
    &self,
    document_id: &str,
  ) -> FlowyResult<Vec<DocumentSnapshotMeta>>;
  fn get_document_snapshot(&self, snapshot_id: &str) -> FlowyResult<DocumentSnapshotData>;
}

pub struct DocumentManager {
  pub user_service: Arc<dyn DocumentUserService>,
  collab_builder: Weak<WorkspaceCollabAdaptor>,
  documents: Arc<DashMap<Uuid, DocumentHolder>>,
  removing_documents: Arc<DashMap<Uuid, Arc<RwLock<Document>>>>,
  cloud_service: Arc<dyn DocumentCloudService>,
  storage_service: Weak<dyn StorageService>,
  snapshot_service: Arc<dyn DocumentSnapshotService>,
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
    Self {
      user_service,
      collab_builder,
      documents: Arc::new(Default::default()),
      removing_documents: Arc::new(Default::default()),
      cloud_service,
      storage_service,
      snapshot_service,
    }
  }

  pub fn collab_client_id(&self, workspace_id: &Uuid) -> FlowyResult<ClientID> {
    self.user_service.collab_client_id(workspace_id)
  }

  fn collab_builder(&self) -> FlowyResult<Arc<WorkspaceCollabAdaptor>> {
    self
      .collab_builder
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)
  }

  /// Get the encoded collab of the document.
  pub async fn get_encoded_collab_with_view_id(&self, doc_id: &Uuid) -> FlowyResult<EncodedCollab> {
    let uid = self.user_service.user_id()?;
    let workspace_id = self.user_service.workspace_id()?;
    let doc_state =
      CollabPersistenceImpl::new(self.user_service.collab_db(uid)?, uid, workspace_id)
        .into_data_source();
    let collab = self.collab_for_document(doc_id, doc_state).await?;
    let encoded_collab = collab
      .try_read()
      .unwrap()
      .encode_collab_v1(|collab| CollabType::Document.validate_require_data(collab))
      .map_err(internal_error)?;
    Ok(encoded_collab)
  }

  pub async fn initialize(&self, _uid: i64) -> FlowyResult<()> {
    trace!("initialize document manager");
    self.documents.clear();
    self.removing_documents.clear();
    Ok(())
  }

  #[instrument(
    name = "document_initialize_after_sign_up",
    level = "debug",
    skip_all,
    err
  )]
  pub async fn initialize_after_sign_up(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await?;
    Ok(())
  }

  pub async fn initialize_after_open_workspace(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await?;
    Ok(())
  }

  #[instrument(level = "debug", skip_all, err)]
  pub async fn initialize_after_sign_in(&self, uid: i64) -> FlowyResult<()> {
    self.initialize(uid).await?;
    Ok(())
  }

  pub async fn handle_reminder_action(&self, action: DocumentReminderAction) {
    match action {
      DocumentReminderAction::Add { reminder: _ } => {},
      DocumentReminderAction::Remove { reminder_id: _ } => {},
      DocumentReminderAction::Update { reminder: _ } => {},
    }
  }

  fn persistence(&self) -> FlowyResult<CollabPersistenceImpl> {
    let uid = self.user_service.user_id()?;
    let workspace_id = self.user_service.workspace_id()?;
    let db = self.user_service.collab_db(uid)?;
    Ok(CollabPersistenceImpl::new(db, uid, workspace_id))
  }

  /// Create a new document.
  ///
  /// if the document already exists, return the existing document.
  /// if the data is None, will create a document with default data.
  #[instrument(level = "info", skip(self, data))]
  pub async fn create_document(
    &self,
    _uid: i64,
    doc_id: &Uuid,
    data: Option<DocumentData>,
  ) -> FlowyResult<EncodedCollab> {
    if self.is_doc_exist(doc_id).await.unwrap_or(false) {
      Err(FlowyError::new(
        ErrorCode::RecordAlreadyExists,
        format!("document {} already exists", doc_id),
      ))
    } else {
      let workspace_id = self.user_service.workspace_id()?;
      let client_id = self.user_service.collab_client_id(&workspace_id)?;
      let encoded_collab = doc_state_from_document_data(doc_id, data, client_id).await?;
      self
        .collab_builder()?
        .save_collab_to_disk(doc_id, encoded_collab.clone())?;

      // Send the collab data to server with a background task.
      let cloud_service = self.cloud_service.clone();
      let cloned_encoded_collab = encoded_collab.clone();
      let workspace_id = self.user_service.workspace_id()?;
      let doc_id = *doc_id;
      tokio::spawn(async move {
        let _ = cloud_service
          .create_document_collab(&workspace_id, &doc_id, cloned_encoded_collab)
          .await;
      });
      Ok(encoded_collab)
    }
  }

  async fn collab_for_document(
    &self,
    doc_id: &Uuid,
    data_source: DataSource,
  ) -> FlowyResult<Arc<RwLock<Document>>> {
    let workspace_id = self.user_service.workspace_id()?;
    let document = self
      .collab_builder()?
      .create_document(workspace_id, *doc_id, data_source, None)
      .await?;
    Ok(document)
  }

  /// Return a document instance if the document is already opened.
  pub async fn editable_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    // Check if the document is in the documents map
    if let Some(holder) = self.documents.get(doc_id) {
      if let Some(doc) = holder.get_document() {
        return Ok(doc);
      }
    }

    // Check if the document is in the removing_documents map
    if let Some(doc) = self.restore_document_from_removing(doc_id) {
      return Ok(doc);
    }

    Err(FlowyError::internal().with_context("Call open document first"))
  }

  /// Returns Document for given object id
  /// If the document does not exist in local disk, try get the doc state from the cloud.
  /// If the document exists, open the document and cache it
  #[tracing::instrument(level = "info", skip(self), err)]
  async fn create_document_instance(
    &self,
    doc_id: &Uuid,
    enable_sync: bool,
  ) -> FlowyResult<Arc<RwLock<Document>>> {
    let entry = self.documents.entry(*doc_id);
    let should_initialize = match entry {
      dashmap::mapref::entry::Entry::Occupied(entry) => entry.get().try_start_initialize(),
      dashmap::mapref::entry::Entry::Vacant(entry) => {
        let holder = DocumentHolder::new();
        holder.is_initializing.store(true, Ordering::Release);
        entry.insert(holder);
        true
      },
    };

    if !should_initialize {
      tokio::time::sleep(std::time::Duration::from_secs(5)).await;
      if let Some(holder) = self.documents.get(doc_id) {
        if let Some(doc) = holder.get_document() {
          return Ok(doc);
        }
      }
      // If we still don't have a document, something went wrong with initialization
      return Err(FlowyError::internal().with_context("Document initialization failed"));
    }

    // Proceed with document creation - holder is now marked as initializing
    trace!("Initializing document: {}", doc_id);
    match self.create_document_data(doc_id).await {
      Ok(document) => {
        // Store the document in the holder
        if let Some(mut holder) = self.documents.get_mut(doc_id) {
          holder.set_document(document.clone());
          Ok(document)
        } else {
          // This shouldn't happen since we inserted it earlier
          Err(
            FlowyError::internal()
              .with_context("Document holder disappeared during initialization"),
          )
        }
      },
      Err(err) => {
        if let Some(holder) = self.documents.get_mut(doc_id) {
          holder.is_initializing.store(false, Ordering::Release);
        }

        if err.is_invalid_data() {
          self.delete_document(doc_id).await?;
        }
        Err(err)
      },
    }
  }

  // Helper method to create the document data and initialize subscriptions
  async fn create_document_data(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    let mut doc_state = self.persistence()?.into_data_source();
    // If the document does not exist in local disk, try get the doc state from the cloud. This happens
    // When user_device_a create a document and user_device_b open the document.
    if !self.is_doc_exist(doc_id).await? {
      info!(
        "document {} not found in local disk, try to get the doc state from the cloud",
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

    let document = self.collab_for_document(doc_id, doc_state).await?;

    // Initialize subscriptions
    let mut lock = document.write().await;
    subscribe_document_changed(doc_id, &mut lock);
    subscribe_document_snapshot_state(&lock);
    subscribe_document_sync_state(&lock);
    drop(lock);

    Ok(document)
  }

  pub async fn get_document_data(&self, doc_id: &Uuid) -> FlowyResult<DocumentData> {
    let document = self.get_document(doc_id).await?;
    let document = document.read().await;
    document.get_document_data().map_err(internal_error)
  }
  pub async fn get_document_text(&self, doc_id: &Uuid) -> FlowyResult<String> {
    let document = self.get_document(doc_id).await?;
    let document = document.read().await;
    let text = document.paragraphs().join("\n");
    Ok(text)
  }

  /// Return a document instance.
  /// The returned document might or might not be able to sync with the cloud.
  async fn get_document(&self, doc_id: &Uuid) -> FlowyResult<Arc<RwLock<Document>>> {
    // Check if the document is in the documents map
    if let Some(holder) = self.documents.get(doc_id) {
      if let Some(doc) = holder.get_document() {
        return Ok(doc);
      }
    }

    // Check if the document is in the removing_documents map
    if let Some(doc) = self.restore_document_from_removing(doc_id) {
      return Ok(doc);
    }

    let document = self.create_document_instance(doc_id, false).await?;
    Ok(document)
  }

  pub async fn open_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    if let Some(mutex_document) = self.restore_document_from_removing(doc_id) {
      let lock = mutex_document.read().await;
      lock.start_init_sync();
      return Ok(());
    }

    // Check if the document is in the documents map
    if let Some(holder) = self.documents.get(doc_id) {
      if holder.get_document().is_some() {
        return Ok(());
      }
    }

    let _ = self.create_document_instance(doc_id, true).await?;
    Ok(())
  }

  pub async fn close_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    if let Some((doc_id, holder)) = self.documents.remove(doc_id) {
      if let Some(document) = holder.get_document() {
        {
          // clear the awareness state when close the document
          let mut lock = document.write().await;
          lock.clean_awareness_local_state();
        }

        let clone_doc_id = doc_id;
        trace!("move document to removing_documents: {}", doc_id);
        self.removing_documents.insert(doc_id, document);

        let weak_removing_documents = Arc::downgrade(&self.removing_documents);
        tokio::spawn(async move {
          tokio::time::sleep(std::time::Duration::from_secs(120)).await;
          if let Some(removing_documents) = weak_removing_documents.upgrade() {
            if removing_documents.remove(&clone_doc_id).is_some() {
              trace!("drop document from removing_documents: {}", clone_doc_id);
            }
          }
        });
      }
    }

    Ok(())
  }

  pub async fn delete_document(&self, doc_id: &Uuid) -> FlowyResult<()> {
    let uid = self.user_service.user_id()?;
    let workspace_id = self.user_service.workspace_id()?;
    if let Some(db) = self.user_service.collab_db(uid)?.upgrade() {
      db.delete_doc(uid, &workspace_id.to_string(), &doc_id.to_string())
        .await?;
      // When deleting a document, we need to remove it from the cache.
      self.documents.remove(doc_id);
    }
    Ok(())
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
    let uid = self.user_service.user_id()?;
    let workspace_id = self.user_service.workspace_id()?;
    if let Some(collab_db) = self.user_service.collab_db(uid)?.upgrade() {
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

  fn restore_document_from_removing(&self, doc_id: &Uuid) -> Option<Arc<RwLock<Document>>> {
    let (doc_id, doc) = self.removing_documents.remove(doc_id)?;
    trace!(
      "move document {} from removing_documents to documents",
      doc_id
    );

    // Insert into documents map with a new holder
    let mut holder = DocumentHolder::new();
    holder.set_document(doc.clone());
    self.documents.insert(doc_id, holder);

    Some(doc)
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

struct DocumentHolder {
  document: Option<Arc<RwLock<Document>>>,
  is_initializing: AtomicBool,
}

impl DocumentHolder {
  fn new() -> Self {
    Self {
      document: None,
      is_initializing: AtomicBool::new(false),
    }
  }

  /// Try to set the initializing flag. Returns true if successful (no other thread is initializing)
  fn try_start_initialize(&self) -> bool {
    self
      .is_initializing
      .compare_exchange(false, true, Ordering::Acquire, Ordering::Relaxed)
      .is_ok()
  }

  /// Set the document and mark initialization as complete
  fn set_document(&mut self, document: Arc<RwLock<Document>>) {
    self.document = Some(document);
    self.is_initializing.store(false, Ordering::Release);
  }

  /// Get the document if it exists
  fn get_document(&self) -> Option<Arc<RwLock<Document>>> {
    self.document.clone()
  }
}
