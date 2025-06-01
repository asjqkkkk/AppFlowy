use crate::event_builder::EventBuilder;
use crate::EventIntegrationTest;
use collab::core::collab::{default_client_id, CollabOptions};
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::preclude::updates::decoder::Decode;
use collab::preclude::{Collab, Update};
use collab_document::blocks::DocumentData;
use collab_document::document::Document;
use collab_entity::CollabType;
use flowy_document::entities::{
  ApplyActionPayloadPB, BlockActionPB, BlockActionPayloadPB, BlockActionTypePB, BlockPB,
  DocumentDataPB, DocumentRedoUndoPayloadPB, DocumentRedoUndoResponsePB, DocumentSnapshotMetaPB,
  DocumentSnapshotPB, DocumentTextPB, EncodedCollabPB, OpenDocumentPayloadPB,
  RepeatedDocumentSnapshotMetaPB, TextDeltaPayloadPB,
};
use flowy_document::event_map::DocumentEvent;
use flowy_document::parser::parser_entities::{
  ConvertDataToJsonPayloadPB, ConvertDataToJsonResponsePB, ConvertDocumentPayloadPB,
  ConvertDocumentResponsePB,
};
use flowy_error::FlowyResult;
use flowy_folder::entities::{CreateViewPayloadPB, ViewLayoutPB, ViewPB};
use flowy_folder::event_map::FolderEvent;
use nanoid::nanoid;
use serde_json::{json, Value};
use std::collections::HashMap;
use uuid::Uuid;

pub struct OpenDocumentData {
  pub id: String,
  pub data: DocumentDataPB,
}

// Helper functions for document operations
fn gen_id() -> String {
  nanoid!(10)
}

fn gen_text_block_data() -> String {
  json!({}).to_string()
}

fn gen_delta_str(text: &str) -> String {
  json!([{ "insert": text }]).to_string()
}

const TEXT_BLOCK_TY: &str = "paragraph";

impl EventIntegrationTest {
  pub async fn create_document(&self, name: &str, parent_id: Uuid) -> ViewPB {
    let payload = CreateViewPayloadPB {
      parent_view_id: parent_id.to_string(),
      name: name.to_string(),
      thumbnail: None,
      layout: ViewLayoutPB::Document,
      initial_data: vec![],
      meta: Default::default(),
      set_as_current: true,
      index: None,
      section: None,
      view_id: None,
      extra: None,
    };
    EventBuilder::new(self.clone())
      .event(FolderEvent::CreateView)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<ViewPB>()
  }

  // Create document without specifying parent (uses current workspace)
  pub async fn create_document_simple(&self) -> ViewPB {
    let current_workspace = self.get_current_workspace().await;
    let parent_id = Uuid::parse_str(&current_workspace.id).unwrap();

    let payload = CreateViewPayloadPB {
      parent_view_id: parent_id.to_string(),
      name: "document".to_string(),
      thumbnail: None,
      layout: ViewLayoutPB::Document,
      initial_data: vec![],
      meta: Default::default(),
      set_as_current: true,
      index: None,
      section: None,
      view_id: None,
      extra: None,
    };
    EventBuilder::new(self.clone())
      .event(FolderEvent::CreateView)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<ViewPB>()
  }

  pub async fn create_and_open_document(
    &self,
    parent_id: &str,
    name: String,
    initial_data: Vec<u8>,
  ) -> ViewPB {
    let payload = CreateViewPayloadPB {
      parent_view_id: parent_id.to_string(),
      name,
      thumbnail: None,
      layout: ViewLayoutPB::Document,
      initial_data,
      meta: Default::default(),
      set_as_current: true,
      index: None,
      section: None,
      view_id: None,
      extra: None,
    };
    let view = EventBuilder::new(self.clone())
      .event(FolderEvent::CreateView)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<ViewPB>();

    let payload = OpenDocumentPayloadPB {
      document_id: view.id.clone(),
    };

    let _ = EventBuilder::new(self.clone())
      .event(DocumentEvent::OpenDocument)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<DocumentDataPB>();

    view
  }

