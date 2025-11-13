use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use validator::Validate;

// Database representation with string timestamps
#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct DeviceRow {
    pub id: String,
    pub name: String,
    pub api_endpoint: String,
    pub api_key: Option<String>,
    pub cursor_agent_path: Option<String>,
    pub created_at: String,  // ISO 8601 string
    pub last_seen: Option<String>,  // ISO 8601 string
    pub is_active: i32,  // SQLite stores as integer
    pub status: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "TEXT", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum DeviceStatus {
    Online,
    Offline,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub api_endpoint: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub api_key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor_agent_path: Option<String>,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_seen: Option<DateTime<Utc>>,
    #[serde(default = "default_is_active")]
    pub is_active: bool,
    #[serde(default)]
    pub status: DeviceStatus,
}

impl From<DeviceRow> for Device {
    fn from(row: DeviceRow) -> Self {
        Device {
            id: row.id,
            name: row.name,
            api_endpoint: row.api_endpoint,
            api_key: row.api_key,
            cursor_agent_path: row.cursor_agent_path,
            created_at: DateTime::parse_from_rfc3339(&row.created_at)
                .map(|dt| dt.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
            last_seen: row.last_seen.and_then(|s| {
                DateTime::parse_from_rfc3339(&s)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc))
            }),
            is_active: row.is_active != 0,
            status: match row.status.as_str() {
                "online" => DeviceStatus::Online,
                "offline" => DeviceStatus::Offline,
                _ => DeviceStatus::Unknown,
            },
        }
    }
}

fn default_is_active() -> bool {
    true
}

impl Default for DeviceStatus {
    fn default() -> Self {
        DeviceStatus::Unknown
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct DeviceCreate {
    #[validate(length(min = 1, max = 100))]
    pub name: String,
    
    #[validate(length(min = 1, max = 512))]
    pub api_endpoint: String,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    #[validate(length(min = 16))]
    pub api_key: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor_agent_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct DeviceUpdate {
    #[serde(skip_serializing_if = "Option::is_none")]
    #[validate(length(min = 1, max = 100))]
    pub name: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    #[validate(length(min = 1, max = 512))]
    pub api_endpoint: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    #[validate(length(min = 16))]
    pub api_key: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor_agent_path: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_active: Option<bool>,
}

// Database representation for RemoteChat
#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct RemoteChatRow {
    pub chat_id: String,
    pub device_id: String,
    pub working_directory: String,
    pub name: String,
    pub created_at: String,  // ISO 8601 string
    pub last_updated_at: Option<String>,  // ISO 8601 string
    pub message_count: i32,
    pub last_message_preview: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteChat {
    pub chat_id: String,
    pub device_id: String,
    pub working_directory: String,
    #[serde(default = "default_name")]
    pub name: String,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_updated_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub message_count: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_message_preview: Option<String>,
}

impl From<RemoteChatRow> for RemoteChat {
    fn from(row: RemoteChatRow) -> Self {
        RemoteChat {
            chat_id: row.chat_id,
            device_id: row.device_id,
            working_directory: row.working_directory,
            name: row.name,
            created_at: DateTime::parse_from_rfc3339(&row.created_at)
                .map(|dt| dt.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
            last_updated_at: row.last_updated_at.and_then(|s| {
                DateTime::parse_from_rfc3339(&s)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc))
            }),
            message_count: row.message_count,
            last_message_preview: row.last_message_preview,
        }
    }
}

fn default_name() -> String {
    "Untitled".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct RemoteChatCreate {
    pub device_id: String,
    
    #[validate(length(min = 1))]
    pub working_directory: String,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ChatLocation {
    Local,
    Remote,
}

