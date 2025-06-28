use lib_infra::util::OperatingSystem;
use lib_log::stream_log::StreamLogSender;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::AppFlowyCoreConfig;

static INIT_LOG: AtomicBool = AtomicBool::new(false);
pub(crate) fn init_log(
  config: &AppFlowyCoreConfig,
  platform: &OperatingSystem,
  stream_log_sender: Option<Arc<dyn StreamLogSender>>,
) {
  #[cfg(debug_assertions)]
  if get_bool_from_env_var("DISABLE_CI_TEST_LOG") {
    return;
  }

  if !INIT_LOG.load(Ordering::SeqCst) {
    INIT_LOG.store(true, Ordering::SeqCst);

    let _ = lib_log::Builder::new("log", &config.storage_path, platform, stream_log_sender)
      .env_filter(&config.log_filter)
      .build();
  }
}

pub fn create_log_filter(default_level: String, platform: OperatingSystem) -> String {
  let mut env_rust_log = std::env::var("RUST_LOG").unwrap_or(default_level.clone());
  #[cfg(debug_assertions)]
  if matches!(platform, OperatingSystem::IOS) {
    env_rust_log = "trace".to_string();
  }
  let mut filters = vec![];

  #[cfg(feature = "profiling")]
  filters.push(format!("tokio={}", "debug"));
  #[cfg(feature = "profiling")]
  filters.push(format!("runtime={}", "debug"));

  if cfg!(debug_assertions) {
    // env_rust_log should be string than separate by ,
    let env_rust_log = env_rust_log
      .split(',')
      .map(|v| v.to_string())
      .collect::<Vec<_>>();
    filters.extend(env_rust_log);
  } else {
    let level = default_level;
    filters.push(format!("flowy_core={}", level));
    filters.push(format!("flowy_folder={}", level));
    filters.push(format!("collab_sync={}", level));
    filters.push(format!("collab_folder={}", level));
    filters.push(format!("collab_database={}", level));
    filters.push(format!("collab_plugins={}", level));
    filters.push(format!("collab={}", level));
    filters.push(format!("flowy_user={}", level));
    filters.push(format!("flowy_user_pub={}", level));
    filters.push(format!("flowy_document={}", level));
    filters.push(format!("flowy_database2={}", level));
    filters.push(format!("flowy_server={}", level));
    filters.push(format!("flowy_notification={}", "info"));
    filters.push(format!("lib_infra={}", level));
    filters.push(format!("flowy_search={}", level));
    filters.push(format!("flowy_chat={}", level));
    filters.push(format!("flowy_ai={}", level));
    filters.push(format!("flowy_ai_pub={}", level));
    filters.push(format!("flowy_sqlite_vec={}", level));
    filters.push(format!("sync_log={}", level));
    filters.push(format!("dart_ffi={}", level));
    filters.push(format!("client_api={}", level));
    filters.push(format!("infra={}", level));

    // Most of the time, we don't need to see the logs from the following crates
    // filters.push(format!("lib_dispatch={}", level));
  }
  filters.join(",")
}

#[cfg(debug_assertions)]
fn get_bool_from_env_var(env_var_name: &str) -> bool {
  match std::env::var(env_var_name) {
    Ok(value) => match value.to_lowercase().as_str() {
      "true" | "1" => true,
      "false" | "0" => false,
      _ => false,
    },
    Err(_) => false,
  }
}
