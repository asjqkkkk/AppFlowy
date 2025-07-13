use crate::SqliteVectorStore;
use crate::ai_tool::text_split::RAGSource;
use crate::local_ai::chat::chains::context_question_chain::{
  ContextRelatedQuestionChain, embedded_documents_to_context_str,
};
use crate::local_ai::chat::chains::related_question_chain::RelatedQuestionChain;
use crate::local_ai::chat::llm::LLMOllama;
use crate::local_ai::chat::llm_chat::EmbedFile;
use crate::local_ai::chat::retriever::{AFEmbedder, AFRetriever, EmbedFileProgress};
use arc_swap::ArcSwap;
use async_trait::async_trait;
use flowy_ai_pub::cloud::{ContextSuggestedQuestion, QuestionStreamValue};
use flowy_ai_pub::entities::{SOURCE, SOURCE_ID, SOURCE_NAME};
use flowy_error::{FlowyError, FlowyResult};
use flowy_sqlite_vec::entities::EmbeddedContent;
use futures::Stream;
use futures_util::StreamExt;
use langchain_rust::chain::{
  Chain, ChainError, CondenseQuestionGeneratorChain, CondenseQuestionPromptBuilder,
  StuffDocumentBuilder, StuffQAPromptBuilder,
};
use langchain_rust::language_models::{GenerateResult, TokenUsage};
use langchain_rust::memory::SimpleMemory;
use langchain_rust::prompt::{FormatPrompter, PromptArgs};
use langchain_rust::schemas::{BaseMemory, Document, Message, StreamData};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::path::PathBuf;
use std::{collections::HashMap, pin::Pin, sync::Arc};
use tokio::sync::Mutex;
use tokio::sync::oneshot;
use tokio_util::either::Either;
use tracing::{debug, error, trace};
use uuid::Uuid;

pub const CAN_NOT_ANSWER_WITH_CONTEXT: &str = "I couldn't find any relevant information in the sources you selected. Please try asking a different question or remove selected sources";
pub const ANSWER_WITH_SUGGESTED_QUESTION: &str = "I couldn't find any relevant information in the sources you selected. Please try ask following questions";
pub(crate) const DEFAULT_OUTPUT_KEY: &str = "output";
pub(crate) const DEFAULT_RESULT_KEY: &str = "generate_result";

#[derive(Debug, Clone)]
pub enum SuccessOrError {
  Success { file_content: String },
  Error(String),
}

#[derive(Debug, Clone)]
pub struct EmbedFileResult {
  pub file_path: PathBuf,
  pub result: SuccessOrError,
}

const CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_SOURCE_DOCUMENT_KEY: &str = "source_documents";
const CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_GENERATED_QUESTION_KEY: &str = "generated_question";
const CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_INPUT_KEY: &str = "question";

