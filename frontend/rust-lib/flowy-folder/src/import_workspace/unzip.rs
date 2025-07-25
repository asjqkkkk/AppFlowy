use std::fs::File;
use std::io;
use std::path::Path;
use uuid::Uuid;
use zip::ZipArchive;

use flowy_error::{FlowyError, FlowyResult};

use super::types::FolderWorkspaceImporter;

impl<'a> FolderWorkspaceImporter<'a> {
  /// Unzip the archive to a temporary directory
  pub async fn extract_archive(&self, archive_path: &str) -> FlowyResult<String> {
    // todo: this path should be configurable
    let temp_dir = format!("/tmp/appflowy_import_{}", Uuid::new_v4());

    std::fs::create_dir_all(&temp_dir).map_err(|e| {
      FlowyError::internal().with_context(format!(
        "Failed to create temp directory '{}': {}",
        temp_dir, e
      ))
    })?;

    let file = File::open(archive_path).map_err(|e| {
      FlowyError::invalid_data().with_context(format!(
        "Failed to open archive file '{}': {}",
        archive_path, e
      ))
    })?;

    let mut archive = ZipArchive::new(file).map_err(|e| {
      FlowyError::invalid_data().with_context(format!("Failed to read ZIP archive: {}", e))
    })?;

    for i in 0..archive.len() {
      let mut file = archive.by_index(i).map_err(|e| {
        FlowyError::internal().with_context(format!("Failed to read ZIP entry {}: {}", i, e))
      })?;

      let output_path = format!("{}/{}", temp_dir, file.name());

      if file.is_dir() {
        std::fs::create_dir_all(&output_path).map_err(|e| {
          FlowyError::internal().with_context(format!(
            "Failed to create directory '{}': {}",
            output_path, e
          ))
        })?;
      } else {
        if let Some(parent) = Path::new(&output_path).parent() {
          std::fs::create_dir_all(parent).map_err(|e| {
            FlowyError::internal().with_context(format!("Failed to create parent directory: {}", e))
          })?;
        }

        let mut output_file = File::create(&output_path).map_err(|e| {
          FlowyError::internal().with_context(format!(
            "Failed to create output file '{}': {}",
            output_path, e
          ))
        })?;

        io::copy(&mut file, &mut output_file).map_err(|e| {
          FlowyError::internal()
            .with_context(format!("Failed to extract file '{}': {}", output_path, e))
        })?;
      }
    }

    Ok(temp_dir)
  }

  // todo: clean up the temp dir
  pub async fn cleanup_temp_dir(&self, _temp_dir: String) -> FlowyResult<()> {
    Ok(())
  }

  // todo: validate the unzipped files
  // for now, only validate the files exist
  pub async fn validate(&self, temp_dir: &str) -> FlowyResult<()> {
    tracing::info!("Validating archive structure in: {}", temp_dir);

    let metadata_path = format!("{}/metadata.json", temp_dir);
    if !Path::new(&metadata_path).exists() {
      return Err(FlowyError::invalid_data().with_context("Missing metadata.json file"));
    }

    let relation_map_path = format!("{}/relation_map.json", temp_dir);
    if !Path::new(&relation_map_path).exists() {
      return Err(FlowyError::invalid_data().with_context("Missing relation_map.json file"));
    }

    let collab_objects_path = format!("{}/collab_objects", temp_dir);
    if !Path::new(&collab_objects_path).exists() {
      return Err(FlowyError::invalid_data().with_context("Missing collab_objects directory"));
    }

    Ok(())
  }
}
