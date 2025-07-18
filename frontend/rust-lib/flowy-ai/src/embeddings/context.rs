use crate::embeddings::scheduler::EmbeddingScheduler;
use crate::local_ai::chat::llm::LocalLLMController;
use arc_swap::ArcSwapOption;
use flowy_error::{ErrorCode, FlowyError, FlowyResult};
use flowy_sqlite_vec::db::VectorSqliteDB;
use lib_infra::util::get_operating_system;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};
use tracing::{error, info, warn};

pub struct EmbedContext {
  local_llm_controller: ArcSwapOption<LocalLLMController>,
  vector_db: ArcSwapOption<VectorSqliteDB>,
  scheduler: ArcSwapOption<EmbeddingScheduler>,
}

impl EmbedContext {
  pub fn shared() -> &'static Arc<EmbedContext> {
    static INSTANCE: OnceLock<Arc<EmbedContext>> = OnceLock::new();
    INSTANCE.get_or_init(|| {
      Arc::new(EmbedContext {
        local_llm_controller: ArcSwapOption::empty(),
        vector_db: ArcSwapOption::empty(),
        scheduler: Default::default(),
      })
    })
  }

  pub fn get_vector_db(&self) -> Option<Arc<VectorSqliteDB>> {
    self.vector_db.load_full()
  }

  pub fn init_vector_db(&self, db_path: PathBuf) {
    let sys = get_operating_system();
    if !sys.is_desktop() {
      warn!("[Embedding] Vector db is not supported on {:?}", sys);
      return;
    }

    info!("Initializing vector db");
    match VectorSqliteDB::new(db_path.clone()) {
      Ok(db) => {
        info!("[Embedding] Vector db created at: {:?}", db_path);
        self.vector_db.store(Some(Arc::new(db)));
        self.try_create_scheduler();
      },
      Err(err) => {
        error!("[Embedding] Failed to create vector db: {}", err);
      },
    }
  }

  pub fn set_llm(&self, llm: Option<Arc<LocalLLMController>>) {
    if let Some(local_llm_controller) = llm {
      self.local_llm_controller.store(Some(local_llm_controller));
      self.try_create_scheduler();
    } else {
      self.local_llm_controller.store(None);
      if let Some(s) = self.scheduler.swap(None) {
        info!("[Embedding] Stopping scheduler");
        let _ = s.stop_tx.send(());
      }
    }
  }

  pub fn get_scheduler(&self) -> FlowyResult<Arc<EmbeddingScheduler>> {
    self.scheduler.load_full().ok_or_else(|| {
      FlowyError::new(
        ErrorCode::LocalEmbeddingNotReady,
        "Local embedding is not ready. Please check if the Ollama and vector db are initialized.",
      )
    })
  }

  fn try_create_scheduler(&self) {
    let ollama = match self.local_llm_controller.load_full() {
      Some(ollama) => ollama,
      None => {
        warn!("[Embedding] Ollama is not initialized, cannot create scheduler");
        return;
      },
    };

    let vector_db = match self.vector_db.load_full() {
      Some(vector_db) => vector_db,
      None => {
        warn!("[Embedding] Vector db is not initialized, cannot create scheduler");
        return;
      },
    };

    match EmbeddingScheduler::new(ollama, vector_db) {
      Ok(s) => {
        info!("[Embedding] create scheduler successfully");
        self.scheduler.store(Some(s));
      },
      Err(err) => error!("[Embedding] Failed to create scheduler: {}", err),
    }
  }
}
