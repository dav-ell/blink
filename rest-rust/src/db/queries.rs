use crate::error::Result;
use crate::models::ChatMetadata;
use rusqlite::Connection;
use serde_json::Value;
use std::collections::HashMap;

/// Get all chat IDs from the database
pub fn get_all_chat_ids(conn: &Connection) -> Result<Vec<String>> {
    let mut stmt = conn.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'")?;

    let chat_ids: Vec<String> = stmt
        .query_map([], |row| {
            let key: String = row.get(0)?;
            Ok(key.replace("composerData:", ""))
        })?
        .collect::<std::result::Result<Vec<String>, rusqlite::Error>>()?;

    Ok(chat_ids)
}

/// Get metadata for a specific chat
pub fn get_chat_metadata(conn: &Connection, chat_id: &str) -> Result<Option<ChatMetadata>> {
    let key = format!("composerData:{}", chat_id);
    let mut stmt = conn.prepare("SELECT value FROM cursorDiskKV WHERE key = ?")?;

    let result = stmt.query_row([&key], |row| {
        let value_str: String = row.get(0)?;
        Ok(value_str)
    });

    match result {
        Ok(value_str) => {
            let metadata_json: HashMap<String, Value> = serde_json::from_str(&value_str)?;

            // Parse the metadata into our ChatMetadata struct
            let chat_metadata = ChatMetadata {
                chat_id: chat_id.to_string(),
                name: metadata_json
                    .get("name")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string()),
                created_at: metadata_json.get("createdAt").and_then(|v| v.as_i64()),
                created_at_iso: None, // Computed later if needed
                last_updated_at: metadata_json.get("lastUpdatedAt").and_then(|v| v.as_i64()),
                last_updated_at_iso: None, // Computed later if needed
                is_archived: metadata_json
                    .get("isArchived")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false),
                is_draft: metadata_json
                    .get("isDraft")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false),
                total_lines_added: metadata_json
                    .get("totalLinesAdded")
                    .and_then(|v| v.as_i64())
                    .map(|n| n as i32)
                    .unwrap_or(0),
                total_lines_removed: metadata_json
                    .get("totalLinesRemoved")
                    .and_then(|v| v.as_i64())
                    .map(|n| n as i32)
                    .unwrap_or(0),
                subtitle: metadata_json
                    .get("subtitle")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string()),
                message_count: 0, // Computed separately
            };

            Ok(Some(chat_metadata))
        }
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e.into()),
    }
}

/// Get all messages for a specific chat
pub fn get_chat_messages(
    conn: &Connection,
    chat_id: &str,
) -> Result<Vec<(String, HashMap<String, Value>)>> {
    let pattern = format!("bubbleId:{}:%", chat_id);
    let mut stmt =
        conn.prepare("SELECT key, value FROM cursorDiskKV WHERE key LIKE ? ORDER BY key")?;

    let messages: Result<Vec<(String, HashMap<String, Value>)>> = stmt
        .query_map([pattern], |row| {
            let key: String = row.get(0)?;
            let value_str: String = row.get(1)?;
            Ok((key, value_str))
        })?
        .map(|result| {
            result.map_err(|e| e.into()).and_then(|(key, value_str)| {
                let bubble_id = key.split(':').last().unwrap_or("").to_string();
                let bubble_data: HashMap<String, Value> = serde_json::from_str(&value_str)?;
                Ok((bubble_id, bubble_data))
            })
        })
        .collect();

    messages
}

/// Count total number of chats
pub fn count_chats(conn: &Connection, include_archived: bool) -> Result<i32> {
    if include_archived {
        let count: i32 = conn.query_row(
            "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%'",
            [],
            |row| row.get(0),
        )?;
        Ok(count)
    } else {
        let mut stmt =
            conn.prepare("SELECT value FROM cursorDiskKV WHERE key LIKE 'composerData:%'")?;

        let mut count = 0;
        let rows = stmt.query_map([], |row| {
            let value_str: String = row.get(0)?;
            Ok(value_str)
        })?;

        for row_result in rows {
            let value_str = row_result?;
            if let Ok(metadata) = serde_json::from_str::<HashMap<String, Value>>(&value_str) {
                if !metadata
                    .get("isArchived")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false)
                {
                    count += 1;
                }
            }
        }

        Ok(count)
    }
}