type EmbedFileStream = Pin<Box<dyn Stream<Item = Result<StreamData, ChainError>> + Send>>;
type ResponseStream = Pin<Box<dyn Stream<Item = Result<StreamData, ChainError>> + Send>>;
pub struct ConversationalRetrieverChain {
  pub(crate) ollama: LLMOllama,
  pub(crate) retriever: Box<dyn AFRetriever>,
  pub(crate) embedder: Arc<dyn AFEmbedder>,
  pub memory: Arc<Mutex<dyn BaseMemory>>,
  pub(crate) combine_documents_chain: Arc<dyn Chain>,
  pub(crate) condense_question_chain: Arc<dyn Chain>,
  pub(crate) context_question_chain: Option<ContextRelatedQuestionChain>,
  pub(crate) rephrase_question: bool,
  pub(crate) return_source_documents: bool,
  pub(crate) input_key: String,
  pub(crate) output_key: String,
  latest_context: ArcSwap<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum StreamValue {
  Answer {
    value: String,
  },
  ContextSuggested {
    value: String,
    suggested_questions: Vec<ContextSuggestedQuestion>,
  },
}

impl ConversationalRetrieverChain {
  async fn handle_attachments(
    &self,
    history: Vec<Message>,
    input_variables: PromptArgs,
    files: Vec<EmbedFile>,
  ) -> Result<ResponseStream, ChainError> {
    let input_variable = &input_variables
      .get(&self.input_key)
      .ok_or(ChainError::MissingInputVariable(self.input_key.clone()))?;
    let input = input_variable.to_string();

    let (embed_results_sender, embed_results_recv) = tokio::sync::oneshot::channel();
    let embed_file_stream = self.create_embed_files_stream(files, Some(embed_results_sender));

    let rephrase_question = self.rephrase_question;
    let combine_documents_chain = self.combine_documents_chain.clone();
    let condense_question_chain = self.condense_question_chain.clone();
    let ollama = self.ollama.clone();
    let memory = self.memory.clone();

    // Create a stream that handles both embedding and processing
    let stream = Box::pin(async_stream::stream! {
      let mut embed_stream = embed_file_stream;
      while let Some(item) = embed_stream.next().await {
        if let Ok(ref data) = item {
          if data.value == json!({}) {
            // This is the dummy value, don't yield it
            continue;
          }
        }
        yield item;
      }

      // Now wait for the embed results
      let embed_results = embed_results_recv.await.unwrap_or_else(|_| {
          // If we couldn't get results, continue with empty documents
          vec![]
        });

      let (documents, content) = process_embed_results_to_content(&embed_results, &input);
      let new_question = if rephrase_question {
        get_attachments_rephrase_question(&ollama, history, &content, &condense_question_chain)
          .await
          .map(|v| v.0)
          .unwrap_or(content.clone())
      } else {
        content.clone()
      };

      debug!(
        "[Chat] main stream context: document: {:?}, question: {}",
        documents, new_question,
      );

      let sources = deduplicate_metadata(&documents);
      let human_message = Message::new_human_message(&content);
      yield Ok(StreamData::new(
          json!(QuestionStreamValue::Progress {
            value: "Generating response...".to_string()
          }),
          None,
          String::new(),
        ));

      let mut question_args = StuffQAPromptBuilder::new()
            .documents(&[])
            .question(new_question)
            .build();
      for (key, value) in input_variables.into_iter() {
        if question_args.contains_key(&key) {
          continue;
        }
        question_args.insert(key, value);
      }

      match combine_documents_chain
        .stream(question_args)
        .await
      {
        Ok(question_stream) => {
          // Forward the main question stream
          let mut main_stream = question_stream;
          let mut complete_ai_message = String::new();

          while let Some(result) = main_stream.next().await {
            match &result {
              Ok(data) => {
                complete_ai_message.push_str(&data.content);
                yield Ok(StreamData::new(
                  json!(QuestionStreamValue::Answer {
                    value: data.content.clone()
                  }),
                  data.tokens.clone(),
                  data.content.clone(),
                ));
              }
              Err(_) => {
                yield result;
              }
            }
          }

          // Emit source metadata
          for source in sources {
            yield Ok(StreamData::new(json!(source), None, String::new()));
          }

          // Update memory
          let mut memory_guard = memory.lock().await;
          debug!("[Chat] Complete QA: question:{}", human_message.content);
          memory_guard.add_message(human_message).await;

          if !complete_ai_message.is_empty() {
            debug!("[Chat] Complete QA: answer:{}", complete_ai_message);
            memory_guard
              .add_message(Message::new_ai_message(&complete_ai_message))
              .await;
          }
        }
        Err(e) => {
          yield Err(e);
        }
      }

      // Explicitly terminate the stream
      debug!("[Chat] Stream completed, terminating");
    });

    Ok(stream)
  }

