use flowy_ai::ai_tool::pdf::PdfReader;
use std::path::PathBuf;

#[test]
#[ignore]
fn extract_pdf_content() {
  let reader = PdfReader::new(PathBuf::from("tests/asset/AppFlowy_Values.pdf"));
  let out = reader.read_all().unwrap();
  dbg!(out);
}
