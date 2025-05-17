use std::borrow::BorrowMut;
use std::fmt::{Debug, Display};
use std::sync::{Arc, Weak};

use anyhow::{Error, anyhow};
use client_api::v2::WorkspaceController;
use collab::core::collab::DataSource;
use collab::core::collab_plugin::CollabPersistence;
use collab::entity::EncodedCollab;
use collab::error::CollabError;
use collab::preclude::{Collab, CollabBuilder, Transact};
use collab_database::workspace_database::{DatabaseCollabService, WorkspaceDatabaseManager};
use collab_document::blocks::DocumentData;
use collab_document::document::{Document, DocumentBody};
use collab_entity::{CollabObject, CollabType};
use collab_folder::{Folder, FolderData, FolderNotify};

use collab::lock::RwLock;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use collab_plugins::local_storage::rocksdb::kv_impl::KVTransactionDBRocksdbImpl;
use collab_user::core::{UserAwareness, UserAwarenessNotifier};

use flowy_ai_pub::entities::UnindexedData;
use flowy_error::FlowyError;
use lib_infra::async_trait::async_trait;
use lib_infra::util::get_operating_system;
use tracing::{error, instrument, trace};
use uuid::Uuid;

#[derive(Clone, Debug)]
pub enum CollabPluginProviderType {
  Local,
  AppFlowyCloud,
}

pub enum CollabPluginProviderContext {
  Local,
  AppFlowyCloud {
    uid: i64,
    collab_object: CollabObject,
    local_collab: Weak<RwLock<dyn BorrowMut<Collab> + Send + Sync + 'static>>,
  },
}

impl Display for CollabPluginProviderContext {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    let str = match self {
      CollabPluginProviderContext::Local => "Local".to_string(),
      CollabPluginProviderContext::AppFlowyCloud {
        uid: _,
        collab_object,
        ..
      } => collab_object.to_string(),
    };
    write!(f, "{}", str)
  }
}

pub trait WorkspaceCollabUser: Send + Sync {
  fn workspace_id(&self) -> Result<Uuid, FlowyError>;
  fn device_id(&self) -> Result<String, FlowyError>;
}

#[async_trait]
pub trait CollabIndexedData: Send + Sync + 'static {
  async fn get_unindexed_data(&self, collab_type: &CollabType) -> Option<UnindexedData>;
}

#[async_trait]
impl<T> CollabIndexedData for RwLock<T>
where
  T: BorrowMut<Collab> + Send + Sync + 'static,
{
  async fn get_unindexed_data(&self, collab_type: &CollabType) -> Option<UnindexedData> {
    let collab = self.try_read().ok()?;
    unindexed_data_form_collab(collab.borrow(), collab_type)
  }
}

#[async_trait]
pub trait WorkspaceCollabEmbedding: Send + Sync {
  async fn embed_collab(&self, collab_object: CollabObject, collab: Weak<dyn CollabIndexedData>);
}

/// writer interface
#[async_trait]
pub trait InstantIndexedDataConsumer: Send + Sync + 'static {
  fn consumer_id(&self) -> String;

  async fn consume_collab(
    &self,
    workspace_id: &Uuid,
    data: UnindexedData,
    object_id: &Uuid,
    collab_type: CollabType,
  ) -> Result<bool, FlowyError>;

  async fn did_delete_collab(
    &self,
    workspace_id: &Uuid,
    object_id: &Uuid,
  ) -> Result<(), FlowyError>;
}

pub struct WorkspaceCollabAdaptor {
  controller: RwLock<Option<Weak<WorkspaceController>>>,
  user: Arc<dyn WorkspaceCollabUser>,
  embeddings_writer: Option<Weak<dyn WorkspaceCollabEmbedding>>,
}

impl WorkspaceCollabAdaptor {
  pub fn new(
    user: impl WorkspaceCollabUser + 'static,
    embeddings_writer: Option<Weak<dyn WorkspaceCollabEmbedding>>,
  ) -> Self {
    Self {
      controller: Default::default(),
      embeddings_writer,
      user: Arc::new(user),
    }
  }

  pub async fn set_controller(&self, controller: Weak<WorkspaceController>) {
    *self.controller.write().await = Some(controller);
  }

  pub fn update_network(&self, _reachable: bool) {
    // TODO(nathan): new syncing protocol
  }

