use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;

use crate::{
    db::get_cursor_db_connection,
    utils::{extract_separated_content, parse_timestamp},
    AppState, Result,
};

#[derive(Debug, Deserialize)]
pub struct ListChatsQuery {
    #[serde(default)]
    pub include_archived: bool,
    #[serde(default = "default_sort_by")]
    pub sort_by: String,
    pub limit: Option<usize>,
    #[serde(default)]
    pub offset: usize,
}

fn default_sort_by() -> String {
    "last_updated".to_string()
}

#[derive(Debug, Deserialize)]
pub struct GetMessagesQuery {
    #[serde(default = "default_true")]
    pub include_metadata: bool,
    pub limit: Option<usize>,
    #[serde(default = "default_true")]
    pub include_content: bool,
}

fn default_true() -> bool {
    true
}

/// List all chats with metadata
pub async fn list_chats(
    State(state): State<Arc<AppState>>,
    Query(params): Query<ListChatsQuery>,
) -> Result<Json<Value>> {
    let settings = state.settings.clone();
    
    let chats = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;
        let mut chats = Vec::new();
        
        // Get all chats from database
        let mut stmt = conn.prepare(
            "SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
        )?;
        
        let rows = stmt.query_map([], |row| {
            let key: String = row.get(0)?;
            let value_str: String = row.get(1)?;
            Ok((key, value_str))
        })?;
        
        for row_result in rows {
            let (_key, value_str) = row_result?;
            
            if let Ok(data) = serde_json::from_str::<HashMap<String, Value>>(&value_str) {
                // Skip archived if not requested
                let is_archived = data.get("isArchived")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                
                if !params.include_archived && is_archived {
                    continue;
                }
                
                let chat_id = data.get("composerId")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                
                let created_at = data.get("createdAt").and_then(|v| v.as_i64());
                let last_updated_at = data.get("lastUpdatedAt").and_then(|v| v.as_i64());
                
                let chat_meta = json!({
                    "chat_id": chat_id,
                    "name": data.get("name").and_then(|v| v.as_str()).unwrap_or("Untitled"),
                    "created_at": created_at,
                    "created_at_iso": created_at.map(parse_timestamp),
                    "last_updated_at": last_updated_at,
                    "last_updated_at_iso": last_updated_at.map(parse_timestamp),
                    "is_archived": is_archived,
                    "is_draft": data.get("isDraft").and_then(|v| v.as_bool()).unwrap_or(false),
                    "total_lines_added": data.get("totalLinesAdded").and_then(|v| v.as_i64()).unwrap_or(0),
                    "total_lines_removed": data.get("totalLinesRemoved").and_then(|v| v.as_i64()).unwrap_or(0),
                    "subtitle": data.get("subtitle").and_then(|v| v.as_str()),
                    "message_count": data.get("fullConversationHeadersOnly")
                        .and_then(|v| v.as_array())
                        .map(|a| a.len())
                        .unwrap_or(0),
                    "location": "local"
                });
                
                chats.push(chat_meta);
            }
        }
        
        Ok::<_, crate::AppError>(chats)
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;
    
    // Sort chats
    let mut chats = chats;
    match params.sort_by.as_str() {
        "last_updated" => {
            chats.sort_by(|a, b| {
                let a_time = a.get("last_updated_at").and_then(|v| v.as_i64()).unwrap_or(0);
                let b_time = b.get("last_updated_at").and_then(|v| v.as_i64()).unwrap_or(0);
                b_time.cmp(&a_time)
            });
        }
        "created" => {
            chats.sort_by(|a, b| {
                let a_time = a.get("created_at").and_then(|v| v.as_i64()).unwrap_or(0);
                let b_time = b.get("created_at").and_then(|v| v.as_i64()).unwrap_or(0);
                b_time.cmp(&a_time)
            });
        }
        "name" => {
            chats.sort_by(|a, b| {
                let a_name = a.get("name").and_then(|v| v.as_str()).unwrap_or("").to_lowercase();
                let b_name = b.get("name").and_then(|v| v.as_str()).unwrap_or("").to_lowercase();
                a_name.cmp(&b_name)
            });
        }
        _ => {}
    }
    
    // Apply pagination
    let total_count = chats.len();
    let chats: Vec<Value> = chats
        .into_iter()
        .skip(params.offset)
        .take(params.limit.unwrap_or(usize::MAX))
        .collect();
    
    Ok(Json(json!({
        "total": total_count,
        "returned": chats.len(),
        "offset": params.offset,
        "chats": chats
    })))
}

