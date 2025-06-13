use collab::core::collab::default_client_id;
use collab::entity::EncodedCollab;
use collab::preclude::ClientID;
use collab_document::blocks::DocumentData;
use collab_document::document::Document;
use collab_document::document_data::default_document_data;
use collab_plugins::CollabKVDB;
use flowy_document::manager::{DocumentManager, DocumentUserService};
use flowy_document_pub::cloud::*;
use flowy_error::{ErrorCode, FlowyError, FlowyResult};
use flowy_storage_pub::storage::{CreatedUpload, FileProgressReceiver, StorageService};
use flowy_user_pub::workspace_collab::adaptor::WorkspaceCollabAdaptor;
use flowy_user_pub::workspace_collab::adaptor_trait::WorkspaceCollabUser;
use lib_infra::async_trait::async_trait;
use lib_infra::box_any::BoxAny;
use nanoid::nanoid;
use std::ops::Deref;
use std::sync::{Arc, OnceLock, Weak};
use tempfile::TempDir;
use tokio::sync::RwLock;
use tracing_subscriber::{EnvFilter, fmt::Subscriber, util::SubscriberInitExt};
use uuid::Uuid;

pub struct DocumentTest {
  #[allow(dead_code)]
  builder: Arc<WorkspaceCollabAdaptor>,
  inner: DocumentManager,
}

impl DocumentTest {
  pub fn new() -> Self {
    let user = FakeUser::new();
    let cloud_service = Arc::new(LocalTestDocumentCloudServiceImpl());
    let file_storage = Arc::new(DocumentTestFileStorageService) as Arc<dyn StorageService>;

    let builder = Arc::new(WorkspaceCollabAdaptor::new(
      WorkspaceCollabIntegrateImpl {
        workspace_id: user.workspace_id,
      },
      None,
    ));

    let manager = DocumentManager::new(
      Arc::new(user),
      Arc::downgrade(&builder),
      cloud_service,
      Arc::downgrade(&file_storage),
    );
    Self {
      inner: manager,
      builder,
    }
  }
}

impl Deref for DocumentTest {
  type Target = DocumentManager;

  fn deref(&self) -> &Self::Target {
    &self.inner
  }
}

pub struct FakeUser {
  workspace_id: Uuid,
  collab_db: Arc<CollabKVDB>,
}

impl FakeUser {
  pub fn new() -> Self {
    setup_log();

    let tempdir = TempDir::new().unwrap();
    let path = tempdir.into_path();
    let collab_db = Arc::new(CollabKVDB::open(path).unwrap());
    let workspace_id = uuid::Uuid::new_v4();

    Self {
      collab_db,
      workspace_id,
    }
  }
}

impl DocumentUserService for FakeUser {
  fn user_id(&self) -> Result<i64, FlowyError> {
    Ok(1)
  }

  fn workspace_id(&self) -> Result<Uuid, FlowyError> {
    Ok(self.workspace_id)
  }

  fn collab_db(&self, _uid: i64) -> Result<std::sync::Weak<CollabKVDB>, FlowyError> {
    Ok(Arc::downgrade(&self.collab_db))
  }

  fn device_id(&self) -> Result<String, FlowyError> {
    Ok("".to_string())
  }

  fn collab_client_id(&self, _workspace_id: &Uuid) -> ClientID {
    default_client_id()
  }
}

pub fn setup_log() {
  static START: OnceLock<()> = OnceLock::new();
  START.get_or_init(|| {
    unsafe {
      std::env::set_var("RUST_LOG", "collab_persistence=trace");
    }
    let subscriber = Subscriber::builder()
      .with_env_filter(EnvFilter::from_default_env())
      .with_ansi(true)
      .finish();
    subscriber.try_init().unwrap();
  });
}

pub async fn create_and_open_empty_document() -> (DocumentTest, Arc<RwLock<Document>>, String) {
  let test = DocumentTest::new();
  let doc_id = gen_document_id();
  let data = default_document_data(&doc_id.to_string());
  let uid = test.user_service.user_id().unwrap();
  // create a document
  test
    .create_document(uid, &doc_id, Some(data.clone()))
    .await
    .unwrap();

  test.open_document(&doc_id).await.unwrap();
  let document = test.editable_document(&doc_id).await.unwrap();

  (test, document, data.page_id)
}

pub fn gen_document_id() -> Uuid {
  uuid::Uuid::new_v4()
}

pub fn gen_id() -> String {
  nanoid!(10)
}

pub struct LocalTestDocumentCloudServiceImpl();

#[async_trait]
impl DocumentCloudService for LocalTestDocumentCloudServiceImpl {
  async fn get_document_doc_state(
    &self,
    document_id: &Uuid,
    _workspace_id: &Uuid,
  ) -> Result<Vec<u8>, FlowyError> {
    let document_id = document_id.to_string();
    Err(FlowyError::new(
      ErrorCode::RecordNotFound,
      format!("Document {} not found", document_id),
    ))
  }

  async fn get_document_snapshots(
    &self,
    _document_id: &Uuid,
    _limit: usize,
    _workspace_id: &str,
  ) -> Result<Vec<DocumentSnapshot>, FlowyError> {
    Ok(vec![])
  }

  async fn get_document_data(
    &self,
    _document_id: &Uuid,
    _workspace_id: &Uuid,
  ) -> Result<Option<DocumentData>, FlowyError> {
    Ok(None)
  }

  async fn create_document_collab(
    &self,
    _workspace_id: &Uuid,
    _document_id: &Uuid,
    _encoded_collab: EncodedCollab,
  ) -> Result<(), FlowyError> {
    Ok(())
  }
}

pub struct DocumentTestFileStorageService;

#[async_trait]
impl StorageService for DocumentTestFileStorageService {
  async fn delete_object(&self, _url: String) -> FlowyResult<()> {
    todo!()
  }

  fn download_object(&self, _url: String, _local_file_path: String) -> FlowyResult<()> {
    todo!()
  }

  async fn create_upload(
    &self,
    _workspace_id: &str,
    _parent_dir: &str,
    _local_file_path: &str,
  ) -> Result<(CreatedUpload, Option<FileProgressReceiver>), flowy_error::FlowyError> {
    todo!()
  }

  async fn start_upload(&self, _record: &BoxAny) -> Result<(), FlowyError> {
    todo!()
  }

  async fn resume_upload(
    &self,
    _workspace_id: &str,
    _parent_dir: &str,
    _file_id: &str,
  ) -> Result<(), FlowyError> {
    todo!()
  }

  async fn subscribe_file_progress(
    &self,
    _parent_idr: &str,
    _url: &str,
  ) -> Result<Option<FileProgressReceiver>, FlowyError> {
    todo!()
  }
}

struct WorkspaceCollabIntegrateImpl {
  workspace_id: Uuid,
}
impl WorkspaceCollabUser for WorkspaceCollabIntegrateImpl {
  fn workspace_id(&self) -> Result<Uuid, FlowyError> {
    Ok(self.workspace_id)
  }

  fn uid(&self) -> Result<i64, FlowyError> {
    Ok(0)
  }

  fn device_id(&self) -> Result<String, FlowyError> {
    Ok("fake_device_id".to_string())
  }

  fn collab_db(&self) -> FlowyResult<Weak<CollabKVDB>> {
    todo!()
  }
}
