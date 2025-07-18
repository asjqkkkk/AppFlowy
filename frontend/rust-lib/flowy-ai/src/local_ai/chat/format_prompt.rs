use crate::local_ai::prompt::format_prompt;
use flowy_ai_pub::cloud::ResponseFormat;
use flowy_error::{FlowyError, FlowyResult};
use langchain_rust::prompt::{
  FormatPrompter, HumanMessagePromptTemplate, MessageFormatter, PromptArgs, PromptError,
  SystemMessagePromptTemplate,
};
use langchain_rust::schemas::{Message, PromptValue};
use langchain_rust::{prompt_args, template_jinja2};
use std::sync::{Arc, RwLock};
use tracing::debug;

const QA_CONTEXT_TEMPLATE: &str = r#"
Only Use the context provided below to formulate your answer. Do not use any other information.
Do not reference external knowledge or information outside the context.

##Context##
{{context}}

Question:{{question}}
Answer:
"#;

const QA_TEMPLATE: &str = r#"
Question:{{question}}
Answer:
"#;

fn template_from_rag_ids(rag_ids: &[String]) -> HumanMessagePromptTemplate {
  if rag_ids.is_empty() {
    HumanMessagePromptTemplate::new(template_jinja2!(QA_TEMPLATE, "question"))
  } else {
    HumanMessagePromptTemplate::new(template_jinja2!(QA_CONTEXT_TEMPLATE, "context", "question"))
  }
}

const QA_HISTORY_TEMPLATE: &str = r#"
The following is a conversation between the User and you. Refer to the conversation history below when answering the User's question.
Current conversation:
{{chat_history}}
"#;

fn history_template() -> SystemMessagePromptTemplate {
  SystemMessagePromptTemplate::new(template_jinja2!(QA_HISTORY_TEMPLATE, "chat_history"))
}

struct FormatState {
  format_msg: Arc<Message>,
  format: ResponseFormat,
}

pub struct AFContextPrompt {
  rag_ids: Vec<String>,
  system_msg: Arc<Message>,
  state: Arc<RwLock<FormatState>>,
  context_template: Arc<RwLock<HumanMessagePromptTemplate>>,
  history_template: Arc<SystemMessagePromptTemplate>,
}

impl AFContextPrompt {
  pub fn new(system_msg: Message, fmt: &ResponseFormat, rag_ids: &[String]) -> Self {
    let context_template = template_from_rag_ids(rag_ids);
    let history_template = history_template();
    let state = FormatState {
      format_msg: Arc::new(format_prompt(fmt)),
      format: fmt.clone(),
    };

    Self {
      rag_ids: rag_ids.to_vec(),
      system_msg: Arc::new(system_msg),
      state: Arc::new(RwLock::new(state)),
      context_template: Arc::new(RwLock::new(context_template)),
      history_template: Arc::new(history_template),
    }
  }

  pub fn set_rag_ids(&mut self, rag_ids: &[String]) {
    if self.rag_ids == rag_ids {
      return;
    }
    self.rag_ids = rag_ids.to_vec();
    let template = template_from_rag_ids(rag_ids);
    if let Ok(mut w) = self.context_template.try_write() {
      *w = template;
    }
  }

  /// Returns true if we actually swapped in a new instruction
  pub fn set_format(&self, new_fmt: &ResponseFormat) -> FlowyResult<()> {
    let mut st = self
      .state
      .write()
      .map_err(|err| FlowyError::internal().with_context(err))?;

    if st.format.output_layout != new_fmt.output_layout {
      st.format = new_fmt.clone();
      st.format_msg = Arc::new(format_prompt(new_fmt));
    }

    Ok(())
  }
}

impl Clone for AFContextPrompt {
  fn clone(&self) -> Self {
    Self {
      rag_ids: self.rag_ids.clone(),
      system_msg: Arc::clone(&self.system_msg),
      state: Arc::clone(&self.state),
      context_template: Arc::clone(&self.context_template),
      history_template: Arc::clone(&self.history_template),
    }
  }
}

impl MessageFormatter for AFContextPrompt {
  fn format_messages(&self, mut args: PromptArgs) -> Result<Vec<Message>, PromptError> {
    let chat_history = args.remove("chat_history");

    let mut out = Vec::with_capacity(4);
    out.push((*self.system_msg).clone());

    if let Ok(st) = self.state.try_read() {
      out.push((*st.format_msg).clone());
    }

    if let Some(serde_json::Value::Array(chat_history)) = chat_history {
      if !chat_history.is_empty() {
        let args = prompt_args! {
            "chat_history" => chat_history,
        };
        out.extend(self.history_template.format_messages(args)?);
      }
    }

    if let Ok(context_template) = self.context_template.try_read() {
      out.extend(context_template.format_messages(args)?);
    }

    debug!("👀👀👀 Formatted messages: {:#?}", out);
    Ok(out)
  }

  fn input_variables(&self) -> Vec<String> {
    vec!["context".into(), "question".into(), "chat_history".into()]
  }
}

impl FormatPrompter for AFContextPrompt {
  fn format_prompt(&self, input_variables: PromptArgs) -> Result<PromptValue, PromptError> {
    let messages = self.format_messages(input_variables)?;
    Ok(PromptValue::from_messages(messages))
  }

  fn get_input_variables(&self) -> Vec<String> {
    self.input_variables()
  }
}
