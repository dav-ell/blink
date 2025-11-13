use crate::error::Result;
use rusqlite::{Connection, Transaction};
use serde_json::{json, Value};
use std::collections::HashMap;

/// Ensure a chat exists in the database, creating it if necessary
pub fn ensure_chat_exists(
    conn: &Connection,
    chat_id: &str,
) -> Result<(bool, HashMap<String, Value>)> {
    let key = format!("composerData:{}", chat_id);
    let mut stmt = conn.prepare("SELECT value FROM cursorDiskKV WHERE key = ?")?;
    
    let existing = stmt.query_row([&key], |row| {
        let value_str: String = row.get(0)?;
        Ok(value_str)
    });
    
    match existing {
        Ok(value_str) => {
            let metadata: HashMap<String, Value> = serde_json::from_str(&value_str)?;
            Ok((false, metadata))
        }
        Err(rusqlite::Error::QueryReturnedNoRows) => {
            // Create minimal metadata
            let now_ms = chrono::Utc::now().timestamp_millis();
            
            // Create rich text structure
            let rich_text = json!({
                "root": {
                    "children": [{
                        "children": [],
                        "format": "",
                        "indent": 0,
                        "type": "paragraph",
                        "version": 1
                    }],
                    "format": "",
                    "indent": 0,
                    "type": "root",
                    "version": 1
                }
            });
            
            let mut metadata = HashMap::new();
            metadata.insert("_v".to_string(), Value::Number(10.into()));
            metadata.insert("composerId".to_string(), Value::String(chat_id.to_string()));
            metadata.insert("name".to_string(), Value::String("Untitled".to_string()));
            metadata.insert("richText".to_string(), Value::String(rich_text.to_string()));
            metadata.insert("hasLoaded".to_string(), Value::Bool(true));
            metadata.insert("text".to_string(), Value::String(String::new()));
            metadata.insert("fullConversationHeadersOnly".to_string(), Value::Array(vec![]));
            metadata.insert("createdAt".to_string(), Value::Number(now_ms.into()));
            metadata.insert("lastUpdatedAt".to_string(), Value::Number(now_ms.into()));
            metadata.insert("isArchived".to_string(), Value::Bool(false));
            metadata.insert("isDraft".to_string(), Value::Bool(false));
            metadata.insert("totalLinesAdded".to_string(), Value::Number(0.into()));
            metadata.insert("totalLinesRemoved".to_string(), Value::Number(0.into()));
            
            // Save to database
            let metadata_str = serde_json::to_string(&metadata)?;
            conn.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                [&key, &metadata_str],
            )?;
            
            Ok((true, metadata))
        }
        Err(e) => Err(e.into()),
    }
}

/// Ensure a chat exists within a transaction
pub fn ensure_chat_exists_tx(
    tx: &Transaction,
    chat_id: &str,
) -> Result<(bool, HashMap<String, Value>)> {
    let key = format!("composerData:{}", chat_id);
    let mut stmt = tx.prepare("SELECT value FROM cursorDiskKV WHERE key = ?")?;
    
    let existing = stmt.query_row([&key], |row| {
        let value_str: String = row.get(0)?;
        Ok(value_str)
    });
    
    match existing {
        Ok(value_str) => {
            let metadata: HashMap<String, Value> = serde_json::from_str(&value_str)?;
            Ok((false, metadata))
        }
        Err(rusqlite::Error::QueryReturnedNoRows) => {
            // Create minimal metadata (same as above)
            let now_ms = chrono::Utc::now().timestamp_millis();
            
            let rich_text = json!({
                "root": {
                    "children": [{
                        "children": [],
                        "format": "",
                        "indent": 0,
                        "type": "paragraph",
                        "version": 1
                    }],
                    "format": "",
                    "indent": 0,
                    "type": "root",
                    "version": 1
                }
            });
            
            let mut metadata = HashMap::new();
            metadata.insert("_v".to_string(), Value::Number(10.into()));
            metadata.insert("composerId".to_string(), Value::String(chat_id.to_string()));
            metadata.insert("name".to_string(), Value::String("Untitled".to_string()));
            metadata.insert("richText".to_string(), Value::String(rich_text.to_string()));
            metadata.insert("hasLoaded".to_string(), Value::Bool(true));
            metadata.insert("text".to_string(), Value::String(String::new()));
            metadata.insert("fullConversationHeadersOnly".to_string(), Value::Array(vec![]));
            metadata.insert("createdAt".to_string(), Value::Number(now_ms.into()));
            metadata.insert("lastUpdatedAt".to_string(), Value::Number(now_ms.into()));
            metadata.insert("isArchived".to_string(), Value::Bool(false));
            metadata.insert("isDraft".to_string(), Value::Bool(false));
            metadata.insert("totalLinesAdded".to_string(), Value::Number(0.into()));
            metadata.insert("totalLinesRemoved".to_string(), Value::Number(0.into()));
            
            let metadata_str = serde_json::to_string(&metadata)?;
            tx.execute(
                "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
                [&key, &metadata_str],
            )?;
            
            Ok((true, metadata))
        }
        Err(e) => Err(e.into()),
    }
}

