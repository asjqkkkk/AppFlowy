use crate::ai_tool::pdf::types::PdfContent;
use flowy_error::{FlowyError, FlowyResult};
use lopdf::Document;
use rayon::prelude::*;

/// Extracts text content from a PDF document
pub fn extract_text(doc: &Document, content: &mut PdfContent) -> FlowyResult<()> {
  let text_results: Vec<_> = doc
    .get_pages()
    .par_iter()
    .map(|(&page, _)| {
      let result = doc
        .extract_text(&[page])
        .map(|text| {
          let raw_lines: Vec<String> = text
            .lines()
            .map(|line| line.trim().to_owned())
            .filter(|line| !line.is_empty())
            .collect();

          join_text_fragments(raw_lines)
        })
        .map_err(|e| FlowyError::invalid_data().with_context(e));
      (page, result)
    })
    .collect();

  // Process results and add to content
  for (page, result) in text_results {
    match result {
      Ok(lines) => {
        for line in lines {
          content.add_text(page, line);
        }
      },
      Err(e) => content.add_error(page, e),
    }
  }

  Ok(())
}

/// Intelligently joins text fragments that were split during PDF extraction
pub fn join_text_fragments(fragments: Vec<String>) -> Vec<String> {
  if fragments.is_empty() {
    return vec![];
  }

  let mut result = Vec::new();
  let mut current_sentence = String::new();

  for fragment in fragments {
    let should_start_new = should_start_new_sentence(&current_sentence, &fragment);

    if should_start_new && !current_sentence.is_empty() {
      // Save the current sentence and start a new one
      result.push(current_sentence.trim().to_string());
      current_sentence = fragment;
    } else {
      // Continue building the current sentence
      if !current_sentence.is_empty() {
        current_sentence.push(' ');
      }
      current_sentence.push_str(&fragment);
    }
  }

  // Don't forget the last sentence
  if !current_sentence.is_empty() {
    result.push(current_sentence.trim().to_string());
  }

  result
}

/// Determines if a text fragment should start a new sentence
fn should_start_new_sentence(current: &str, fragment: &str) -> bool {
  if current.is_empty() {
    return true;
  }

  // Check if previous fragment ended with sentence-ending punctuation
  let trimmed_current = current.trim_end();
  let ends_with_sentence_end = trimmed_current.ends_with('.')
    || trimmed_current.ends_with('!')
    || trimmed_current.ends_with('?')
    || trimmed_current.ends_with(':');

  // Check if this fragment starts with a capital letter (likely new sentence)
  let starts_with_capital = fragment
    .chars()
    .next()
    .map(|c| c.is_uppercase())
    .unwrap_or(false);

  ends_with_sentence_end && starts_with_capital
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_join_text_fragments() {
    let fragments = vec![
      "This is a sentence.".to_string(),
      "Another sentence starts here".to_string(),
      "and continues on this line".to_string(),
      "without stopping.".to_string(),
      "Final sentence.".to_string(),
    ];

    let result = join_text_fragments(fragments);
    assert_eq!(result.len(), 3);
    assert_eq!(result[0], "This is a sentence.");
    assert_eq!(
      result[1],
      "Another sentence starts here and continues on this line without stopping."
    );
    assert_eq!(result[2], "Final sentence.");
  }

  #[test]
  fn test_should_start_new_sentence() {
    assert!(should_start_new_sentence("", "Any text"));
    assert!(should_start_new_sentence("End.", "Start"));
    assert!(should_start_new_sentence("Question?", "Answer"));
    assert!(!should_start_new_sentence("No period", "continues"));
    assert!(!should_start_new_sentence("End.", "but lowercase"));
  }
}
