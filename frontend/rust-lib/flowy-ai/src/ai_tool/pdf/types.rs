use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// The AI model used for image analysis and text extraction
/// Consider using more capable models like "llava" or "bakllava" for better OCR results
pub const IMAGE_LLM_MODEL: &str = "gemma3:4b";

/// Represents the extracted content from a PDF document
///
/// Content is automatically ordered by page number due to the use of BTreeMap,
/// ensuring that parallel processing doesn't affect the final output order.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdfContent {
  /// Text content organized by page number (BTreeMap ensures sorted order)
  pub text: BTreeMap<u32, Vec<String>>,
  /// Collection of errors encountered during extraction
  pub errors: Vec<String>,
}

impl PdfContent {
  /// Creates a new empty PdfContent
  pub fn new() -> Self {
    Self {
      text: BTreeMap::new(),
      errors: Vec::new(),
    }
  }

  /// Converts the content into a single string with all text
  pub fn into_text(self) -> String {
    let mut result = String::new();

    // BTreeMap ensures pages are iterated in sorted order (1, 2, 3, ...)
    for (page, lines) in self.text.into_iter() {
      // Add page marker for clarity (optional, can be removed if not needed)
      if !result.is_empty() {
        result.push('\n');
      }
      result.push_str(&format!("--- Page {} ---\n", page));

      for line in lines {
        result.push_str(&line);
        result.push('\n');
      }
    }
    result
  }

  /// Converts the content into a single string without page markers
  pub fn into_text_plain(self) -> String {
    let mut result = String::new();
    for (_page, lines) in self.text.into_iter() {
      for line in lines {
        result.push_str(&line);
        result.push('\n');
      }
    }
    result
  }

  /// Adds an error message with page context
  pub fn add_error(&mut self, page: u32, error: impl std::fmt::Display) {
    self.errors.push(format!("page {}: {}", page, error));
  }

  /// Adds text content to a specific page
  pub fn add_text(&mut self, page: u32, text: String) {
    self.text.entry(page).or_default().push(text);
  }

  /// Returns content as a vector of (page_number, text_lines) tuples, sorted by page number
  pub fn get_ordered_content(&self) -> Vec<(u32, Vec<String>)> {
    self
      .text
      .iter()
      .map(|(page, lines)| (*page, lines.clone()))
      .collect()
  }

  /// Gets all text from a specific page
  pub fn get_page_text(&self, page: u32) -> Option<&Vec<String>> {
    self.text.get(&page)
  }
}

impl Default for PdfContent {
  fn default() -> Self {
    Self::new()
  }
}

/// Configuration for PDF reading operations
#[derive(Debug, Clone)]
pub struct PdfConfig {
  /// The AI model to use for image analysis
  pub image_model: String,
  /// Whether to extract images from the PDF
  pub extract_images: bool,
  /// Whether to extract text from the PDF
  pub extract_text: bool,
  /// Maximum number of concurrent image processing tasks
  pub max_concurrent_images: usize,
  /// Maximum number of concurrent page processing tasks
  pub max_concurrent_pages: usize,
}

impl PdfConfig {
  pub fn new() -> Self {
    Self::default()
  }

  pub fn with_image_model(mut self, model: &str) -> Self {
    self.image_model = model.to_string();
    self
  }

  pub fn with_concurrent_images(mut self, limit: usize) -> Self {
    self.max_concurrent_images = limit;
    self
  }

  pub fn with_concurrent_pages(mut self, limit: usize) -> Self {
    self.max_concurrent_pages = limit;
    self
  }
}

impl Default for PdfConfig {
  fn default() -> Self {
    Self {
      image_model: IMAGE_LLM_MODEL.to_string(),
      extract_images: true,
      extract_text: true,
      max_concurrent_images: 10,
      max_concurrent_pages: 5,
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_content_ordering_maintained() {
    let mut content = PdfContent::new();

    // Add pages out of order (simulating parallel processing)
    content.add_text(5, "Content from page 5".to_string());
    content.add_text(2, "Content from page 2".to_string());
    content.add_text(10, "Content from page 10".to_string());
    content.add_text(1, "Content from page 1".to_string());
    content.add_text(3, "Content from page 3".to_string());

    // Get ordered content
    let ordered = content.get_ordered_content();

    // Verify pages are in correct order
    assert_eq!(ordered.len(), 5);
    assert_eq!(ordered[0].0, 1);
    assert_eq!(ordered[1].0, 2);
    assert_eq!(ordered[2].0, 3);
    assert_eq!(ordered[3].0, 5);
    assert_eq!(ordered[4].0, 10);

    // Verify into_text maintains order
    let text = content.clone().into_text();
    assert!(text.contains("--- Page 1 ---\nContent from page 1"));
    assert!(text.contains("--- Page 2 ---\nContent from page 2"));
    assert!(text.contains("--- Page 3 ---\nContent from page 3"));

    // Verify pages appear in correct sequence
    let page1_pos = text.find("Page 1").unwrap();
    let page2_pos = text.find("Page 2").unwrap();
    let page3_pos = text.find("Page 3").unwrap();
    let page5_pos = text.find("Page 5").unwrap();
    let page10_pos = text.find("Page 10").unwrap();

    assert!(page1_pos < page2_pos);
    assert!(page2_pos < page3_pos);
    assert!(page3_pos < page5_pos);
    assert!(page5_pos < page10_pos);
  }
}