/// Save a message bubble to the database
pub fn save_message_to_db(
    conn: &Connection,
    chat_id: &str,
    bubble_id: &str,
    bubble_data: &HashMap<String, Value>,
) -> Result<()> {
    let key = format!("bubbleId:{}:{}", chat_id, bubble_id);
    let value_str = serde_json::to_string(bubble_data)?;
    
    conn.execute(
        "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
        [&key, &value_str],
    )?;
    
    Ok(())
}

/// Save a message bubble within a transaction
pub fn save_message_to_db_tx(
    tx: &Transaction,
    chat_id: &str,
    bubble_id: &str,
    bubble_data: &HashMap<String, Value>,
) -> Result<()> {
    let key = format!("bubbleId:{}:{}", chat_id, bubble_id);
    let value_str = serde_json::to_string(bubble_data)?;
    
    tx.execute(
        "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
        [&key, &value_str],
    )?;
    
    Ok(())
}

/// Update chat metadata
pub fn update_chat_metadata(
    conn: &Connection,
    chat_id: &str,
    updates: HashMap<String, Value>,
) -> Result<()> {
    let key = format!("composerData:{}", chat_id);
    
    // Get existing metadata
    let mut metadata: HashMap<String, Value> = {
        let mut stmt = conn.prepare("SELECT value FROM cursorDiskKV WHERE key = ?")?;
        let value_str: String = stmt.query_row([&key], |row| row.get(0))?;
        serde_json::from_str(&value_str)?
    };
    
    // Apply updates
    for (k, v) in updates {
        metadata.insert(k, v);
    }
    
    // Save back
    let metadata_str = serde_json::to_string(&metadata)?;
    conn.execute(
        "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
        [&key, &metadata_str],
    )?;
    
    Ok(())
}

/// Update chat metadata within a transaction
pub fn update_chat_metadata_tx(
    tx: &Transaction,
    chat_id: &str,
    updates: HashMap<String, Value>,
) -> Result<()> {
    let key = format!("composerData:{}", chat_id);
    
    // Get existing metadata
    let mut metadata: HashMap<String, Value> = {
        let mut stmt = tx.prepare("SELECT value FROM cursorDiskKV WHERE key = ?")?;
        let value_str: String = stmt.query_row([&key], |row| row.get(0))?;
        serde_json::from_str(&value_str)?
    };
    
    // Apply updates
    for (k, v) in updates {
        metadata.insert(k, v);
    }
    
    // Save back
    let metadata_str = serde_json::to_string(&metadata)?;
    tx.execute(
        "INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)",
        [&key, &metadata_str],
    )?;
    
    Ok(())
}

/// Perform a complete message persistence operation with transaction
/// This ensures atomic writes: user message + AI response
pub fn persist_conversation_turn(
    conn: &mut Connection,
    chat_id: &str,
    user_bubble_id: &str,
    user_bubble: &HashMap<String, Value>,
    assistant_bubble_id: &str,
    assistant_bubble: &HashMap<String, Value>,
) -> Result<()> {
    let tx = conn.transaction()?;
    
    // Ensure chat exists
    ensure_chat_exists_tx(&tx, chat_id)?;
    
    // Save user message
    save_message_to_db_tx(&tx, chat_id, user_bubble_id, user_bubble)?;
    
    // Save assistant message
    save_message_to_db_tx(&tx, chat_id, assistant_bubble_id, assistant_bubble)?;
    
    // Update chat metadata (last updated time)
    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut updates = HashMap::new();
    updates.insert("lastUpdatedAt".to_string(), Value::Number(now_ms.into()));
    update_chat_metadata_tx(&tx, chat_id, updates)?;
    
    tx.commit()?;
    Ok(())
}

