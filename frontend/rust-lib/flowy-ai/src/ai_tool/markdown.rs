#![allow(dead_code)]

use std::fs;
use std::path::PathBuf;

pub struct MdReader {
  path: PathBuf,
}

impl MdReader {
  pub fn new<P: Into<PathBuf>>(path: P) -> Self {
    MdReader { path: path.into() }
  }

  pub fn read_markdown(&self) -> std::io::Result<String> {
    let content = fs::read_to_string(&self.path)?;
    Ok(content)
  }
}
