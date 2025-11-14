use crate::error::Result;
use crate::models::device::{DeviceRow, RemoteChatRow};
use crate::models::{Device, RemoteChat};
use sqlx::{Row, SqlitePool};

/// Initialize the device database with required tables
pub async fn ensure_device_db_initialized(pool: &SqlitePool) -> Result<()> {
    // Check if devices table exists and has correct schema
    let devices_table_info = sqlx::query("SELECT sql FROM sqlite_master WHERE type='table' AND name='devices'")
        .fetch_optional(pool)
        .await?;
    
    if let Some(row) = devices_table_info {
        let sql: String = row.try_get("sql")?;
        // If the schema is missing api_endpoint column, we need to migrate
        if !sql.contains("api_endpoint") {
            tracing::warn!("Detected old devices schema missing api_endpoint column, migrating...");
            
            // Backup existing data
            let has_data: i32 = sqlx::query_scalar("SELECT COUNT(*) FROM devices")
                .fetch_one(pool)
                .await?;
            
            if has_data > 0 {
                tracing::info!("Backing up {} devices before migration", has_data);
                // Create backup table
                sqlx::query("CREATE TABLE devices_backup AS SELECT * FROM devices")
                    .execute(pool)
                    .await?;
            }
            
            // Drop old table
            sqlx::query("DROP TABLE devices")
                .execute(pool)
                .await?;
            
            tracing::info!("Recreating devices table with new schema");
        }
    }
    
    // Create devices table (or recreate if dropped above)
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            api_endpoint TEXT NOT NULL,
            api_key TEXT,
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
    
    // If we had a backup, restore with default api_endpoint
    let devices_backup_exists: i32 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='devices_backup'"
    )
    .fetch_one(pool)
    .await?;
    
    if devices_backup_exists > 0 {
        tracing::info!("Restoring devices from backup with default values for missing columns");
        
        // Get the list of columns in the backup table
        let columns: Vec<String> = sqlx::query_scalar(
            "SELECT name FROM pragma_table_info('devices_backup')"
        )
        .fetch_all(pool)
        .await?;
        
        // Build the SELECT clause dynamically based on available columns
        let select_fields = vec![
            "id",
            "name",
            if columns.contains(&"api_endpoint".to_string()) { 
                "api_endpoint" 
            } else { 
                "'http://localhost:8000' as api_endpoint" 
            },
            if columns.contains(&"api_key".to_string()) { 
                "api_key" 
            } else { 
                "NULL as api_key" 
            },
            if columns.contains(&"cursor_agent_path".to_string()) { 
                "cursor_agent_path" 
            } else { 
                "NULL as cursor_agent_path" 
            },
            "created_at",
            if columns.contains(&"last_seen".to_string()) { 
                "last_seen" 
            } else { 
                "NULL as last_seen" 
            },
            if columns.contains(&"is_active".to_string()) { 
                "is_active" 
            } else { 
                "1 as is_active" 
            },
            if columns.contains(&"status".to_string()) { 
                "status" 
            } else { 
                "'unknown' as status" 
            },
        ].join(", ");
        
        let query = format!(
            "INSERT INTO devices (id, name, api_endpoint, api_key, cursor_agent_path, \
                                 created_at, last_seen, is_active, status) \
             SELECT {} FROM devices_backup",
            select_fields
        );
        
        let restore_result = sqlx::query(&query)
            .execute(pool)
            .await;
        
        if let Err(e) = restore_result {
            tracing::error!("Failed to restore devices from backup: {}. Starting fresh.", e);
        } else {
            tracing::info!("Devices restored successfully");
        }
        
        // Drop backup table
        sqlx::query("DROP TABLE devices_backup")
            .execute(pool)
            .await?;
    }
    
    // Check if remote_chats table exists and has correct schema
    let table_info = sqlx::query("SELECT sql FROM sqlite_master WHERE type='table' AND name='remote_chats'")
        .fetch_optional(pool)
        .await?;
    
    if let Some(row) = table_info {
        let sql: String = row.try_get("sql")?;
        // If the schema has INTEGER for created_at, we need to recreate
        if sql.contains("created_at INTEGER") || sql.contains("created_at INT") {
            tracing::warn!("Detected old remote_chats schema with INTEGER timestamps, migrating...");
            
            // Backup existing data
            let has_data: i32 = sqlx::query_scalar("SELECT COUNT(*) FROM remote_chats")
                .fetch_one(pool)
                .await?;
            
            if has_data > 0 {
                tracing::info!("Backing up {} remote chats before migration", has_data);
                // Create backup table
                sqlx::query("CREATE TABLE remote_chats_backup AS SELECT * FROM remote_chats")
                    .execute(pool)
                    .await?;
            }
            
            // Drop old table
            sqlx::query("DROP TABLE remote_chats")
                .execute(pool)
                .await?;
            
            tracing::info!("Recreating remote_chats table with TEXT timestamps");
        }
    }
    
    // Create remote_chats table (or recreate if dropped above)
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
    
    // If we had a backup, try to restore data with converted timestamps
    let backup_exists: i32 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='remote_chats_backup'"
    )
    .fetch_one(pool)
    .await?;
    
    if backup_exists > 0 {
        tracing::info!("Restoring remote chats from backup with converted timestamps");
        sqlx::query(
            r#"
            INSERT INTO remote_chats (chat_id, device_id, working_directory, name, 
                                      created_at, last_updated_at, message_count, last_message_preview)
            SELECT chat_id, device_id, working_directory, name,
                   datetime(created_at / 1000, 'unixepoch') || 'Z',
                   CASE WHEN last_updated_at IS NOT NULL 
                        THEN datetime(last_updated_at / 1000, 'unixepoch') || 'Z'
                        ELSE NULL END,
                   message_count, last_message_preview
            FROM remote_chats_backup
            "#
        )
        .execute(pool)
        .await?;
        
        // Drop backup table
        sqlx::query("DROP TABLE remote_chats_backup")
            .execute(pool)
            .await?;
        
        tracing::info!("Migration complete");
    }
    
    Ok(())
}

/// Get all devices
pub async fn get_all_devices(pool: &SqlitePool) -> Result<Vec<Device>> {
    let rows = sqlx::query_as::<_, DeviceRow>(
        "SELECT id, name, api_endpoint, api_key, cursor_agent_path, 
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
        "SELECT id, name, api_endpoint, api_key, cursor_agent_path, 
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

