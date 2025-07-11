use flowy_error::{FlowyError, FlowyResult};
use std::path::PathBuf;
use tokio::fs;
use tracing::error;
use uuid::Uuid;

pub struct ChatLocalFileStorage {
  pub storage_path: PathBuf,
}

impl ChatLocalFileStorage {
  pub fn new(root: PathBuf) -> FlowyResult<Self> {
    let storage_path = root.join("chat").join("local_files");
    std::fs::create_dir_all(&storage_path)?;
    Ok(Self { storage_path })
  }

  pub async fn get_files_for_chat(&self, chat_id: &str) -> FlowyResult<Vec<String>> {
    let chat_dir = self.storage_path.join(chat_id);
    if !chat_dir.exists() {
      return Ok(vec![]);
    }

    let mut files = Vec::new();
    let mut entries = fs::read_dir(&chat_dir).await?;
    while let Some(entry) = entries.next_entry().await? {
      if entry.file_type().await?.is_file() {
        if let Some(file_path) = entry.path().to_str() {
          files.push(file_path.to_string());
        }
      }
    }
    Ok(files)
  }

  pub async fn delete_file(&self, file_path: &str) -> FlowyResult<()> {
    let path = PathBuf::from(file_path);
    fs::remove_file(&path).await?;
    Ok(())
  }

  pub async fn copy_file(&self, chat_id: &Uuid, source_path: PathBuf) -> FlowyResult<PathBuf> {
    if !source_path.exists() {
      error!("Source path does not exist: {:?}", source_path);
      return Err(FlowyError::new(
        flowy_error::ErrorCode::InvalidParams,
        "Source path does not exist",
      ));
    }
    let chat_dir = self.storage_path.join(chat_id.to_string());
    fs::create_dir_all(&chat_dir).await?;
    let file_name = source_path.file_name().ok_or_else(|| {
      error!(
        "Failed to get file name from source path: {:?}",
        source_path
      );
      flowy_error::FlowyError::new(
        flowy_error::ErrorCode::InvalidParams,
        "Invalid source path: no file name",
      )
    })?;

    let destination_path = chat_dir.join(file_name);
    fs::copy(&source_path, &destination_path).await?;
    Ok(destination_path)
  }
}