/// Get metadata for a specific chat
pub async fn get_chat_metadata(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
) -> Result<Json<Value>> {
    let settings = state.settings.clone();
    
    let metadata = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;
        let key = format!("composerData:{}", chat_id);
        
        let value_str: String = conn
            .query_row(
                "SELECT value FROM cursorDiskKV WHERE key = ?",
                [&key],
                |row| row.get(0),
            )
            .map_err(|e| match e {
                rusqlite::Error::QueryReturnedNoRows => {
                    crate::AppError::NotFound(format!("Chat {} not found", chat_id))
                }
                _ => crate::AppError::Database(e),
            })?;
        
        let data: HashMap<String, Value> = serde_json::from_str(&value_str)?;
        
        let created_at = data.get("createdAt").and_then(|v| v.as_i64());
        let last_updated_at = data.get("lastUpdatedAt").and_then(|v| v.as_i64());
        
        Ok::<_, crate::AppError>(json!({
            "chat_id": data.get("composerId").and_then(|v| v.as_str()).unwrap_or(&chat_id),
            "name": data.get("name").and_then(|v| v.as_str()).unwrap_or("Untitled"),
            "created_at": created_at,
            "created_at_iso": created_at.map(parse_timestamp),
            "last_updated_at": last_updated_at,
            "last_updated_at_iso": last_updated_at.map(parse_timestamp),
            "is_archived": data.get("isArchived").and_then(|v| v.as_bool()).unwrap_or(false),
            "is_draft": data.get("isDraft").and_then(|v| v.as_bool()).unwrap_or(false),
            "total_lines_added": data.get("totalLinesAdded").and_then(|v| v.as_i64()).unwrap_or(0),
            "total_lines_removed": data.get("totalLinesRemoved").and_then(|v| v.as_i64()).unwrap_or(0),
            "subtitle": data.get("subtitle").and_then(|v| v.as_str()),
            "message_count": data.get("fullConversationHeadersOnly")
                .and_then(|v| v.as_array())
                .map(|a| a.len())
                .unwrap_or(0)
        }))
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;
    
    Ok(Json(metadata))
}

/// Get all messages for a specific chat
pub async fn get_chat_messages(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
    Query(params): Query<GetMessagesQuery>,
) -> Result<Json<Value>> {
    let settings = state.settings.clone();
    
    let result = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;
        
        // Get all messages
        let pattern = format!("bubbleId:{}:%", chat_id);
        let mut stmt = conn.prepare(
            "SELECT key, value FROM cursorDiskKV WHERE key LIKE ? ORDER BY key"
        )?;
        
        let rows = stmt.query_map([pattern], |row| {
            let key: String = row.get(0)?;
            let value_str: String = row.get(1)?;
            Ok((key, value_str))
        })?;
        
        let mut messages = Vec::new();
        for row_result in rows {
            let (key, value_str) = row_result?;
            
            if let Ok(bubble) = serde_json::from_str::<HashMap<String, Value>>(&value_str) {
                let bubble_id = key.split(':').last().unwrap_or("").to_string();
                
                let (text, tool_calls, thinking_content, code_blocks, todos) = if params.include_content {
                    let separated = extract_separated_content(&bubble);
                    (
                        separated.get("text").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                        separated.get("tool_calls").cloned(),
                        separated.get("thinking").and_then(|v| v.as_str()).map(|s| s.to_string()),
                        separated.get("code_blocks").cloned(),
                        separated.get("todos").cloned(),
                    )
                } else {
                    ("[Content not included]".to_string(), None, None, None, None)
                };
                
                let bubble_type = bubble.get("type").and_then(|v| v.as_i64()).unwrap_or(0);
                
                let message = json!({
                    "bubble_id": bubble_id,
                    "type": bubble_type,
                    "type_label": if bubble_type == 1 { "user" } else { "assistant" },
                    "text": text,
                    "created_at": bubble.get("createdAt"),
                    "has_tool_call": bubble.contains_key("toolFormerData"),
                    "has_thinking": bubble.contains_key("thinking"),
                    "has_code": bubble.contains_key("codeBlocks"),
                    "has_todos": bubble.contains_key("todos"),
                    "tool_calls": tool_calls,
                    "thinking_content": thinking_content,
                    "code_blocks": code_blocks,
                    "todos": todos,
                });
                
                messages.push(message);
            }
        }
        
        // Sort by timestamp
        messages.sort_by(|a, b| {
            let a_time = a.get("created_at").and_then(|v| v.as_i64()).unwrap_or(0);
            let b_time = b.get("created_at").and_then(|v| v.as_i64()).unwrap_or(0);
            a_time.cmp(&b_time)
        });
        
        // Apply limit
        if let Some(limit) = params.limit {
            messages.truncate(limit);
        }
        
        let mut result = json!({
            "chat_id": chat_id,
            "message_count": messages.len(),
            "messages": messages
        });
        
        // Add metadata if requested
        if params.include_metadata {
            let key = format!("composerData:{}", chat_id);
            if let Ok(value_str) = conn.query_row::<String, _, _>(
                "SELECT value FROM cursorDiskKV WHERE key = ?",
                [&key],
                |row| row.get(0),
            ) {
                if let Ok(metadata) = serde_json::from_str::<HashMap<String, Value>>(&value_str) {
                    let created_at = metadata.get("createdAt").and_then(|v| v.as_i64());
                    let last_updated_at = metadata.get("lastUpdatedAt").and_then(|v| v.as_i64());
                    
                    result["metadata"] = json!({
                        "name": metadata.get("name").and_then(|v| v.as_str()).unwrap_or("Untitled"),
                        "created_at": created_at,
                        "created_at_iso": created_at.map(parse_timestamp),
                        "last_updated_at": last_updated_at,
                        "last_updated_at_iso": last_updated_at.map(parse_timestamp),
                        "is_archived": metadata.get("isArchived").and_then(|v| v.as_bool()).unwrap_or(false),
                        "is_draft": metadata.get("isDraft").and_then(|v| v.as_bool()).unwrap_or(false),
                        "total_lines_added": metadata.get("totalLinesAdded").and_then(|v| v.as_i64()).unwrap_or(0),
                        "total_lines_removed": metadata.get("totalLinesRemoved").and_then(|v| v.as_i64()).unwrap_or(0),
                        "subtitle": metadata.get("subtitle").and_then(|v| v.as_str()),
                    });
                }
            }
        }
        
        Ok::<_, crate::AppError>(result)
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;
    
    Ok(Json(result))
}

