use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMetadata {
    pub chat_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at_iso: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_updated_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_updated_at_iso: Option<String>,
    #[serde(default)]
    pub is_archived: bool,
    #[serde(default)]
    pub is_draft: bool,
    #[serde(default)]
    pub total_lines_added: i32,
    #[serde(default)]
    pub total_lines_removed: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subtitle: Option<String>,
    #[serde(default)]
    pub message_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub bubble_id: String,
    #[serde(rename = "type")]
    pub msg_type: i32,
    pub type_label: String,
    pub text: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    #[serde(default)]
    pub has_tool_call: bool,
    #[serde(default)]
    pub has_thinking: bool,
    #[serde(default)]
    pub has_code: bool,
    #[serde(default)]
    pub has_todos: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_calls: Option<Vec<HashMap<String, Value>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thinking_content: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub code_blocks: Option<Vec<HashMap<String, Value>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub todos: Option<Vec<HashMap<String, Value>>>,
    #[serde(default)]
    pub is_remote: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Bubble {
    pub bubble_id: String,
    pub bubble_data: BubbleData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BubbleData {
    #[serde(rename = "type")]
    pub bubble_type: i32,
    pub text: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thinking: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_calls: Option<Vec<HashMap<String, Value>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageCreate {
    pub text: String,
    #[serde(rename = "type", default = "default_message_type")]
    pub msg_type: i32,
}

fn default_message_type() -> i32 {
    1
}
