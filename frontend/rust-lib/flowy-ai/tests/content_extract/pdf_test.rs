use flowy_ai::ai_tool::pdf::{PdfConfig, PdfReader};
use std::path::PathBuf;

#[tokio::test]
async fn local_ai_test_extract_pdf_content() {
  let reader = PdfReader::with_config(
    PathBuf::from("tests/asset/AppFlowy_Values.pdf"),
    PdfConfig::default(),
  );
  let out = reader.read_all().await.unwrap();
  dbg!(out);
}

#[tokio::test]
async fn local_ai_test_extract_blood_pressure_image_pdf_content() {
  let _ = tracing_subscriber::fmt()
    .with_env_filter("flowy_ai=debug")
    .try_init();

  let reader = PdfReader::with_config(
    PathBuf::from("tests/asset/blood_pressure.pdf"),
    PdfConfig::default(),
  );
  let out = reader.read_all().await.unwrap();
  dbg!(&out.errors);
  dbg!(&out);
  assert!(out.errors.is_empty());
  let text = out.into_text();
  dbg!(&text);
  // With image processing, we should get text descriptions of images
  assert!(!text.is_empty() || text.contains("[Image:"));
}

#[tokio::test]
#[ignore]
async fn extract_zao_onsen_image_pdf_content() {
  // let _ = tracing_subscriber::fmt()
  //   .with_env_filter("flowy_ai=debug")
  //   .try_init();

  let reader = PdfReader::with_config(
    PathBuf::from("tests/asset/zao_onsen_ski.pdf"),
    PdfConfig::default(),
  );
  let out = reader.read_all().await.unwrap();
  dbg!(&out.errors);
  dbg!(&out);
  assert!(out.errors.is_empty());

  let text = out.into_text();
  dbg!(&text);
  // With image processing, we should get text descriptions of images
  assert!(!text.is_empty() && text.contains("[Image:"));
}