  async fn handle_no_attachments(
    &self,
    history: &[Message],
    input_variables: PromptArgs,
  ) -> Result<ResponseStream, ChainError> {
    let input_variable = &input_variables
      .get(&self.input_key)
      .ok_or(ChainError::MissingInputVariable(self.input_key.clone()))?;
    let human_message = Message::new_human_message(input_variable);
    let rephase_question = if self.rephrase_question {
      get_rephase_question(
        &self.ollama,
        history,
        &human_message.content,
        &self.condense_question_chain,
      )
      .await?
      .0
    } else {
      human_message.content.to_string()
    };

    // Handle document retrieval
    let documents = match self.get_documents_or_suggestions(&rephase_question).await? {
      Either::Left(docs) => docs,
      Either::Right(_) => {
        vec![]
      },
    };

    debug!(
      "[Chat] Retrieved documents for question: {}, count: {}, contents: {:?}",
      rephase_question,
      documents.len(),
      documents,
    );

    debug!(
      "[Chat] main stream context: document: {:?}, question: {}",
      documents, rephase_question,
    );

    let mut question_args = StuffQAPromptBuilder::new()
      .documents(&documents)
      .question(rephase_question.clone())
      .build();
    for (key, value) in input_variables.into_iter() {
      if question_args.contains_key(&key) {
        continue;
      }
      question_args.insert(key, value);
    }

    let main_stream = self.combine_documents_chain.stream(question_args).await?;
    let sources = deduplicate_metadata(&documents);
    let output_stream = create_output_stream(
      self.memory.clone(),
      main_stream,
      sources,
      None,
      human_message,
    );
    Ok(Box::pin(output_stream))
  }

  /// Extract files from input variables
  fn extract_attachments_from_input(&self, input_variables: &PromptArgs) -> Vec<EmbedFile> {
    input_variables
      .get("files")
      .map(|v| {
        v.as_array()
          .unwrap_or(&vec![])
          .iter()
          .flat_map(|f| serde_json::from_value::<EmbedFile>(f.clone()))
          .collect::<Vec<EmbedFile>>()
      })
      .unwrap_or_default()
  }

