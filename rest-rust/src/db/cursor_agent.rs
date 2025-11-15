use crate::AppError;
use anyhow::anyhow;
use rusqlite::Connection;
use serde_json::{json, Value};
use std::path::PathBuf;

/// Find cursor-agent chat directory
pub fn find_cursor_agent_chat(chat_id: &str) -> Result<PathBuf, AppError> {
    let home = dirs::home_dir().ok_or_else(|| {
        AppError::Internal("Could not determine home directory".to_string())
    })?;
    let chats_dir = home.join(".cursor").join("chats");
    
    if !chats_dir.exists() {
        return Err(AppError::Internal(format!("cursor-agent chats directory not found: {:?}", chats_dir)));
    }
    
    // Search all user hash directories for the chat
    for entry in std::fs::read_dir(&chats_dir).map_err(|e| {
        AppError::Internal(format!("Failed to read chats dir: {}", e))
    })? {
        let entry = entry.map_err(|e| {
            AppError::Internal(format!("Failed to read entry: {}", e))
        })?;
        let chat_path = entry.path().join(chat_id);
        if chat_path.exists() && chat_path.is_dir() {
            return Ok(chat_path);
        }
    }
    
    Err(AppError::Internal(format!("Chat {} not found in cursor-agent storage", chat_id)))
}

/// Get chat metadata from cursor-agent format
pub fn get_chat_metadata_from_agent(chat_id: &str) -> Result<Value, AppError> {
    let chat_path = find_cursor_agent_chat(chat_id)?;
    let db_path = chat_path.join("store.db");
    let conn = Connection::open(&db_path)
        .map_err(|e| AppError::Internal(format!("Failed to open store.db: {}", e)))?;
    
    // Read hex-encoded JSON from meta table
    let hex_value: String = conn.query_row(
        "SELECT value FROM meta WHERE key = '0'",
        [],
        |row| row.get(0),
    ).map_err(|e| AppError::Internal(format!("Failed to read metadata: {}", e)))?;
    
    // Decode hex to JSON
    let json_bytes = hex::decode(&hex_value)
        .map_err(|e| AppError::Internal(format!("Failed to decode hex: {}", e)))?;
    let metadata: Value = serde_json::from_slice(&json_bytes)
        .map_err(|e| AppError::Internal(format!("Failed to parse JSON: {}", e)))?;
    
    Ok(metadata)
}

/// Extract JSON message from blob data
/// The blob contains protobuf-wrapped JSON. We extract the JSON substring.
fn extract_json_from_blob(blob_data: &[u8]) -> Result<Value, AppError> {
    // Convert to string, looking for JSON content
    let data_str = String::from_utf8_lossy(blob_data);
    
    // Find JSON object (starts with { and contains "role")
    if let Some(start) = data_str.find('{') {
        if let Some(end) = data_str.rfind('}') {
            if end > start {
                let json_str = &data_str[start..=end];
                if json_str.contains("\"role\"") {
                    // This looks like a message JSON
                    return serde_json::from_str(json_str)
                        .map_err(|e| AppError::Internal(format!("Failed to parse message JSON: {}", e)));
                }
            }
        }
    }
    
    // No JSON found, return minimal structure
    Ok(json!({}))
}

/// Get all messages from cursor-agent format
pub fn get_chat_messages_from_agent(
    chat_id: &str,
    include_content: bool,
) -> Result<Vec<Value>, AppError> {
    let chat_path = find_cursor_agent_chat(chat_id)?;
    let db_path = chat_path.join("store.db");
    
    tracing::debug!("Opening cursor-agent DB: {:?}", db_path);
    let conn = Connection::open(&db_path)
        .map_err(|e| AppError::Internal(format!("Failed to open store.db: {}", e)))?;
    
    let mut stmt = conn.prepare("SELECT id, data FROM blobs ORDER BY id")
        .map_err(|e| AppError::Internal(format!("Failed to prepare statement: {}", e)))?;
    
    let rows = stmt.query_map([], |row| {
        let id: String = row.get(0)?;
        let data: Vec<u8> = row.get(1)?;
        Ok((id, data))
    }).map_err(|e| AppError::Internal(format!("Failed to query blobs: {}", e)))?;
    
    let mut messages = Vec::new();
    let mut blob_count = 0;
    
    for row in rows {
        let (blob_id, data) = row.map_err(|e| AppError::Internal(format!("Failed to read row: {}", e)))?;
        blob_count += 1;
        
        if include_content {
            // Try to extract JSON message
            match extract_json_from_blob(&data) {
                Ok(json_msg) if json_msg.get("role").is_some() => {
                    let role = json_msg["role"].as_str().unwrap_or("unknown");
                    let role_type = if role == "user" { 1 } else { 2 };
                    
                    // Extract text content
                    let text = if let Some(text_field) = json_msg.get("text") {
                        // Assistant messages often have top-level "text"
                        text_field.as_str().unwrap_or("").to_string()
                    } else if let Some(content) = json_msg.get("content").and_then(|c| c.as_array()) {
                        // User messages have content array
                        content.iter()
                            .filter_map(|item| {
                                item.get("text").and_then(|t| t.as_str())
                            })
                            .collect::<Vec<_>>()
                            .join("\n")
                    } else {
                        String::new()
                    };
                    
                    messages.push(json!({
                        "blob_id": blob_id,
                        "type": role_type,
                        "type_label": role,
                        "text": text,
                        "is_remote": false,  // Local cursor-agent chat
                    }));
                }
                _ => {
                    // Non-message blob (state/metadata), skip it
                }
            }
        } else {
            // Just return blob info without content
            messages.push(json!({
                "blob_id": blob_id,
                "text": "[Content not included]",
                "is_remote": false,
            }));
        }
    }
    
    tracing::debug!("Processed {} blobs, extracted {} messages (include_content={})", blob_count, messages.len(), include_content);
    Ok(messages)
}

