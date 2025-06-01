use std::borrow::BorrowMut;
use std::fmt::{Debug, Display};
use std::sync::{Arc, Weak};

use anyhow::{Error, anyhow};
use client_api::v2::WorkspaceController;
use collab::core::collab::{CollabOptions, DataSource, default_client_id};
use collab::core::collab_plugin::CollabPersistence;
use collab::core::origin::{CollabClient, CollabOrigin};
use collab::error::CollabError;
use collab::preclude::{ClientID, Collab, Transact};
use collab_database::workspace_database::{
  CollabRef, DatabaseCollabService, WorkspaceDatabaseManager,
};
use collab_document::document::{Document, DocumentBody};
use collab_entity::{CollabObject, CollabType};
use collab_folder::{Folder, FolderData, FolderNotify};

use collab::lock::RwLock;
use collab_plugins::local_storage::kv::KVTransactionDB;
use collab_plugins::local_storage::kv::doc::CollabKVAction;
use collab_plugins::local_storage::rocksdb::kv_impl::KVTransactionDBRocksdbImpl;
use collab_user::core::{UserAwareness, UserAwarenessNotifier};

use crate::workspace_collab::adaptor_trait::{WorkspaceCollabIndexer, WorkspaceCollabUser};
use flowy_ai_pub::entities::UnindexedData;
use flowy_error::{FlowyError, FlowyResult};
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

pub struct WorkspaceCollabAdaptor {
  controller: RwLock<Option<Arc<Weak<WorkspaceController>>>>,
  user: Arc<dyn WorkspaceCollabUser>,
  collab_indexer: Option<Weak<dyn WorkspaceCollabIndexer>>,
  index_task_handle: RwLock<Option<tokio::task::JoinHandle<()>>>,
}

impl WorkspaceCollabAdaptor {
  pub fn new(
    user: impl WorkspaceCollabUser + 'static,
    collab_indexer: Option<Weak<dyn WorkspaceCollabIndexer>>,
  ) -> Self {
    Self {
      controller: Default::default(),
      collab_indexer,
      user: Arc::new(user),
      index_task_handle: Default::default(),
    }
  }

  pub async fn client_id(&self) -> FlowyResult<ClientID> {
    Ok(self.get_controller().await?.client_id())
  }

  pub async fn set_controller(&self, controller: Weak<WorkspaceController>) {
    if let Some(handle) = self.index_task_handle.write().await.take() {
      handle.abort();
    }

    let controller = Arc::new(controller);
    let weak_controller = Arc::downgrade(&controller);
    *self.controller.write().await = Some(controller);

    // Only spawn indexing task if indexer is available
    if let Ok(workspace_id) = self.user.workspace_id() {
      if let Some(indexer) = self.collab_indexer.clone() {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        let handle = tokio::spawn(async move {
          loop {
            interval.tick().await;
            // Get indexer and controller, breaking out if either is unavailable
            let Some(indexer) = indexer.upgrade() else {
              break;
            };
            let Some(controller) = weak_controller.upgrade().and_then(|w| w.upgrade()) else {
              break;
            };

            // Process changed collabs
            match controller.consume_latest_changed_collab() {
              collabs if !collabs.is_empty() => {
                for collab in collabs {
                  let _ = indexer
                    .index_opened_collab(workspace_id, collab.id, collab.collab_type)
                    .await;
                }
              },
              _ => {
                // If no collabs are changed, sleep for a while
                tokio::time::sleep(std::time::Duration::from_secs(10)).await;
              },
            }
          }
        });

        *self.index_task_handle.write().await = Some(handle);
      }
    } else {
      error!("Unable to spawn indexing task: workspace_id not found");
    }
  }

  pub fn update_network(&self, _reachable: bool) {
    // TODO(nathan): new syncing protocol
  }

