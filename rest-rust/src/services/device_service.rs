use crate::db::device_db;
use crate::models::device::{Device, DeviceCreate, DeviceStatus, RemoteChat, RemoteChatCreate};
use crate::Result;
use chrono::Utc;
use sqlx::SqlitePool;
use uuid::Uuid;

/// Get all active devices
pub async fn get_all_devices(pool: &SqlitePool) -> Result<Vec<Device>> {
    device_db::get_all_devices(pool).await
}

/// Get a device by ID
pub async fn get_device(pool: &SqlitePool, device_id: &str) -> Result<Option<Device>> {
    device_db::get_device(pool, device_id).await
}

/// Create a new device
pub async fn create_device(pool: &SqlitePool, device_create: DeviceCreate) -> Result<Device> {
    let device_id = Uuid::new_v4().to_string();
    let now = Utc::now();
    
    sqlx::query(
        r#"
        INSERT INTO devices (id, name, hostname, username, port, cursor_agent_path, 
                            created_at, is_active, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'unknown')
        "#,
    )
    .bind(&device_id)
    .bind(&device_create.name)
    .bind(&device_create.hostname)
    .bind(&device_create.username)
    .bind(device_create.port)
    .bind(device_create.cursor_agent_path.as_deref())
    .bind(now.to_rfc3339())
    .execute(pool)
    .await?;
    
    Ok(Device {
        id: device_id,
        name: device_create.name,
        hostname: device_create.hostname,
        username: device_create.username,
        port: device_create.port,
        cursor_agent_path: device_create.cursor_agent_path,
        created_at: now,
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Unknown,
    })
}

/// Update device last_seen timestamp
pub async fn update_device_last_seen(pool: &SqlitePool, device_id: &str) -> Result<()> {
    let now = Utc::now();
    
    sqlx::query("UPDATE devices SET last_seen = ?, status = 'online' WHERE id = ?")
        .bind(now.to_rfc3339())
        .bind(device_id)
        .execute(pool)
        .await?;
    
    Ok(())
}

/// Update device status
pub async fn update_device_status(
    pool: &SqlitePool,
    device_id: &str,
    status: DeviceStatus,
) -> Result<()> {
    let status_str = match status {
        DeviceStatus::Online => "online",
        DeviceStatus::Offline => "offline",
        DeviceStatus::Unknown => "unknown",
    };
    
    sqlx::query("UPDATE devices SET status = ? WHERE id = ?")
        .bind(status_str)
        .bind(device_id)
        .execute(pool)
        .await?;
    
    Ok(())
}

/// Delete a device (soft delete by setting is_active = false)
pub async fn delete_device(pool: &SqlitePool, device_id: &str) -> Result<()> {
    sqlx::query("UPDATE devices SET is_active = 0 WHERE id = ?")
        .bind(device_id)
        .execute(pool)
        .await?;
    
    Ok(())
}

/// Create a remote chat
pub async fn create_remote_chat(
    pool: &SqlitePool,
    create: RemoteChatCreate,
) -> Result<RemoteChat> {
    let chat_id = Uuid::new_v4().to_string();
    let now = Utc::now();
    let name = create.name.unwrap_or_else(|| "Untitled".to_string());
    
    sqlx::query(
        r#"
        INSERT INTO remote_chats (chat_id, device_id, working_directory, name, 
                                  created_at, message_count)
        VALUES (?, ?, ?, ?, ?, 0)
        "#,
    )
    .bind(&chat_id)
    .bind(&create.device_id)
    .bind(&create.working_directory)
    .bind(&name)
    .bind(now.to_rfc3339())
    .execute(pool)
    .await?;
    
    Ok(RemoteChat {
        chat_id,
        device_id: create.device_id,
        working_directory: create.working_directory,
        name,
        created_at: now,
        last_updated_at: None,
        message_count: 0,
        last_message_preview: None,
    })
}

/// Get remote chat by ID
pub async fn get_remote_chat(pool: &SqlitePool, chat_id: &str) -> Result<Option<RemoteChat>> {
    device_db::get_remote_chat(pool, chat_id).await
}

/// Update remote chat metadata after message
pub async fn update_remote_chat_metadata(
    pool: &SqlitePool,
    chat_id: &str,
    preview: Option<&str>,
) -> Result<()> {
    let now = Utc::now();
    
    sqlx::query(
        r#"
        UPDATE remote_chats 
        SET last_updated_at = ?, 
            message_count = message_count + 1,
            last_message_preview = COALESCE(?, last_message_preview)
        WHERE chat_id = ?
        "#,
    )
    .bind(now.to_rfc3339())
    .bind(preview)
    .bind(chat_id)
    .execute(pool)
    .await?;
    
    Ok(())
}