  /// Create a stream that emits embedding progress for each file
  fn create_embed_files_stream(
    &self,
    files: Vec<EmbedFile>,
    result_sender: Option<oneshot::Sender<Vec<EmbedFileResult>>>,
  ) -> ResponseStream {
    let embedder = self.embedder.clone();
    let results = Arc::new(Mutex::new(Vec::new()));
    let results_for_send = results.clone();

    let stream = futures::stream::iter(files)
      .flat_map(move |file| {
        let embedder = embedder.clone();
        let file_path = PathBuf::from(file.path);
        let results = results.clone();

        let stream: ResponseStream = if file_path.exists() {
          let embedder_clone = embedder.clone();
          let file_path_clone = file_path.clone();
          let results_clone = results.clone();

          // Create the embed stream that yields immediately
          Box::pin(async_stream::stream! {
            match embedder_clone.embed_file(&file_path_clone).await {
              Ok(mut progress_stream) => {
                let mut final_content = String::new();
                let mut has_error = false;

                // Yield progress events as they come
                while let Some(progress_result) = progress_stream.next().await {
                  match progress_result {
                    Ok(progress) => {
                      match &progress {
                        EmbedFileProgress::StartProcessing { file_name } => {
                          yield Ok::<_, ChainError>(StreamData::new(
                            json!(QuestionStreamValue::Progress {
                              value: format!("Processing file: {}", file_name)
                            }),
                            None,
                            String::new(),
                          ));
                        }
                        EmbedFileProgress::ReadingFile { progress: _, current_page, total_pages } => {
                           if let (Some(current), Some(total)) = (current_page, total_pages) {
                             let message = if current == &0 {
                               format!("Reading files with {} pages...", total)
                             } else if current == total {
                               format!("Completed reading {} pages", total)
                             } else {
                               format!("Reading page {}/{}", current, total)
                             };

                             yield Ok(StreamData::new(
                                json!(QuestionStreamValue::Progress {
                                  value: message
                                }),
                                None,
                                String::new(),
                             ));
                           };


                        }
                        EmbedFileProgress::ReadingFileDetails { details } => {
                          yield Ok(StreamData::new(
                            json!(QuestionStreamValue::Progress {
                              value: details.clone()
                            }),
                            None,
                            String::new(),
                          ));
                        }
                        EmbedFileProgress::Completed { content } => {
                          final_content = content.clone();
                          yield Ok(StreamData::new(
                            json!(QuestionStreamValue::Progress {
                              value: "File processed successfully".to_string()
                            }),
                            None,
                            String::new(),
                          ));
                        }
                        EmbedFileProgress::Error { message } => {
                          has_error = true;
                          yield Ok(StreamData::new(
                            json!(QuestionStreamValue::Progress {
                              value: format!("Error: {}", message)
                            }),
                            None,
                            String::new(),
                          ));
                        }
                      }
                    }
                    Err(e) => {
                      has_error = true;
                      error!("[Chat] Embedding error: {}", e);
                      yield Ok(StreamData::new(
                        json!(QuestionStreamValue::Progress {
                          value: format!("Error: {}", e)
                        }),
                        None,
                        String::new(),
                      ));
                    }
                  }
                }

                // Store the result after all progress events
                if !has_error && !final_content.is_empty() {
                  let result = EmbedFileResult {
                    file_path: file_path_clone,
                    result: SuccessOrError::Success { file_content: final_content },
                  };
                  results_clone.lock().await.push(result);
                } else if has_error {
                  let result = EmbedFileResult {
                    file_path: file_path_clone,
                    result: SuccessOrError::Error("Embedding failed".to_string()),
                  };
                  results_clone.lock().await.push(result);
                }
              }
              Err(err) => {
                let result = EmbedFileResult {
                  file_path: file_path_clone,
                  result: SuccessOrError::Error(err.msg.clone()),
                };
                results_clone.lock().await.push(result);

                yield Ok::<_, ChainError>(StreamData::new(
                  json!(QuestionStreamValue::Progress {
                    value: format!("Error: {}", err.msg)
                  }),
                  None,
                  String::new(),
                ));
              }
            }
          })
        } else {
          let result = EmbedFileResult {
            file_path: file_path.clone(),
            result: SuccessOrError::Error(format!("File not found: {}", file_path.display())),
          };

          Box::pin(futures::stream::once(async move {
            results.lock().await.push(result);
            Ok::<_, ChainError>(StreamData::new(
              json!(QuestionStreamValue::Progress {
                value: "File not found".to_string()
              }),
              None,
              String::new(),
            ))
          }))
        };

        stream
      })
      .boxed();

    let final_stream = stream
      .chain(futures::stream::once(async move {
        if let Some(sender) = result_sender {
          let results = results_for_send.lock().await.clone();
          let _ = sender.send(results);
        }
        Ok::<_, ChainError>(dummy_stream_value())
      }))
      .filter_map(|result| async move {
        match result {
          Ok(data) if data.value == json!({}) => None,
          other => Some(other),
        }
      })
      .boxed();

    final_stream
  }

  /// Create stream for context suggested answers
  #[allow(dead_code)]
  fn create_context_suggested_stream(
    &self,
    value: String,
    suggested_questions: Vec<ContextSuggestedQuestion>,
    embed_file_stream: Option<EmbedFileStream>,
  ) -> ResponseStream {
    let initial_msg = futures::stream::once(async move {
      Ok(StreamData::new(
        json!(QuestionStreamValue::Answer {
          value: value.clone()
        }),
        None,
        value,
      ))
    });

    let question_stream: ResponseStream = if !suggested_questions.is_empty() {
      let newline_msg = futures::stream::once(async move {
        Ok(StreamData::new(
          json!(QuestionStreamValue::Answer {
            value: "\n\n".to_string()
          }),
          None,
          "\n\n".to_string(),
        ))
      });

      let suggested_questions_for_msg = suggested_questions.clone();
      let suggested_msg = futures::stream::once(async move {
        Ok(StreamData::new(
          json!(QuestionStreamValue::SuggestedQuestion {
            context_suggested_questions: suggested_questions_for_msg
          }),
          None,
          String::new(),
        ))
      });

      let formatted_questions = futures::stream::iter(suggested_questions.into_iter().enumerate())
        .then(|(i, question)| async move {
          tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
          let formatted_question = format!("{}. {}\n", i + 1, question.content);
          let result = Ok::<_, ChainError>(StreamData::new(
            json!(QuestionStreamValue::Answer {
              value: formatted_question.clone()
            }),
            None,
            formatted_question,
          ));
          tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
          result
        });

      let followup_msg = futures::stream::once(async move {
        Ok(StreamData::new(
          json!(QuestionStreamValue::FollowUp {
            should_generate_related_question: false
          }),
          None,
          String::new(),
        ))
      });

      Box::pin(
        newline_msg
          .chain(suggested_msg)
          .chain(formatted_questions)
          .chain(followup_msg),
      )
    } else {
      Box::pin(futures::stream::empty())
    };

    let start_stream = embed_file_stream.unwrap_or_else(|| futures::stream::empty().boxed());
    start_stream
      .chain(initial_msg)
      .chain(question_stream)
      .boxed()
  }

