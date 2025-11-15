use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};
use sqlx;
use std::collections::HashMap;
use std::sync::Arc;

use crate::{
    db::{cache_sync, get_cursor_db_connection},
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

#[derive(Debug, Deserialize, Clone)]
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

/// Helper function to fetch messages from local Cursor DB
fn fetch_local_messages(
    settings: &crate::Settings,
    chat_id: &str,
    params: &GetMessagesQuery,
    is_remote_fallback: bool,
) -> crate::Result<Value> {
    // Try cursor-agent format first
    match crate::db::cursor_agent::get_chat_messages_from_agent(chat_id, params.include_content) {
        Ok(messages) if !messages.is_empty() => {
            tracing::info!(
                "Successfully loaded {} messages from cursor-agent format",
                messages.len()
            );

            // Apply limit
            let mut messages = messages;
            if let Some(limit) = params.limit {
                messages.truncate(limit);
            }

            let mut result = json!({
                "chat_id": chat_id,
                "message_count": messages.len(),
                "messages": messages,
            });

            // Add metadata if requested
            if params.include_metadata {
                if let Ok(metadata) = crate::db::cursor_agent::get_chat_metadata_from_agent(chat_id)
                {
                    let mut meta = json!({
                        "name": metadata.get("name"),
                        "created_at": metadata.get("createdAt"),
                        "agent_id": metadata.get("agentId"),
                        "mode": metadata.get("mode"),
                        "format": "cursor-agent",
                    });

                    if is_remote_fallback {
                        if let Some(meta_obj) = meta.as_object_mut() {
                            meta_obj.insert("location".to_string(), json!("local_fallback"));
                            meta_obj.insert(
                                "note".to_string(),
                                json!("Remote device unavailable, showing local cursor-agent copy"),
                            );
                        }
                    } else {
                        if let Some(meta_obj) = meta.as_object_mut() {
                            meta_obj.insert("location".to_string(), json!("local"));
                        }
                    }

                    result["metadata"] = meta;
                }
            }

            return Ok(result);
        }
        Ok(_) => {
            tracing::debug!("cursor-agent format found but empty, trying Cursor IDE format");
        }
        Err(e) => {
            tracing::debug!(
                "cursor-agent format not found ({}), trying Cursor IDE format",
                e
            );
        }
    }

    // Fall back to Cursor IDE format
    tracing::info!("Loading messages from Cursor IDE format");
    let conn = get_cursor_db_connection(settings)?;

    // Get all messages
    let pattern = format!("bubbleId:{}:%", chat_id);
    let mut stmt =
        conn.prepare("SELECT key, value FROM cursorDiskKV WHERE key LIKE ? ORDER BY key")?;

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

            let (text, tool_calls, thinking_content, code_blocks, todos) = if params.include_content
            {
                let separated = extract_separated_content(&bubble);
                (
                    separated
                        .get("text")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    separated.get("tool_calls").cloned(),
                    separated
                        .get("thinking")
                        .and_then(|v| v.as_str())
                        .map(|s| s.to_string()),
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
                "is_remote": is_remote_fallback,
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

                let mut meta = json!({
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
                    "format": "cursor-ide",
                });

                // If this is a remote fallback, mark it
                if is_remote_fallback {
                    if let Some(meta_obj) = meta.as_object_mut() {
                        meta_obj.insert("location".to_string(), json!("local_fallback"));
                        meta_obj.insert(
                            "note".to_string(),
                            json!("Remote device unavailable, showing local Cursor IDE copy"),
                        );
                    }
                }

                result["metadata"] = meta;
            }
        }
    }

    Ok(result)
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
                let a_time = a
                    .get("last_updated_at")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
                let b_time = b
                    .get("last_updated_at")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
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
                let a_name = a
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_lowercase();
                let b_name = b
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_lowercase();
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

/// List all remote chats
pub async fn list_remote_chats(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let pool = state.job_pool.clone();

    let chats = sqlx::query_as::<
        _,
        (
            String,
            Option<String>,
            String,
            String,
            String,
            Option<String>,
        ),
    >(
        "SELECT rc.chat_id, rc.name, rc.working_directory, d.name as device_name,
                rc.created_at, rc.last_updated_at
         FROM remote_chats rc
         JOIN devices d ON rc.device_id = d.id
         ORDER BY rc.last_updated_at DESC",
    )
    .fetch_all(&pool)
    .await?;

    let mut chats_json = Vec::new();
    for chat in chats {
        chats_json.push(json!({
            "chat_id": chat.0,
            "name": chat.1.unwrap_or_else(|| "Untitled".to_string()),
            "working_directory": chat.2,
            "device_name": chat.3,
            "created_at": chat.4,
            "last_updated_at": chat.5,
        }));
    }

    Ok(Json(json!({
        "chats": chats_json
    })))
}

/// List all cursor-agent chats
pub async fn list_cursor_agent_chats(
    State(_state): State<Arc<AppState>>,
    Query(params): Query<ListChatsQuery>,
) -> Result<Json<Value>> {
    let chats = tokio::task::spawn_blocking(move || {
        crate::db::cursor_agent::list_all_cursor_agent_chats()
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;

    // Apply filtering and sorting
    let mut chats = chats;

    // Filter archived chats if not requested
    if !params.include_archived {
        chats.retain(|chat| {
            !chat
                .get("is_archived")
                .and_then(|v| v.as_bool())
                .unwrap_or(false)
        });
    }

    // Sort chats
    match params.sort_by.as_str() {
        "last_updated" => {
            chats.sort_by(|a, b| {
                let a_time = a
                    .get("last_updated_at")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
                let b_time = b
                    .get("last_updated_at")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0);
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
                let a_name = a
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_lowercase();
                let b_name = b
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_lowercase();
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
    let pool = state.job_pool.clone();
    let chat_id_for_remote_check = chat_id.clone();

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

    // Check if this is a remote chat
    let remote_info = sqlx::query_as::<_, (String, String, String)>(
        "SELECT rc.device_id, rc.working_directory, d.name 
         FROM remote_chats rc 
         JOIN devices d ON rc.device_id = d.id 
         WHERE rc.chat_id = ?",
    )
    .bind(&chat_id_for_remote_check)
    .fetch_optional(&pool)
    .await
    .ok()
    .flatten();

    let mut metadata_obj = metadata.as_object().unwrap().clone();

    if let Some((device_id, working_dir, device_name)) = remote_info {
        metadata_obj.insert("location".to_string(), json!("remote"));
        metadata_obj.insert("device_id".to_string(), json!(device_id));
        metadata_obj.insert("device_name".to_string(), json!(device_name));
        metadata_obj.insert("working_directory".to_string(), json!(working_dir));

        // Fetch device status
        let device_status =
            sqlx::query_scalar::<_, String>("SELECT status FROM devices WHERE id = ?")
                .bind(&device_id)
                .fetch_one(&pool)
                .await
                .unwrap_or("unknown".to_string());

        metadata_obj.insert("device_status".to_string(), json!(device_status));
    } else {
        metadata_obj.insert("location".to_string(), json!("local"));
    }

    Ok(Json(json!(metadata_obj)))
}

/// Get all messages for a specific chat
pub async fn get_chat_messages(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
    Query(params): Query<GetMessagesQuery>,
) -> Result<Json<Value>> {
    let settings = state.settings.clone();
    let pool = state.job_pool.clone();
    let chat_id_for_check = chat_id.clone();
    let chat_id_for_metadata = chat_id.clone();

    // Check if this is a remote chat and get device info if so
    let remote_info = sqlx::query_as::<_, (String, String)>(
        "SELECT rc.device_id, d.api_endpoint 
         FROM remote_chats rc 
         JOIN devices d ON rc.device_id = d.id 
         WHERE rc.chat_id = ?",
    )
    .bind(&chat_id_for_check)
    .fetch_optional(&pool)
    .await?;

    let is_remote = remote_info.is_some();

    // If remote, fetch messages from remote device
    if is_remote {
        let (device_id, api_endpoint) = remote_info.unwrap();
        tracing::info!(
            "Fetching messages for remote chat {} from device {}",
            chat_id,
            device_id
        );

        // Build URL for remote messages endpoint
        let mut url = format!(
            "{}/messages/{}?include_metadata={}&include_content={}",
            api_endpoint, chat_id, params.include_metadata, params.include_content
        );

        if let Some(limit) = params.limit {
            url = format!("{}&limit={}", url, limit);
        }

        // Try to fetch from remote
        let remote_result = state.http_client.get(&url).send().await;

        let mut result = match remote_result {
            Ok(response) if response.status().is_success() => {
                // Successfully fetched from remote
                response.json::<Value>().await.map_err(|e| {
                    crate::AppError::Internal(format!("Failed to parse remote response: {}", e))
                })?
            }
            Ok(response) => {
                // Remote returned an error - try local fallback
                tracing::warn!(
                    "Remote agent returned error {}, falling back to local Cursor DB",
                    response.status()
                );

                // Fall through to local fetch below
                let settings_clone = settings.clone();
                let chat_id_clone = chat_id.clone();
                let params_clone = params.clone();

                tokio::task::spawn_blocking(move || {
                    fetch_local_messages(&settings_clone, &chat_id_clone, &params_clone, true)
                })
                .await
                .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??
            }
            Err(e) => {
                // Network error - try local fallback
                tracing::warn!(
                    "Failed to connect to remote device: {}. Falling back to local Cursor DB",
                    e
                );

                // Fall through to local fetch
                let settings_clone = settings.clone();
                let chat_id_clone = chat_id.clone();
                let params_clone = params.clone();

                tokio::task::spawn_blocking(move || {
                    fetch_local_messages(&settings_clone, &chat_id_clone, &params_clone, true)
                })
                .await
                .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??
            }
        };

        // Enhance metadata with device info if present
        if params.include_metadata {
            if let Some(metadata) = result.get_mut("metadata") {
                if let Some(meta_obj) = metadata.as_object_mut() {
                    // Add remote chat metadata from our database
                    let chat_info = sqlx::query_as::<_, (String, String, String)>(
                        "SELECT rc.working_directory, rc.name, d.name 
                         FROM remote_chats rc 
                         JOIN devices d ON rc.device_id = d.id 
                         WHERE rc.chat_id = ?",
                    )
                    .bind(&chat_id_for_metadata)
                    .fetch_one(&pool)
                    .await?;

                    let (working_dir, chat_name, device_name) = chat_info;

                    meta_obj.insert("location".to_string(), json!("remote"));
                    meta_obj.insert("device_id".to_string(), json!(device_id));
                    meta_obj.insert("device_name".to_string(), json!(device_name));
                    meta_obj.insert("working_directory".to_string(), json!(working_dir));
                    meta_obj.insert("remote_chat_name".to_string(), json!(chat_name));
                }
            }
        }

        return Ok(Json(result));
    }

    // Local chat - fetch from local Cursor DB
    let params_clone = params.clone();
    let mut result = tokio::task::spawn_blocking(move || {
        fetch_local_messages(&settings, &chat_id, &params_clone, false)
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;

    // If metadata was requested, check for remote chat info
    if params.include_metadata {
        tracing::debug!("Checking for remote chat info for {}", chat_id_for_metadata);
        let remote_info = sqlx::query_as::<_, (String, String, String, String, String)>(
            "SELECT rc.device_id, rc.working_directory, rc.name, rc.created_at, d.name 
             FROM remote_chats rc 
             JOIN devices d ON rc.device_id = d.id 
             WHERE rc.chat_id = ?",
        )
        .bind(&chat_id_for_metadata)
        .fetch_optional(&pool)
        .await
        .ok()
        .flatten();

        tracing::debug!("Remote info result: {:?}", remote_info);

        if let Some((device_id, working_dir, chat_name, created_at, device_name)) = remote_info {
            // This is a remote chat - create or update metadata
            if result.get("metadata").is_none() {
                // No Cursor DB metadata, create from remote_chats table
                result["metadata"] = json!({
                    "name": chat_name,
                    "created_at_iso": created_at,
                    "is_archived": false,
                    "is_draft": false,
                    "total_lines_added": 0,
                    "total_lines_removed": 0,
                });
            }

            // Add location and remote info
            if let Some(metadata_obj) = result.get_mut("metadata").and_then(|m| m.as_object_mut()) {
                metadata_obj.insert("location".to_string(), json!("remote"));
                metadata_obj.insert("device_id".to_string(), json!(device_id));
                metadata_obj.insert("device_name".to_string(), json!(device_name));
                metadata_obj.insert("working_directory".to_string(), json!(working_dir));

                // Fetch device status
                let device_status =
                    sqlx::query_scalar::<_, String>("SELECT status FROM devices WHERE id = ?")
                        .bind(&device_id)
                        .fetch_one(&pool)
                        .await
                        .unwrap_or("unknown".to_string());

                metadata_obj.insert("device_status".to_string(), json!(device_status));
            }
        } else if result.get("metadata").is_some() {
            // Local chat with Cursor DB metadata
            if let Some(metadata_obj) = result.get_mut("metadata").and_then(|m| m.as_object_mut()) {
                metadata_obj.insert("location".to_string(), json!("local"));
            }
        }
    }

    Ok(Json(result))
}

/// Get cache consistency status
pub async fn get_cache_status(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let settings = state.settings.clone();

    let status = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;
        let status = cache_sync::verify_cache_consistency(&conn)?;
        Ok::<_, crate::AppError>(status)
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;

    Ok(Json(json!({
        "status": "ok",
        "cache_status": {
            "composer_data_count": status.composer_data_count,
            "cache_entry_count": status.cache_entry_count,
            "is_consistent": status.is_consistent,
            "missing_cache_entries_count": status.missing_cache_entries.len(),
            "orphaned_cache_entries_count": status.orphaned_cache_entries.len(),
            "missing_cache_entries": status.missing_cache_entries,
            "orphaned_cache_entries": status.orphaned_cache_entries,
        }
    })))
}

/// Verify and fix cache consistency
pub async fn verify_and_fix_cache(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let settings = state.settings.clone();

    let result = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;

        // Get initial status
        let initial_status = cache_sync::verify_cache_consistency(&conn)?;

        // Sync missing entries
        let synced_chats = cache_sync::sync_missing_cache_entries(&conn)?;

        // Clean orphaned entries
        let cleaned_entries = cache_sync::clean_orphaned_cache_entries(&conn)?;

        // Get final status
        let final_status = cache_sync::verify_cache_consistency(&conn)?;

        Ok::<_, crate::AppError>(json!({
            "initial_status": {
                "is_consistent": initial_status.is_consistent,
                "missing_count": initial_status.missing_cache_entries.len(),
                "orphaned_count": initial_status.orphaned_cache_entries.len(),
            },
            "actions_taken": {
                "synced_chats": synced_chats,
                "cleaned_entries": cleaned_entries,
            },
            "final_status": {
                "is_consistent": final_status.is_consistent,
                "composer_data_count": final_status.composer_data_count,
                "cache_entry_count": final_status.cache_entry_count,
            }
        }))
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;

    Ok(Json(result))
}

/// Sync cache for a specific chat
pub async fn sync_chat_cache(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
) -> Result<Json<Value>> {
    let settings = state.settings.clone();

    let result = tokio::task::spawn_blocking(move || {
        let conn = get_cursor_db_connection(&settings)?;
        let success = cache_sync::sync_chat_cache(&conn, &chat_id)?;

        if !success {
            return Err(crate::AppError::NotFound(format!(
                "Chat {} not found",
                chat_id
            )));
        }

        Ok::<_, crate::AppError>(json!({
            "status": "ok",
            "chat_id": chat_id,
            "message": "Cache entry created/updated successfully"
        }))
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;

    Ok(Json(result))
}
