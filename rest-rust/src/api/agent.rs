use axum::{extract::State, Json};
use serde::Serialize;
use serde_json::{json, Value};
use std::sync::Arc;

use crate::{
    models::AgentPromptRequest,
    services::{agent_service::AVAILABLE_MODELS, chat_service::create_new_chat, run_cursor_agent},
    AppState, Result,
};

/// Get available AI models
pub async fn get_models() -> Json<Value> {
    Json(json!({
        "models": AVAILABLE_MODELS,
        "default": "auto",
        "recommended": ["gpt-5", "sonnet-4.5", "opus-4.1"]
    }))
}

#[derive(Debug, Serialize)]
pub struct CreateChatResponse {
    pub status: String,
    pub chat_id: String,
    pub message: String,
}

/// Create a new chat for conversation
pub async fn create_chat() -> Result<Json<CreateChatResponse>> {
    let chat_id = create_new_chat().await?;

    Ok(Json(CreateChatResponse {
        status: "success".to_string(),
        chat_id,
        message: "Chat created successfully".to_string(),
    }))
}

#[derive(Debug, Serialize)]
pub struct AgentPromptResponse {
    pub status: String,
    pub chat_id: String,
    pub prompt: String,
    pub model: String,
    pub output_format: String,
    pub response: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thinking: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_calls: Option<Vec<Value>>,
    pub metadata: serde_json::Map<String, Value>,
}

/// Send a prompt to cursor-agent with automatic chat history
pub async fn send_agent_prompt(
    State(state): State<Arc<AppState>>,
    axum::extract::Path(chat_id): axum::extract::Path<String>,
    Json(request): Json<AgentPromptRequest>,
) -> Result<Json<AgentPromptResponse>> {
    let settings = &state.settings;

    // Check if cursor-agent exists
    if !settings.cursor_agent_path.exists() {
        return Err(crate::AppError::CursorAgent(format!(
            "cursor-agent not found at {}",
            settings.cursor_agent_path.display()
        )));
    }

    // Execute cursor-agent
    let response = run_cursor_agent(
        settings,
        &chat_id,
        &request.prompt,
        Some(&request.model),
        &request.output_format,
        settings.cursor_agent_timeout,
    )
    .await?;

    if !response.success {
        return Err(crate::AppError::CursorAgent(format!(
            "cursor-agent failed: {}",
            response.stderr
        )));
    }

    // Extract parsed content or use raw stdout
    let (text, thinking, tool_calls) = if let Some(parsed) = response.parsed_content {
        let text = parsed
            .get("text")
            .and_then(|v| v.as_str())
            .unwrap_or(&response.stdout)
            .to_string();
        let thinking = parsed
            .get("thinking")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        let tool_calls = parsed.get("tool_calls").and_then(|v| v.as_array()).cloned();
        (text, thinking, tool_calls)
    } else {
        (response.stdout.clone(), None, None)
    };

    // Build metadata
    let mut metadata = serde_json::Map::new();
    metadata.insert("command".to_string(), json!(response.command));
    metadata.insert("returncode".to_string(), json!(response.returncode));
    if let Some(err) = response.parse_error {
        metadata.insert("parse_error".to_string(), json!(err));
    }

    Ok(Json(AgentPromptResponse {
        status: "success".to_string(),
        chat_id,
        prompt: request.prompt,
        model: request.model,
        output_format: request.output_format,
        response: text,
        thinking,
        tool_calls,
        metadata,
    }))
}