  pub async fn get_related_questions(&self, question: &str) -> Result<Vec<String>, FlowyError> {
    let context = self.latest_context.load();
    let rag_ids = self.retriever.get_rag_ids().await;

    if context.is_empty() {
      let chain = RelatedQuestionChain::new(self.ollama.clone());
      chain.generate_related_question(question).await
    } else if let Some(c) = self.context_question_chain.as_ref() {
      c.generate_questions_from_context(&rag_ids, &context)
        .await
        .map(|questions| questions.into_iter().map(|q| q.content).collect())
    } else {
      Ok(vec![])
    }
  }

  pub async fn get_chat_history(&self, revert_token: usize) -> Result<Vec<String>, FlowyError> {
    let history = {
      let memory = self.memory.lock().await;
      memory.messages().await
    };
    let trim_history = trim_history_message(&self.ollama, history, revert_token).await;
    Ok(
      trim_history
        .into_iter()
        .map(|message| format!("{}:{}", message.message_type.to_string(), message.content))
        .collect(),
    )
  }

  async fn get_documents_or_suggestions(
    &self,
    question: &str,
  ) -> Result<Either<Vec<Document>, StreamValue>, ChainError> {
    let rag_ids = self.retriever.get_rag_ids().await;
    trace!(
      "Get document for question: {}, RAG IDs: {:?}",
      question, rag_ids
    );

    if rag_ids.is_empty() {
      Ok(Either::Left(vec![]))
    } else {
      let documents = self
        .retriever
        .retrieve_documents(question)
        .await
        .map_err(|e| ChainError::RetrieverError(e.to_string()))?;

      if documents.is_empty() {
        trace!(
          "[Embedding] No relevant documents for given RAG IDs:{:?}. try generating suggested questions",
          rag_ids
        );

        let mut suggested_questions = vec![];
        if let Some(c) = self.context_question_chain.as_ref() {
          let rag_ids = rag_ids.iter().map(|v| v.to_string()).collect::<Vec<_>>();
          match c.generate_questions(&rag_ids).await {
            Ok((context, questions)) => {
              self.latest_context.store(Arc::new(context));
              trace!("[embedding]: context related questions: {:?}", questions);
              suggested_questions = questions
                .into_iter()
                .map(|q| ContextSuggestedQuestion {
                  content: q.content,
                  object_id: q.object_id,
                })
                .collect::<Vec<_>>();
            },
            Err(err) => {
              error!(
                "[embedding] Error generating context related questions: {}",
                err
              );
            },
          }
        }

        if suggested_questions.is_empty() {
          Ok(Either::Right(StreamValue::ContextSuggested {
            value: CAN_NOT_ANSWER_WITH_CONTEXT.to_string(),
            suggested_questions,
          }))
        } else {
          Ok(Either::Right(StreamValue::ContextSuggested {
            value: ANSWER_WITH_SUGGESTED_QUESTION.to_string(),
            suggested_questions,
          }))
        }
      } else {
        let embedded_docs = documents
          .iter()
          .flat_map(|d| {
            let object_id = d
              .metadata
              .get(SOURCE_ID)
              .and_then(|v| v.as_str().map(|v| v.to_string()))?;
            Some(EmbeddedContent {
              content: d.page_content.clone(),
              object_id,
            })
          })
          .collect::<Vec<_>>();

        let context = embedded_documents_to_context_str(embedded_docs);
        self.latest_context.store(Arc::new(context));

        Ok(Either::Left(documents))
      }
    }
  }
}

#[async_trait]
impl Chain for ConversationalRetrieverChain {
  async fn call(&self, input_variables: PromptArgs) -> Result<GenerateResult, ChainError> {
    let output = self.execute(input_variables).await?;
    let result: GenerateResult = serde_json::from_value(output[DEFAULT_RESULT_KEY].clone())?;
    Ok(result)
  }

