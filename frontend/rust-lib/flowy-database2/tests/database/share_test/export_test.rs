use flowy_database2::entities::FieldType;
use flowy_database2::services::cell::stringify_cell;
use flowy_database2::services::share::csv::CSVFormat;

use crate::database::database_editor::DatabaseEditorTest;

#[tokio::test]
async fn export_meta_csv_test() {
  let test = DatabaseEditorTest::new_grid().await;
  let database = test.editor.clone();
  let s = database.export_csv(CSVFormat::META).await.unwrap();
  let mut reader = csv::Reader::from_reader(s.as_bytes());
  for header in reader.headers().unwrap() {
    dbg!(header);
  }

  let export_csv_records = reader.records();
  for record in export_csv_records {
    let record = record.unwrap();
    dbg!(record);
  }
}

#[tokio::test]
async fn export_and_then_import_meta_csv_test() {
  let test = DatabaseEditorTest::new_grid().await;
  let database = test.editor.clone();
  let format = CSVFormat::META;
  let csv_1 = database.export_csv(format).await.unwrap();

  let result = test.import(csv_1.clone(), format).await;
  let database = test.get_database(&result.database_id).await.unwrap();

  let fields = database.get_fields(&result.view_id, None).await;
  let rows = database.get_all_rows(&result.view_id).await.unwrap();
  assert_eq!(fields[0].field_type, 0);
  assert_eq!(fields[1].field_type, 1);
  assert_eq!(fields[2].field_type, 2);
  assert_eq!(fields[3].field_type, 3);
  assert_eq!(fields[4].field_type, 4);
  assert_eq!(fields[5].field_type, 5);
  assert_eq!(fields[6].field_type, 6);
  assert_eq!(fields[7].field_type, 7);
  assert_eq!(fields[8].field_type, 8);
  assert_eq!(fields[9].field_type, 9);

  for field in fields {
    for (index, row) in rows.iter().enumerate() {
      if let Some(cell) = row.cells.get(&field.id) {
        let field_type = FieldType::from(field.field_type);
        let s = stringify_cell(cell, &field);
        match &field_type {
          FieldType::RichText => {
            if index == 0 {
              assert_eq!(s, "A");
            }
          },
          FieldType::Number => {
            if index == 0 {
              assert_eq!(s, "$1");
            }
          },
          FieldType::DateTime => {
            if index == 0 {
              assert_eq!(s, "2022/03/14");
            }
          },
          FieldType::SingleSelect => {
            if index == 0 {
              assert_eq!(s, "");
            }
          },
          FieldType::MultiSelect => {
            if index == 0 {
              assert_eq!(s, "Google,Facebook");
            }
          },
          FieldType::Checkbox
          | FieldType::URL
          | FieldType::Checklist
          | FieldType::LastEditedTime
          | FieldType::CreatedTime
          | FieldType::Relation
          | FieldType::Summary
          | FieldType::Time
          | FieldType::Translate
          | FieldType::Media => {},
        }
      } else {
        panic!(
          "Can not found the cell with id: {} in {:?}",
          field.id, row.cells
        );
      }
    }
  }
}
