use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct AgentPromptRequest {
    #[validate(length(min = 1))]
    pub prompt: String,

    #[serde(default = "default_include_history")]
    pub include_history: bool,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_history_messages: Option<i32>,

    #[serde(default = "default_model")]
    pub model: String,

    #[serde(default = "default_output_format")]
    pub output_format: String,
}

fn default_include_history() -> bool {
    true
}

fn default_model() -> String {
    "sonnet-4.5-thinking".to_string()
}

fn default_output_format() -> String {
    "text".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateChatRequest {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}