  pub fn collab_object(
    &self,
    workspace_id: &Uuid,
    uid: i64,
    object_id: &Uuid,
    collab_type: CollabType,
  ) -> Result<CollabObject, Error> {
    // Compare the workspace_id with the currently opened workspace_id. Return an error if they do not match.
    // This check is crucial in asynchronous code contexts where the workspace_id might change during operation.
    let actual_workspace_id = self.user.workspace_id()?;
    if workspace_id != &actual_workspace_id {
      return Err(anyhow::anyhow!(
        "workspace_id not match when build collab. expect workspace_id: {}, actual workspace_id: {}",
        workspace_id,
        actual_workspace_id
      ));
    }
    let device_id = self.user.device_id()?;
    Ok(CollabObject::new(
      uid,
      object_id.to_string(),
      collab_type,
      workspace_id.to_string(),
      device_id,
    ))
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip(self, data_source, data))]
  pub async fn create_document(
    &self,
    object: CollabObject,
    data_source: DataSource,
    data: Option<DocumentData>,
  ) -> Result<Arc<RwLock<Document>>, Error> {
    let expected_collab_type = CollabType::Document;
    assert_eq!(object.collab_type, expected_collab_type);
    let mut collab = self.build_collab(&object, data_source).await?;
    collab.enable_undo_redo();

    let document = match data {
      None => Document::open(collab)?,
      Some(data) => Document::create_with_data(collab, data)?,
    };
    let document = Arc::new(RwLock::new(document));
    self.finalize(object, document).await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip(self, object, doc_state, folder_notifier))]
  pub async fn create_folder(
    &self,
    object: CollabObject,
    doc_state: DataSource,
    folder_notifier: Option<FolderNotify>,
    folder_data: Option<FolderData>,
  ) -> Result<Arc<RwLock<Folder>>, Error> {
    let expected_collab_type = CollabType::Folder;
    assert_eq!(object.collab_type, expected_collab_type);
    let folder = match folder_data {
      None => {
        let collab = self.build_collab(&object, doc_state).await?;
        Folder::open(object.uid, collab, folder_notifier)?
      },
      Some(data) => {
        let collab = self.build_collab(&object, doc_state).await?;
        Folder::create(object.uid, collab, folder_notifier, data)
      },
    };
    let folder = Arc::new(RwLock::new(folder));
    self.finalize(object, folder).await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip(self, object, doc_state, notifier))]
  pub async fn create_user_awareness(
    &self,
    object: CollabObject,
    doc_state: DataSource,
    notifier: Option<UserAwarenessNotifier>,
  ) -> Result<Arc<RwLock<UserAwareness>>, Error> {
    let expected_collab_type = CollabType::UserAwareness;
    assert_eq!(object.collab_type, expected_collab_type);
    let collab = self.build_collab(&object, doc_state).await?;
    let user_awareness = UserAwareness::create(collab, notifier)?;
    let user_awareness = Arc::new(RwLock::new(user_awareness));
    self.finalize(object, user_awareness).await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip_all)]
  pub async fn create_workspace_database_manager(
    &self,
    object: CollabObject,
    collab: Collab,
    collab_service: impl DatabaseCollabService,
  ) -> Result<Arc<RwLock<WorkspaceDatabaseManager>>, Error> {
    let expected_collab_type = CollabType::WorkspaceDatabase;
    assert_eq!(object.collab_type, expected_collab_type);
    let workspace = WorkspaceDatabaseManager::open(&object.object_id, collab, collab_service)?;
    let workspace = Arc::new(RwLock::new(workspace));
    self.finalize(object, workspace).await
  }

  pub async fn build_collab(
    &self,
    object: &CollabObject,
    data_source: DataSource,
  ) -> Result<Collab, Error> {
    let object = object.clone();
    let device_id = self.user.device_id()?;
    let collab = tokio::task::spawn_blocking(move || {
      let collab = CollabBuilder::new(object.uid, &object.object_id, data_source)
        .with_device_id(device_id)
        .build()?;
      Ok::<_, Error>(collab)
    })
    .await??;

    Ok(collab)
  }

  async fn get_controller(&self) -> Result<Arc<WorkspaceController>, Error> {
    let controller = self.controller.read().await;
    if let Some(controller) = controller.as_ref() {
      if let Some(controller) = controller.upgrade() {
        return Ok(controller);
      }
    }

    Err(anyhow!("workspace controller is not set"))
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn finalize<T>(
    &self,
    object: CollabObject,
    collab: Arc<RwLock<T>>,
  ) -> Result<Arc<RwLock<T>>, Error>
  where
    T: BorrowMut<Collab> + Send + Sync + 'static,
  {
    if get_operating_system().is_desktop() {
      let cloned_object = object.clone();
      let weak_collab = Arc::downgrade(&collab);
      let weak_embedding_writer = self.embeddings_writer.clone();
      tokio::spawn(async move {
        if let Some(embedding_writer) = weak_embedding_writer.and_then(|w| w.upgrade()) {
          embedding_writer
            .embed_collab(cloned_object, weak_collab)
            .await;
        }
      });
    }

    let controller = self.get_controller().await?;
    let collab_ref = collab.clone() as Arc<RwLock<dyn BorrowMut<Collab> + Send + Sync + 'static>>;
    controller.bind(&collab_ref, object.collab_type).await?;

    let mut write_collab = collab.try_write()?;
    (*write_collab).borrow_mut().initialize();
    drop(write_collab);
    Ok(collab)
  }
}

