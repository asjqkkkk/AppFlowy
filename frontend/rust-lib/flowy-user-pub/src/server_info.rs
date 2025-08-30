use client_api::entity::server_info_dto::ServerInfo;
use lib_infra::async_trait::async_trait;

/// Provides access to server information for other crates.
/// This trait allows other modules (AI, Folder, Database, etc.) to access
/// server configuration without directly depending on the UserManager.
#[async_trait]
pub trait ServerInfoProvider: Send + Sync + 'static {
  /// Get the current server information.
  /// Returns None if server info is not available or signature verification fails.
  async fn get_server_info(&self) -> Option<ServerInfo>;
}