  #[instrument(level = "trace", skip(self, data_source,))]
  pub async fn create_document(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    data_source: DataSource,
  ) -> Result<Arc<RwLock<Document>>, Error> {
    let collab_type = CollabType::Document;
    let mut collab = self
      .build_collab_with_source(object_id, collab_type, data_source)
      .await?;
    collab.enable_undo_redo();
    let document = Document::open(collab)?;
    let document = Arc::new(RwLock::new(document));
    self
      .finalize_arc_collab(workspace_id, object_id, collab_type, document)
      .await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip(self, doc_state, folder_notifier))]
  pub async fn create_folder(
    &self,
    workspace_id: Uuid,
    doc_state: DataSource,
    folder_notifier: Option<FolderNotify>,
    folder_data: Option<FolderData>,
  ) -> Result<Arc<RwLock<Folder>>, Error> {
    let uid = self.user.uid()?;
    let collab_type = CollabType::Folder;
    let folder = match folder_data {
      None => {
        let collab = self
          .build_collab_with_source(workspace_id, collab_type, doc_state)
          .await?;
        Folder::open(uid, collab, folder_notifier)?
      },
      Some(data) => {
        let collab = self
          .build_collab_with_source(workspace_id, collab_type, doc_state)
          .await?;
        Folder::create(uid, collab, folder_notifier, data)
      },
    };
    let folder = Arc::new(RwLock::new(folder));
    self
      .finalize_arc_collab(workspace_id, workspace_id, collab_type, folder)
      .await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip(self, doc_state, notifier))]
  pub async fn create_user_awareness(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    doc_state: DataSource,
    notifier: Option<UserAwarenessNotifier>,
  ) -> Result<Arc<RwLock<UserAwareness>>, Error> {
    let collab_type = CollabType::UserAwareness;
    let collab = self
      .build_collab_with_source(object_id, collab_type, doc_state)
      .await?;
    let user_awareness = UserAwareness::create(collab, notifier)?;
    let user_awareness = Arc::new(RwLock::new(user_awareness));
    self
      .finalize_arc_collab(workspace_id, object_id, collab_type, user_awareness)
      .await
  }

  #[allow(clippy::too_many_arguments)]
  #[instrument(level = "trace", skip_all)]
  pub async fn create_workspace_database_manager(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    collab: Collab,
    collab_service: impl DatabaseCollabService,
  ) -> Result<Arc<RwLock<WorkspaceDatabaseManager>>, Error> {
    let collab_type = CollabType::WorkspaceDatabase;
    let workspace = WorkspaceDatabaseManager::open(&object_id.to_string(), collab, collab_service)?;
    let workspace = Arc::new(RwLock::new(workspace));
    self
      .finalize_arc_collab(workspace_id, object_id, collab_type, workspace)
      .await
  }

  pub async fn build_collab_with_source(
    &self,
    object_id: Uuid,
    collab_type: CollabType,
    data_source: DataSource,
  ) -> Result<Collab, Error> {
    let uid = self.user.uid()?;
    let device_id = self.user.device_id()?;
    let controller = self.get_controller().await?;
    let client_id = controller.client_id();
    let origin = CollabOrigin::Client(CollabClient::new(uid, device_id));
    let options =
      CollabOptions::new(object_id.to_string(), client_id).with_data_source(data_source);

    trace!(
      "Build collab:{}:{} with client_id: {:?}",
      object_id, collab_type, options.client_id
    );
    let collab = Collab::new_with_options(origin, options)?;
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
  pub async fn finalize_arc_collab<T>(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    collab_type: CollabType,
    collab: Arc<RwLock<T>>,
  ) -> Result<Arc<RwLock<T>>, Error>
  where
    T: BorrowMut<Collab> + Send + Sync + 'static,
  {
    self.spawn_indexing_task(workspace_id, object_id, collab_type);

    let controller = self.get_controller().await?;
    let collab_ref = collab.clone() as Arc<RwLock<dyn BorrowMut<Collab> + Send + Sync + 'static>>;
    controller
      .bind_and_cache_collab_ref(&collab_ref, collab_type)
      .await?;
    Ok(collab)
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn finalize_collab(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    collab_type: CollabType,
    collab: &mut Collab,
  ) -> Result<(), Error> {
    self.spawn_indexing_task(workspace_id, object_id, collab_type);
    let controller = self.get_controller().await?;
    controller.bind(collab, collab_type)?;
    Ok(())
  }

  fn spawn_indexing_task(&self, workspace_id: Uuid, object_id: Uuid, collab_type: CollabType) {
    let weak_collab_indexer = self.collab_indexer.clone();
    tokio::spawn(async move {
      if let Some(indexer) = weak_collab_indexer.and_then(|w| w.upgrade()) {
        indexer
          .index_opened_collab(workspace_id, object_id, collab_type)
          .await;
      }
    });
  }

  #[instrument(level = "trace", skip_all, err)]
  pub async fn cache_collab_ref(
    &self,
    object_id: Uuid,
    collab_type: CollabType,
    collab: CollabRef,
  ) -> Result<(), Error> {
    let controller = self.get_controller().await?;
    controller
      .cache_collab_ref(object_id, &collab, collab_type)
      .await?;
    Ok(())
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
}

pub fn unindexed_data_from_object(
  uid: i64,
  workspace_id: &Uuid,
  object_id: &Uuid,
  collab_type: CollabType,
  db: &KVTransactionDBRocksdbImpl,
) -> FlowyResult<Option<UnindexedData>> {
  let workspace_id = workspace_id.to_string();
  let object_id = object_id.to_string();
  let read_txn = db.read_txn();
  if !read_txn.is_exist(uid, &workspace_id, &object_id) {
    return Err(FlowyError::record_not_found());
  }

  let options = CollabOptions::new(object_id.clone(), default_client_id());
  let mut collab = Collab::new_with_options(CollabOrigin::Empty, options)?;
  let mut txn = collab.transact_mut();
  read_txn.load_doc_with_txn(uid, &workspace_id, &object_id, &mut txn)?;
  drop(txn);

  Ok(unindexed_data_form_collab(&collab, &collab_type))
}

pub fn unindexed_data_form_collab(
  collab: &Collab,
  collab_type: &CollabType,
) -> Option<UnindexedData> {
  match collab_type {
    CollabType::Document => {
      let txn = collab.doc().transact();
      let doc = DocumentBody::from_collab(collab)?;
      let paras = doc.paragraphs(txn);
      Some(UnindexedData::Paragraphs(paras))
    },
    _ => None,
  }
}