  pub async fn open_document(&self, doc_id: String) -> OpenDocumentData {
    let payload = OpenDocumentPayloadPB {
      document_id: doc_id.clone(),
    };
    let data = EventBuilder::new(self.clone())
      .event(DocumentEvent::OpenDocument)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<DocumentDataPB>();
    OpenDocumentData { id: doc_id, data }
  }

  pub async fn get_encoded_v1(&self, doc_id: &Uuid) -> EncodedCollab {
    let doc = self
      .appflowy_core
      .document_manager
      .editable_document(doc_id)
      .await
      .unwrap();
    let guard = doc.read().await;
    guard.encode_collab().unwrap()
  }

  pub async fn get_encoded_collab(&self, doc_id: &str) -> EncodedCollabPB {
    let payload = OpenDocumentPayloadPB {
      document_id: doc_id.to_string(),
    };
    EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocEncodedCollab)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<EncodedCollabPB>()
  }

  async fn get_page_id(&self, document_id: &str) -> String {
    let document_data = self.open_document(document_id.to_string()).await;
    document_data.data.page_id
  }

  pub async fn get_block(&self, doc_id: &str, block_id: &str) -> Option<BlockPB> {
    let document_data = self.open_document(doc_id.to_string()).await;
    document_data.data.blocks.get(block_id).cloned()
  }

  pub async fn get_document_data_pb(&self, doc_id: &str) -> DocumentDataPB {
    let document_data = self.open_document(doc_id.to_string()).await;
    document_data.data
  }

  async fn get_block_children(&self, doc_id: &str, block_id: &str) -> Option<Vec<String>> {
    let block = self.get_block(doc_id, block_id).await;
    block.as_ref()?;
    let document_data = self.open_document(doc_id.to_string()).await;
    let children_map = document_data.data.meta.children_map;
    let children_id = block.unwrap().children_id;
    children_map.get(&children_id).map(|c| c.children.clone())
  }

  pub async fn get_text_id(&self, doc_id: &str, block_id: &str) -> Option<String> {
    let block = self.get_block(doc_id, block_id).await?;
    block.external_id
  }

  pub async fn get_delta(&self, doc_id: &str, text_id: &str) -> Option<String> {
    let document_data = self.get_document_data_pb(doc_id).await;
    document_data.meta.text_map.get(text_id).cloned()
  }

  async fn create_text(&self, payload: TextDeltaPayloadPB) {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::CreateText)
      .payload(payload)
      .async_send()
      .await;
  }

  pub async fn apply_text_delta(&self, payload: TextDeltaPayloadPB) {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::ApplyTextDeltaEvent)
      .payload(payload)
      .async_send()
      .await;
  }

  pub async fn apply_actions(&self, payload: ApplyActionPayloadPB) {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::ApplyAction)
      .payload(payload)
      .async_send()
      .await;
  }

  pub async fn undo(&self, doc_id: String) -> DocumentRedoUndoResponsePB {
    let payload = DocumentRedoUndoPayloadPB {
      document_id: doc_id.clone(),
    };
    EventBuilder::new(self.clone())
      .event(DocumentEvent::Undo)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<DocumentRedoUndoResponsePB>()
  }

  pub async fn redo(&self, doc_id: String) -> DocumentRedoUndoResponsePB {
    let payload = DocumentRedoUndoPayloadPB {
      document_id: doc_id.clone(),
    };
    EventBuilder::new(self.clone())
      .event(DocumentEvent::Redo)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<DocumentRedoUndoResponsePB>()
  }

  pub async fn can_undo_redo(&self, doc_id: String) -> DocumentRedoUndoResponsePB {
    let payload = DocumentRedoUndoPayloadPB {
      document_id: doc_id.clone(),
    };
    EventBuilder::new(self.clone())
      .event(DocumentEvent::CanUndoRedo)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<DocumentRedoUndoResponsePB>()
  }

  pub async fn convert_document(
    &self,
    payload: ConvertDocumentPayloadPB,
  ) -> ConvertDocumentResponsePB {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::ConvertDocument)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<ConvertDocumentResponsePB>()
  }

  pub async fn convert_data_to_json(
    &self,
    payload: ConvertDataToJsonPayloadPB,
  ) -> ConvertDataToJsonResponsePB {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::ConvertDataToJSON)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<ConvertDataToJsonResponsePB>()
  }

  pub async fn get_document_snapshot_metas(&self, doc_id: &str) -> Vec<DocumentSnapshotMetaPB> {
    let payload = OpenDocumentPayloadPB {
      document_id: doc_id.to_string(),
    };
    EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocumentSnapshotMeta)
      .payload(payload)
      .async_send()
      .await
      .parse_or_panic::<RepeatedDocumentSnapshotMetaPB>()
      .items
  }

  pub async fn get_document_snapshot(
    &self,
    snapshot_meta: DocumentSnapshotMetaPB,
  ) -> DocumentSnapshotPB {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocumentSnapshot)
      .payload(snapshot_meta)
      .async_send()
      .await
      .parse_or_panic::<DocumentSnapshotPB>()
  }

  /// Insert a new text block at the index of parent's children.
  /// return the new block id.
  pub async fn insert_index(
    &self,
    document_id: &str,
    text: &str,
    index: usize,
    parent_id: Option<&str>,
  ) -> String {
    let text = text.to_string();
    let page_id = self.get_page_id(document_id).await;
    let parent_id = parent_id
      .map(|id| id.to_string())
      .unwrap_or_else(|| page_id);
    let parent_children = self.get_block_children(document_id, &parent_id).await;

    let prev_id = {
      // If index is 0, then the new block will be the first child of parent.
      if index == 0 {
        None
      } else {
        parent_children.and_then(|children| {
          // If index is greater than the length of children, then the new block will be the last child of parent.
          if index >= children.len() {
            children.last().cloned()
          } else {
            children.get(index - 1).cloned()
          }
        })
      }
    };

    let new_block_id = gen_id();
    let data = gen_text_block_data();

    let external_id = gen_id();
    let external_type = "text".to_string();

    self
      .create_text(TextDeltaPayloadPB {
        document_id: document_id.to_string(),
        text_id: external_id.clone(),
        delta: Some(gen_delta_str(&text)),
      })
      .await;

    let new_block = BlockPB {
      id: new_block_id.clone(),
      ty: TEXT_BLOCK_TY.to_string(),
      data,
      parent_id: parent_id.clone(),
      children_id: gen_id(),
      external_id: Some(external_id),
      external_type: Some(external_type),
    };
    let action = BlockActionPB {
      action: BlockActionTypePB::Insert,
      payload: BlockActionPayloadPB {
        block: Some(new_block),
        prev_id,
        parent_id: Some(parent_id),
        text_id: None,
        delta: None,
      },
    };
    let payload = ApplyActionPayloadPB {
      document_id: document_id.to_string(),
      actions: vec![action],
    };
    self.apply_actions(payload).await;
    new_block_id
  }

  pub async fn update_data(&self, document_id: &str, block_id: &str, data: HashMap<String, Value>) {
    let block = self.get_block(document_id, block_id).await.unwrap();

    let new_block = {
      let mut new_block = block.clone();
      new_block.data = serde_json::to_string(&data).unwrap();
      new_block
    };
    let action = BlockActionPB {
      action: BlockActionTypePB::Update,
      payload: BlockActionPayloadPB {
        block: Some(new_block),
        prev_id: None,
        parent_id: Some(block.parent_id.clone()),
        text_id: None,
        delta: None,
      },
    };
    let payload = ApplyActionPayloadPB {
      document_id: document_id.to_string(),
      actions: vec![action],
    };
    self.apply_actions(payload).await;
  }

  pub async fn delete_block(&self, document_id: &str, block_id: &str) {
    let block = self.get_block(document_id, block_id).await.unwrap();
    let parent_id = block.parent_id.clone();
    let action = BlockActionPB {
      action: BlockActionTypePB::Delete,
      payload: BlockActionPayloadPB {
        block: Some(block),
        prev_id: None,
        parent_id: Some(parent_id),
        text_id: None,
        delta: None,
      },
    };
    let payload = ApplyActionPayloadPB {
      document_id: document_id.to_string(),
      actions: vec![action],
    };
    self.apply_actions(payload).await;
  }

  pub async fn insert_document_text(&self, document_id: &str, text: &str, index: usize) {
    let text = text.to_string();
    let page_id = self.get_page_id(document_id).await;
    let parent_id = page_id.clone();
    let parent_children = self.get_block_children(document_id, &parent_id).await;

    let prev_id = {
      // If index is 0, then the new block will be the first child of parent.
      if index == 0 {
        None
      } else {
        parent_children.and_then(|children| {
          // If index is greater than the length of children, then the new block will be the last child of parent.
          if index >= children.len() {
            children.last().cloned()
          } else {
            children.get(index - 1).cloned()
          }
        })
      }
    };

    let new_block_id = gen_id();
    let data = gen_text_block_data();
    let external_id = gen_id();
    let external_type = "text".to_string();

    // Create the text content
    self
      .create_text(TextDeltaPayloadPB {
        document_id: document_id.to_string(),
        text_id: external_id.clone(),
        delta: Some(gen_delta_str(&text)),
      })
      .await;

    // Create the new block
    let new_block = BlockPB {
      id: new_block_id.clone(),
      ty: TEXT_BLOCK_TY.to_string(),
      data,
      parent_id: parent_id.clone(),
      children_id: gen_id(),
      external_id: Some(external_id),
      external_type: Some(external_type),
    };

    // Apply the insert action
    let action = BlockActionPB {
      action: BlockActionTypePB::Insert,
      payload: BlockActionPayloadPB {
        block: Some(new_block),
        prev_id,
        parent_id: Some(parent_id),
        text_id: None,
        delta: None,
      },
    };
    let payload = ApplyActionPayloadPB {
      document_id: document_id.to_string(),
      actions: vec![action],
    };
    self.apply_actions(payload).await;
  }

  pub async fn get_document_data(&self, view_id: &str) -> DocumentData {
    let pb = EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocumentData)
      .payload(OpenDocumentPayloadPB {
        document_id: view_id.to_string(),
      })
      .async_send()
      .await
      .parse_or_panic::<DocumentDataPB>();

    DocumentData::from(pb)
  }

  pub async fn get_document_text_or_panic(&self, view_id: &str) -> DocumentTextPB {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocumentText)
      .payload(OpenDocumentPayloadPB {
        document_id: view_id.to_string(),
      })
      .async_send()
      .await
      .parse_or_panic::<DocumentTextPB>()
  }

  pub async fn get_document_text(&self, view_id: &str) -> FlowyResult<DocumentTextPB> {
    EventBuilder::new(self.clone())
      .event(DocumentEvent::GetDocumentText)
      .payload(OpenDocumentPayloadPB {
        document_id: view_id.to_string(),
      })
      .async_send()
      .await
      .parse::<DocumentTextPB>()
  }

  pub async fn get_document_doc_state(&self, document_id: &str) -> Vec<u8> {
    self
      .get_collab_doc_state(document_id, CollabType::Document)
      .await
      .unwrap()
  }
}

pub fn assert_document_data_equal(doc_state: &[u8], doc_id: &str, expected: DocumentData) {
  let options = CollabOptions::new(doc_id.to_string(), default_client_id());
  let mut collab = Collab::new_with_options(CollabOrigin::Server, options).unwrap();
  {
    let update = Update::decode_v1(doc_state).unwrap();
    let mut txn = collab.transact_mut();
    txn.apply_update(update).unwrap();
  };
  let document = Document::open(collab).unwrap();
  let actual = document.get_document_data().unwrap();
  assert_eq!(actual, expected);
}