pub struct CollabBuilderConfig {
  pub sync_enable: bool,
}

impl Default for CollabBuilderConfig {
  fn default() -> Self {
    Self { sync_enable: true }
  }
}

impl CollabBuilderConfig {
  pub fn sync_enable(mut self, sync_enable: bool) -> Self {
    self.sync_enable = sync_enable;
    self
  }
}

pub struct CollabPersistenceImpl {
  pub db: Weak<KVTransactionDBRocksdbImpl>,
  pub uid: i64,
  pub workspace_id: Uuid,
}

impl CollabPersistenceImpl {
  pub fn new(db: Weak<KVTransactionDBRocksdbImpl>, uid: i64, workspace_id: Uuid) -> Self {
    Self {
      db,
      uid,
      workspace_id,
    }
  }

  pub fn into_data_source(self) -> DataSource {
    DataSource::Disk(Some(Box::new(self)))
  }
}

impl CollabPersistence for CollabPersistenceImpl {
  fn load_collab_from_disk(&self, collab: &mut Collab) -> Result<(), CollabError> {
    let collab_db = self
      .db
      .upgrade()
      .ok_or_else(|| CollabError::Internal(anyhow!("collab_db is dropped")))?;

    let object_id = collab.object_id().to_string();
    let rocksdb_read = collab_db.read_txn();
    let workspace_id = self.workspace_id.to_string();

    if rocksdb_read.is_exist(self.uid, &workspace_id, &object_id) {
      let mut txn = collab.transact_mut();
      match rocksdb_read.load_doc_with_txn(self.uid, &workspace_id, &object_id, &mut txn) {
        Ok(update_count) => {
          trace!(
            "did load collab:{}-{} from disk, update_count:{}",
            self.uid, object_id, update_count
          );
        },
        Err(err) => {
          error!("🔴 load doc:{} failed: {}", object_id, err);
        },
      }
      drop(rocksdb_read);
      txn.commit();
      drop(txn);
    }
    Ok(())
  }

  fn save_collab_to_disk(
    &self,
    object_id: &str,
    encoded_collab: EncodedCollab,
  ) -> Result<(), CollabError> {
    let workspace_id = self.workspace_id.to_string();
    let collab_db = self
      .db
      .upgrade()
      .ok_or_else(|| CollabError::Internal(anyhow!("collab_db is dropped")))?;
    let write_txn = collab_db.write_txn();
    write_txn
      .flush_doc(
        self.uid,
        workspace_id.as_str(),
        object_id,
        encoded_collab.state_vector.to_vec(),
        encoded_collab.doc_state.to_vec(),
      )
      .map_err(|err| CollabError::Internal(err.into()))?;

    write_txn
      .commit_transaction()
      .map_err(|err| CollabError::Internal(err.into()))?;
    Ok(())
  }
}

pub fn unindexed_data_form_collab(
  collab: &Collab,
  collab_type: &CollabType,
) -> Option<UnindexedData> {
  match collab_type {
    CollabType::Document => {
      let txn = collab.doc().try_transact().ok()?;
      let doc = DocumentBody::from_collab(collab)?;
      let paras = doc.paragraphs(txn);
      Some(UnindexedData::Paragraphs(paras))
    },
    _ => None,
  }
}
