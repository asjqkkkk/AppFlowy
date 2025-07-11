use rusqlite::ffi::sqlite3_auto_extension;
use sqlite_vec::sqlite3_vec_init;
use std::sync::Once;
use tracing::{debug, error};

pub mod db;
pub mod entities;
mod migration;

static INIT_SQLITE_VEC: Once = Once::new();

#[allow(clippy::missing_transmute_annotations)]
pub fn init_sqlite_vector_extension() {
  INIT_SQLITE_VEC.call_once(|| unsafe {
    let result = sqlite3_auto_extension(Some(std::mem::transmute(sqlite3_vec_init as *const ())));

    if result == 0 {
      debug!("[SQLite-Vec] Extension registered successfully");
    } else {
      error!(
        "[SQLite-Vec] Failed to register extension, error code: {}",
        result
      );
    }
  });
}