  async fn execute(
    &self,
    _input_variables: PromptArgs,
  ) -> Result<HashMap<String, Value>, ChainError> {
    Err(ChainError::OtherError(
      "Only stream is supported".to_string(),
    ))
  }

  async fn stream(&self, input_variables: PromptArgs) -> Result<ResponseStream, ChainError> {
    let attachments = self.extract_attachments_from_input(&input_variables);
    let history = {
      let memory = self.memory.lock().await;
      memory.messages().await
    };

    if attachments.is_empty() {
      self.handle_no_attachments(&history, input_variables).await
    } else {
      self
        .handle_attachments(history, input_variables, attachments)
        .await
    }
  }

  fn get_input_keys(&self) -> Vec<String> {
    vec![self.input_key.clone()]
  }

  fn get_output_keys(&self) -> Vec<String> {
    let mut keys = Vec::new();
    if self.return_source_documents {
      keys.push(CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_SOURCE_DOCUMENT_KEY.to_string());
    }

    if self.rephrase_question {
      keys.push(CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_GENERATED_QUESTION_KEY.to_string());
    }

    keys.push(self.output_key.clone());
    keys.push(DEFAULT_RESULT_KEY.to_string());

    keys
  }
}

pub struct ConversationalRetrieverChainBuilder {
  workspace_id: Uuid,
  llm: LLMOllama,
  retriever: Box<dyn AFRetriever>,
  embedder: Arc<dyn AFEmbedder>,
  memory: Option<Arc<Mutex<dyn BaseMemory>>>,
  prompt: Option<Box<dyn FormatPrompter>>,
  rephrase_question: bool,
  return_source_documents: bool,
  input_key: String,
  output_key: String,
  store: Option<SqliteVectorStore>,
}
impl ConversationalRetrieverChainBuilder {
  pub fn new(
    workspace_id: Uuid,
    llm: LLMOllama,
    retriever: Box<dyn AFRetriever>,
    embedder: Arc<dyn AFEmbedder>,
    store: Option<SqliteVectorStore>,
  ) -> Self {
    ConversationalRetrieverChainBuilder {
      workspace_id,
      llm,
      retriever,
      embedder,
      memory: None,
      prompt: None,
      rephrase_question: true,
      return_source_documents: true,
      input_key: CONVERSATIONAL_RETRIEVAL_QA_DEFAULT_INPUT_KEY.to_string(),
      output_key: DEFAULT_OUTPUT_KEY.to_string(),
      store,
    }
  }

  ///If you want to add a custom prompt,keep in mind which variables are obligatory.
  pub fn prompt<P: Into<Box<dyn FormatPrompter>>>(mut self, prompt: P) -> Self {
    self.prompt = Some(prompt.into());
    self
  }

  pub fn memory(mut self, memory: Arc<Mutex<dyn BaseMemory>>) -> Self {
    self.memory = Some(memory);
    self
  }

  pub fn rephrase_question(mut self, rephrase_question: bool) -> Self {
    self.rephrase_question = rephrase_question;
    self
  }

  #[allow(dead_code)]
  pub fn return_source_documents(mut self, return_source_documents: bool) -> Self {
    self.return_source_documents = return_source_documents;
    self
  }

