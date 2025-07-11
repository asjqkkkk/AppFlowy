use flowy_error::{FlowyError, FlowyResult};
use lopdf::{Document, Object};
use rayon::iter::{IntoParallelIterator, ParallelIterator};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
pub struct PdfReader {
  path: PathBuf,
}

impl PdfReader {
  pub fn new(path: PathBuf) -> Self {
    PdfReader { path }
  }

  pub fn read_all(&self) -> FlowyResult<String> {
    let doc = load_pdf(&self.path)?;
    // if doc.is_encrypted() {
    // }
    let text = get_pdf_text(&doc)?.into_text();
    Ok(text)
  }
}

fn load_pdf<P: AsRef<Path>>(path: P) -> FlowyResult<Document> {
  Document::load_filtered(path, filter_func).map_err(|err| FlowyError::internal().with_context(err))
}

static IGNORE: &[&[u8]] = &[
  b"Length",
  b"BBox",
  b"FormType",
  b"Matrix",
  b"Type",
  b"XObject",
  b"Subtype",
  b"Filter",
  b"ColorSpace",
  b"Width",
  b"Height",
  b"BitsPerComponent",
  b"Length1",
  b"Length2",
  b"Length3",
  b"PTEX.FileName",
  b"PTEX.PageNumber",
  b"PTEX.InfoDict",
  b"FontDescriptor",
  b"ExtGState",
  b"MediaBox",
  b"Annot",
];
fn filter_func(object_id: (u32, u16), object: &mut Object) -> Option<((u32, u16), Object)> {
  if IGNORE.contains(&object.type_name().unwrap_or_default()) {
    return None;
  }
  if let Ok(d) = object.as_dict_mut() {
    d.remove(b"Producer");
    d.remove(b"ModDate");
    d.remove(b"Creator");
    d.remove(b"ProcSet");
    d.remove(b"Procset");
    d.remove(b"XObject");
    d.remove(b"MediaBox");
    d.remove(b"Annots");
    if d.is_empty() {
      return None;
    }
  }
  Some((object_id, object.to_owned()))
}

fn get_pdf_text(doc: &Document) -> FlowyResult<PdfText> {
  let mut pdf_text: PdfText = PdfText {
    text: BTreeMap::new(),
    errors: Vec::new(),
  };
  let pages: Vec<Result<(u32, Vec<String>), FlowyError>> = doc
    .get_pages()
    .into_par_iter()
    .map(
      |(page_num, _): (u32, (u32, u16))| -> Result<(u32, Vec<String>), FlowyError> {
        let text = doc
          .extract_text(&[page_num])
          .map_err(|e| FlowyError::invalid_data().with_context(e))?;

        Ok((
          page_num,
          text
            .split('\n')
            .map(|s| s.trim_end().to_string())
            .collect::<Vec<String>>(),
        ))
      },
    )
    .collect();
  for page in pages {
    match page {
      Ok((page_num, lines)) => {
        pdf_text.text.insert(page_num, lines);
      },
      Err(e) => {
        pdf_text.errors.push(e.to_string());
      },
    }
  }
  Ok(pdf_text)
}

#[derive(Debug, Deserialize, Serialize)]
struct PdfText {
  text: BTreeMap<u32, Vec<String>>, // Key is page number
  errors: Vec<String>,
}

impl PdfText {
  pub fn into_text(self) -> String {
    let mut text = String::new();
    for (_, lines) in self.text {
      text.extend(lines);
      text.push('\n');
    }

    text
  }
}
