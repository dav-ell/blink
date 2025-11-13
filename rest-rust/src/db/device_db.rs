use crate::error::Result;
use crate::models::device::{DeviceRow, RemoteChatRow};
use crate::models::{Device, RemoteChat};
use sqlx::SqlitePool;

/// Initialize the device database with required tables
pub async fn ensure_device_db_initialized(pool: &SqlitePool) -> Result<()> {
    // Create devices table
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hostname TEXT NOT NULL,
            username TEXT NOT NULL,
            port INTEGER NOT NULL DEFAULT 22,
            cursor_agent_path TEXT,
            created_at TEXT NOT NULL,
            last_seen TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'unknown'
        )
        "#,
    )
    .execute(pool)
    .await?;
    
    // Create remote_chats table
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS remote_chats (
            chat_id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            working_directory TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT 'Untitled',
            created_at TEXT NOT NULL,
            last_updated_at TEXT,
            message_count INTEGER NOT NULL DEFAULT 0,
            last_message_preview TEXT,
            FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;
    
    Ok(())
}

/// Get all devices
pub async fn get_all_devices(pool: &SqlitePool) -> Result<Vec<Device>> {
    let rows = sqlx::query_as::<_, DeviceRow>(
        "SELECT id, name, hostname, username, port, cursor_agent_path, 
                created_at, last_seen, is_active, status 
         FROM devices 
         WHERE is_active = 1 
         ORDER BY created_at DESC"
    )
    .fetch_all(pool)
    .await?;
    
    Ok(rows.into_iter().map(Device::from).collect())
}

/// Get a device by ID
pub async fn get_device(pool: &SqlitePool, device_id: &str) -> Result<Option<Device>> {
    let row = sqlx::query_as::<_, DeviceRow>(
        "SELECT id, name, hostname, username, port, cursor_agent_path, 
                created_at, last_seen, is_active, status 
         FROM devices 
         WHERE id = ?"
    )
    .bind(device_id)
    .fetch_optional(pool)
    .await?;
    
    Ok(row.map(Device::from))
}

/// Get a remote chat by ID
pub async fn get_remote_chat(pool: &SqlitePool, chat_id: &str) -> Result<Option<RemoteChat>> {
    let row = sqlx::query_as::<_, RemoteChatRow>(
        "SELECT chat_id, device_id, working_directory, name, 
                created_at, last_updated_at, message_count, last_message_preview 
         FROM remote_chats 
         WHERE chat_id = ?"
    )
    .bind(chat_id)
    .fetch_optional(pool)
    .await?;
    
    Ok(row.map(RemoteChat::from))
}