  pub fn build(self) -> FlowyResult<ConversationalRetrieverChain> {
    let combine_documents_chain = {
      let mut builder = StuffDocumentBuilder::new().llm(self.llm.clone());
      if let Some(prompt) = self.prompt {
        builder = builder.prompt(prompt);
      }
      builder
        .build()
        .map_err(|err| FlowyError::local_ai().with_context(err))?
    };

    let condense_question_chain = CondenseQuestionGeneratorChain::new(self.llm.clone());
    let memory = self
      .memory
      .unwrap_or_else(|| Arc::new(Mutex::new(SimpleMemory::new())));

    let context_question_chain = self
      .store
      .map(|store| ContextRelatedQuestionChain::new(self.workspace_id, self.llm.clone(), store));

    Ok(ConversationalRetrieverChain {
      ollama: self.llm,
      retriever: self.retriever,
      embedder: self.embedder,
      memory,
      combine_documents_chain: Arc::new(combine_documents_chain),
      condense_question_chain: Arc::new(condense_question_chain),
      context_question_chain,
      rephrase_question: self.rephrase_question,
      return_source_documents: self.return_source_documents,
      input_key: self.input_key,
      output_key: self.output_key,
      latest_context: Default::default(),
    })
  }
}

/// Updates memory with human and AI messages after stream completion
async fn update_memory_after_stream(
  memory: Arc<Mutex<dyn BaseMemory>>,
  human_message: Message,
  complete_ai_message: Arc<Mutex<String>>,
) -> Result<StreamData, ChainError> {
  let mut memory = memory.lock().await;
  debug!("[Chat] Complete QA: question:{}", human_message.content);
  memory.add_message(human_message).await;
  let complete_message = complete_ai_message.lock().await;

  debug!("[Chat] Complete QA: answer:{}", complete_message);
  if !complete_message.is_empty() {
    memory
      .add_message(Message::new_ai_message(&complete_message))
      .await;
  }
  Ok::<_, ChainError>(dummy_stream_value())
}

fn create_output_stream(
  memory: Arc<Mutex<dyn BaseMemory>>,
  main_stream: ResponseStream,
  sources: Vec<QuestionStreamValue>,
  embed_file_stream: Option<EmbedFileStream>,
  human_message: Message,
) -> ResponseStream {
  use futures::stream::StreamExt;

  let complete_ai_message = Arc::new(Mutex::new(String::new()));
  let complete_ai_message_clone = complete_ai_message.clone();

  // Process the main stream to collect AI messages
  let processed_main_stream = main_stream.then(move |result| {
    let complete_ai_message_clone = complete_ai_message_clone.clone();
    async move {
      match result {
        Ok(data) => {
          let mut ai_message = complete_ai_message_clone.lock().await;
          ai_message.push_str(&data.content);
          Ok(StreamData::new(
            json!(QuestionStreamValue::Answer {
              value: data.content.clone()
            }),
            data.tokens,
            data.content,
          ))
        },
        Err(e) => Err(e),
      }
    }
  });

  // Create source metadata stream
  let source_stream = futures::stream::iter(sources)
    .map(|source| Ok(StreamData::new(json!(source), None, String::new())));

  // Memory update stream
  let memory_update_stream = futures::stream::once({
    let memory = memory.clone();
    let human_message = human_message.clone();
    let complete_ai_message = complete_ai_message.clone();
    async move { update_memory_after_stream(memory, human_message, complete_ai_message).await }
  });

  // Chain all streams together
  // Start with embed_file_stream if present, otherwise use an empty stream
  let start_stream = embed_file_stream.unwrap_or_else(|| futures::stream::empty().boxed());

  start_stream
    .chain(processed_main_stream)
    .chain(source_stream)
    .chain(memory_update_stream)
    .filter_map(|result| async move {
      match result {
        Ok(data) if data.value == json!({}) => None,
        other => Some(other),
      }
    })
    .boxed()
}

fn dummy_stream_value() -> StreamData {
  StreamData::new(json!({}), None, String::new())
}

/// Deduplicates metadata from a list of documents by merging metadata entries with the same keys
fn deduplicate_metadata(documents: &[Document]) -> Vec<QuestionStreamValue> {
  let mut merged_metadata: HashMap<String, QuestionStreamValue> = HashMap::new();
  for document in documents {
    if let Some(object_id) = document.metadata.get(SOURCE_ID).and_then(|s| s.as_str()) {
      merged_metadata.insert(
        object_id.to_string(),
        QuestionStreamValue::Metadata {
          value: json!(document.metadata.clone()),
        },
      );
    }
  }
  merged_metadata.into_values().collect()
}

async fn get_attachments_rephrase_question(
  ollama: &LLMOllama,
  history: Vec<Message>,
  content: &str,
  condense_question_chain: &Arc<dyn Chain>,
) -> Result<(String, Option<TokenUsage>), ChainError> {
  let extract_reverse_token = ollama.estimate_token_count(content);
  let trim_history = trim_history_message(ollama, history.clone(), extract_reverse_token).await;
  let result = condense_question_chain
    .call(
      CondenseQuestionPromptBuilder::new()
        .question(content)
        .chat_history(&trim_history)
        .build(),
    )
    .await?;

  debug!(
    "[Chat] Rephrased question: {}, original:{}",
    result.generation, content
  );
  Ok((result.generation, None))
}

async fn get_rephase_question(
  ollama: &LLMOllama,
  history: &[Message],
  input: &str,
  condense_question_chain: &Arc<dyn Chain>,
) -> Result<(String, Option<TokenUsage>), ChainError> {
  if history.is_empty() {
    return Ok((input.to_string(), None));
  }

  let trim_history = trim_history_message(ollama, history.to_vec(), 0).await;
  let mut token_usage: Option<TokenUsage> = None;
  let result = condense_question_chain
    .call(
      CondenseQuestionPromptBuilder::new()
        .question(input)
        .chat_history(&trim_history)
        .build(),
    )
    .await?;
  if let Some(tokens) = result.tokens {
    token_usage = Some(tokens);
  };
  debug!(
    "[Chat] Rephrased question: {}, original:{}, history: {:?}",
    result.generation, input, history
  );
  Ok((result.generation, token_usage))
}

async fn trim_history_message(
  ollama: &LLMOllama,
  mut history: Vec<Message>,
  extract_revert: usize,
) -> Vec<Message> {
  // Calculate how many messages can fit in the context window
  // Reserve tokens for: system prompt (~200), current question (~100),
  // response (~2000), and safety margin (~500)
  debug!(
    "[Tokens] Trimming history for context window, extract_revert: {}",
    extract_revert
  );
  const RESERVED_TOKENS: usize = 2000;
  let message_capacity = ollama
    .calculate_message_capacity(&history, RESERVED_TOKENS + extract_revert)
    .await
    .unwrap_or(5);

  // Take the most recent messages that fit in the context
  if history.len() > message_capacity {
    debug!(
      "[Tokens] Trimming history from {} to {} messages",
      history.len(),
      message_capacity
    );
    let drain_end = history.len() - message_capacity;
    history.drain(..drain_end);
  }
  history
}

fn process_embed_results_to_content(
  embed_results: &[EmbedFileResult],
  input: &str,
) -> (Vec<Document>, String) {
  let documents: Vec<Document> = embed_results
    .iter()
    .flat_map(|file| match &file.result {
      SuccessOrError::Success { file_content } => {
        let mut metadata = HashMap::new();
        let file_name = file
          .file_path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("file")
          .to_string();
        let source = RAGSource::LocalFile { file_name };

        metadata.insert(SOURCE_ID.to_string(), json!(file.file_path));
        metadata.insert(SOURCE_NAME.to_string(), json!(source.file_name()));
        metadata.insert(SOURCE.to_string(), json!(source.as_str()));
        Some(Document::new(file_content.clone()).with_metadata(metadata))
      },
      SuccessOrError::Error(_) => None,
    })
    .collect();

  let mut content = String::new();
  for document in &documents {
    let document_content = format!(
      "Uploaded file: {}\nfile content: {}\n",
      document
        .metadata
        .get(SOURCE_NAME)
        .and_then(|s| s.as_str())
        .unwrap_or("unknown"),
      document.page_content
    );
    debug!("[Chat] attachment file details: {}", &document_content);
    content.push_str(&document_content);
    content.push('\n');
  }
  content.push_str(input);

  (documents, content)
}
