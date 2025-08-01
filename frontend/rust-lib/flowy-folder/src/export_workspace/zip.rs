use collab_importer::workspace::entities::WorkspaceRelationMap;
use flowy_error::{FlowyError, FlowyResult};
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use zip::{ZipWriter, write::FileOptions};

pub fn create_export_archive(
  output_path: &str,
  relation_map: &WorkspaceRelationMap,
  collab_data: &HashMap<String, Vec<u8>>,
  doc_state_to_json: &HashMap<String, String>,
  local_files: &HashMap<String, Vec<u8>>,
) -> FlowyResult<()> {
  let file = File::create(output_path).map_err(|e| {
    FlowyError::internal().with_context(format!(
      "Failed to create export file '{}': {}",
      output_path, e
    ))
  })?;

  let mut zip = ZipWriter::new(file);
  let options = FileOptions::default().compression_method(zip::CompressionMethod::Deflated);

  let relation_map_json = serde_json::to_string_pretty(relation_map).map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to serialize relation map to JSON: {}", e))
  })?;

  zip.start_file("relation_map.json", options).map_err(|e| {
    FlowyError::internal().with_context(format!(
      "Failed to start relation_map.json file in ZIP: {}",
      e
    ))
  })?;
  zip.write_all(relation_map_json.as_bytes()).map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to write relation_map.json to ZIP: {}", e))
  })?;

  for (file_path, file_data) in collab_data {
    zip
      .start_file(format!("collab_objects/{}", file_path), options)
      .map_err(|e| {
        FlowyError::internal().with_context(format!(
          "Failed to start file '{}' in ZIP: {}",
          file_path, e
        ))
      })?;
    zip.write_all(file_data).map_err(|e| {
      FlowyError::internal().with_context(format!(
        "Failed to write file '{}' to ZIP: {}",
        file_path, e
      ))
    })?;
  }

  for (file_path, file_data) in doc_state_to_json {
    zip
      .start_file(format!("collab_jsons/{}", file_path), options)
      .map_err(|e| {
        FlowyError::internal().with_context(format!(
          "Failed to start file '{}' in ZIP: {}",
          file_path, e
        ))
      })?;
    zip.write_all(file_data.as_bytes()).map_err(|e| {
      FlowyError::internal().with_context(format!(
        "Failed to write file '{}' to ZIP: {}",
        file_path, e
      ))
    })?;
  }

  for (file_path, file_data) in local_files {
    zip
      .start_file(format!("local_files/{}", file_path), options)
      .map_err(|e| {
        FlowyError::internal().with_context(format!(
          "Failed to start local file '{}' in ZIP: {}",
          file_path, e
        ))
      })?;
    zip.write_all(file_data).map_err(|e| {
      FlowyError::internal().with_context(format!(
        "Failed to write local file '{}' to ZIP: {}",
        file_path, e
      ))
    })?;
  }

  let metadata = serde_json::json!({
    "export_info": {
      "workspace_id": relation_map.workspace_id,
      "export_timestamp": relation_map.export_timestamp,
      "total_views": relation_map.views.len(),
      "total_dependencies": relation_map.dependencies.len(),
      "total_collab_files": collab_data.len(),
      "total_local_files": local_files.len(),
      "archive_format": "zip",
      "version": "1.0"
    },
    "files": collab_data.keys().collect::<Vec<_>>()
  });

  let metadata_json = serde_json::to_string_pretty(&metadata).map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to serialize metadata to JSON: {}", e))
  })?;

  zip.start_file("metadata.json", options).map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to start metadata.json file in ZIP: {}", e))
  })?;
  zip.write_all(metadata_json.as_bytes()).map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to write metadata.json to ZIP: {}", e))
  })?;

  zip.finish().map_err(|e| {
    FlowyError::internal().with_context(format!("Failed to finalize ZIP archive: {}", e))
  })?;

  Ok(())
}
