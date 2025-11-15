use crate::error::Result;
use rusqlite::Connection;
use serde_json::json;
use std::collections::HashSet;
use uuid::Uuid;

/// Status of cache consistency check
#[derive(Debug, Clone, serde::Serialize)]
pub struct CacheStatus {
    pub composer_data_count: usize,
    pub cache_entry_count: usize,
    pub missing_cache_entries: Vec<String>,
    pub orphaned_cache_entries: Vec<String>,
    pub is_consistent: bool,
}

/// Verify cache consistency between cursorDiskKV and ItemTable
pub fn verify_cache_consistency(conn: &Connection) -> Result<CacheStatus> {
    // Get all composerData chat IDs
    let mut stmt = conn.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'")?;

    let composer_ids: HashSet<String> = stmt
        .query_map([], |row| {
            let key: String = row.get(0)?;
            Ok(key.replace("composerData:", ""))
        })?
        .collect::<std::result::Result<HashSet<String>, rusqlite::Error>>()?;

    // Get all ItemTable cache entries
    let mut stmt = conn.prepare(
        "SELECT key FROM ItemTable WHERE key LIKE 'workbench.panel.composerChatViewPane.%.hidden'",
    )?;

    let cache_ids: HashSet<String> = stmt
        .query_map([], |row| {
            let key: String = row.get(0)?;
            // Extract UUID from: workbench.panel.composerChatViewPane.{uuid}.hidden
            let parts: Vec<&str> = key.split('.').collect();
            if parts.len() >= 4 {
                Ok(parts[3].to_string())
            } else {
                Ok(String::new())
            }
        })?
        .filter_map(|r| r.ok())
        .filter(|s| !s.is_empty())
        .collect();

    // Find missing cache entries (chats without cache)
    let missing_cache_entries: Vec<String> = composer_ids.difference(&cache_ids).cloned().collect();

    // Find orphaned cache entries (cache without chats)
    let orphaned_cache_entries: Vec<String> =
        cache_ids.difference(&composer_ids).cloned().collect();

    let is_consistent = missing_cache_entries.is_empty() && orphaned_cache_entries.is_empty();

    Ok(CacheStatus {
        composer_data_count: composer_ids.len(),
        cache_entry_count: cache_ids.len(),
        missing_cache_entries,
        orphaned_cache_entries,
        is_consistent,
    })
}

/// Sync missing cache entries for existing chats
pub fn sync_missing_cache_entries(conn: &Connection) -> Result<Vec<String>> {
    let status = verify_cache_consistency(conn)?;
    let mut synced_chats = Vec::new();

    for chat_id in &status.missing_cache_entries {
        create_cache_entry(conn, chat_id)?;
        synced_chats.push(chat_id.clone());
    }

    Ok(synced_chats)
}

/// Create a cache entry for a specific chat
pub fn create_cache_entry(conn: &Connection, chat_id: &str) -> Result<()> {
    let key = format!("workbench.panel.composerChatViewPane.{}.hidden", chat_id);

    // Generate a view ID
    let view_id = Uuid::new_v4().to_string();

    // Create the cache entry value
    let cache_value = json!([{
        "id": format!("workbench.panel.aichat.view.{}", view_id),
        "isHidden": false
    }]);

    let value_str = cache_value.to_string();

    // Insert into ItemTable
    conn.execute(
        "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
        [&key, &value_str],
    )?;

    Ok(())
}

/// Clean up orphaned cache entries (cache entries without corresponding chats)
pub fn clean_orphaned_cache_entries(conn: &Connection) -> Result<Vec<String>> {
    let status = verify_cache_consistency(conn)?;
    let mut cleaned_entries = Vec::new();

    for chat_id in &status.orphaned_cache_entries {
        let key = format!("workbench.panel.composerChatViewPane.{}.hidden", chat_id);
        conn.execute("DELETE FROM ItemTable WHERE key = ?", [&key])?;
        cleaned_entries.push(chat_id.clone());
    }

    Ok(cleaned_entries)
}

/// Sync a specific chat's cache entry
pub fn sync_chat_cache(conn: &Connection, chat_id: &str) -> Result<bool> {
    // Check if the chat exists in cursorDiskKV
    let key = format!("composerData:{}", chat_id);
    let mut stmt = conn.prepare("SELECT 1 FROM cursorDiskKV WHERE key = ?")?;

    let exists = stmt.exists([&key])?;

    if !exists {
        return Ok(false);
    }

    // Create or update cache entry
    create_cache_entry(conn, chat_id)?;

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn setup_test_db() -> Connection {
        let conn = Connection::open_in_memory().unwrap();

        // Create tables
        conn.execute(
            "CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value BLOB)",
            [],
        )
        .unwrap();

        conn.execute(
            "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT)",
            [],
        )
        .unwrap();

        conn
    }

    #[test]
    fn test_verify_empty_database() {
        let conn = setup_test_db();
        let status = verify_cache_consistency(&conn).unwrap();

        assert_eq!(status.composer_data_count, 0);
        assert_eq!(status.cache_entry_count, 0);
        assert!(status.is_consistent);
    }

    #[test]
    fn test_missing_cache_entry() {
        let conn = setup_test_db();
        let chat_id = "test-chat-123";

        // Add composerData without cache entry
        conn.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            [&format!("composerData:{}", chat_id), "{}"],
        )
        .unwrap();

        let status = verify_cache_consistency(&conn).unwrap();

        assert_eq!(status.composer_data_count, 1);
        assert_eq!(status.cache_entry_count, 0);
        assert!(!status.is_consistent);
        assert_eq!(status.missing_cache_entries.len(), 1);
        assert_eq!(status.missing_cache_entries[0], chat_id);
    }

    #[test]
    fn test_sync_missing_entries() {
        let conn = setup_test_db();
        let chat_id = "test-chat-456";

        // Add composerData without cache entry
        conn.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            [&format!("composerData:{}", chat_id), "{}"],
        )
        .unwrap();

        // Sync missing entries
        let synced = sync_missing_cache_entries(&conn).unwrap();

        assert_eq!(synced.len(), 1);
        assert_eq!(synced[0], chat_id);

        // Verify consistency after sync
        let status = verify_cache_consistency(&conn).unwrap();
        assert!(status.is_consistent);
    }
}
