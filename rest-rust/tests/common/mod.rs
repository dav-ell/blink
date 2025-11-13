use blink_api::{api, AppState, Settings};
use axum::Router;
use sqlx::SqlitePool;
use std::sync::Arc;
use tempfile::NamedTempFile;

/// Create test settings with temporary databases
#[allow(dead_code)]
pub fn create_test_settings() -> Settings {
    let cursor_db = NamedTempFile::new().unwrap();
    let device_db = NamedTempFile::new().unwrap();
    
    Settings {
        db_path: cursor_db.path().to_path_buf(),
        cursor_agent_path: "/usr/local/bin/cursor-agent".into(),
        api_host: "127.0.0.1".to_string(),
        api_port: 8000,
        device_db_path: device_db.path().to_path_buf(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        default_cursor_agent_path: "cursor-agent".to_string(),
        job_cleanup_max_age_hours: 24,
        job_cleanup_interval_minutes: 60,
        cursor_agent_timeout: 600,
        api_reload: false,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    }
}

/// Create and initialize test database with fixtures
pub async fn setup_test_db() -> SqlitePool {
    // Use in-memory database for fast isolated tests
    let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
    
    // Initialize schema
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS jobs (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            prompt TEXT NOT NULL,
            model TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            started_at TEXT,
            completed_at TEXT,
            result TEXT,
            error TEXT
        )
        "#,
    )
    .execute(&pool)
    .await
    .unwrap();
    
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
    .execute(&pool)
    .await
    .unwrap();
    
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS remote_chats (
            chat_id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            working_directory TEXT NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_updated_at TEXT,
            message_count INTEGER NOT NULL DEFAULT 0,
            last_message_preview TEXT,
            FOREIGN KEY (device_id) REFERENCES devices(id)
        )
        "#,
    )
    .execute(&pool)
    .await
    .unwrap();
    
    pool
}

/// Create test Axum app with shared state
pub async fn create_test_app() -> Router {
    let pool = setup_test_db().await;
    
    let temp_dir = tempfile::tempdir().unwrap();
    let settings = Settings {
        db_path: temp_dir.path().join("cursor.db"),
        cursor_agent_path: "/usr/local/bin/cursor-agent".into(),
        api_host: "127.0.0.1".to_string(),
        api_port: 8000,
        device_db_path: temp_dir.path().join("device.db"),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        default_cursor_agent_path: "cursor-agent".to_string(),
        job_cleanup_max_age_hours: 24,
        job_cleanup_interval_minutes: 60,
        cursor_agent_timeout: 600,
        api_reload: false,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };
    
    // Keep temp dir alive during test
    std::mem::forget(temp_dir);
    
    let state = Arc::new(AppState {
        settings,
        job_pool: pool,
    });
    
    Router::new()
        .route("/", axum::routing::get(api::health::root))
        .route("/health", axum::routing::get(api::health::health_check))
        .route("/chats", axum::routing::get(api::chats::list_chats))
        .route("/chats/:chat_id", axum::routing::get(api::chats::get_chat_messages))
        .route("/chats/:chat_id/metadata", axum::routing::get(api::chats::get_chat_metadata))
        .route("/agent/models", axum::routing::get(api::agent::get_models))
        .route("/agent/create-chat", axum::routing::post(api::agent::create_chat))
        .route("/chats/:chat_id/agent-prompt", axum::routing::post(api::agent::send_agent_prompt))
        .route("/chats/:chat_id/agent-prompt-async", axum::routing::post(api::jobs::create_agent_prompt_job))
        .route("/jobs/:job_id", axum::routing::get(api::jobs::get_job_details))
        .route("/jobs/:job_id/status", axum::routing::get(api::jobs::get_job_status))
        .route("/chats/:chat_id/jobs", axum::routing::get(api::jobs::get_chat_jobs_list))
        .route("/devices", axum::routing::post(api::devices::create_device))
        .route("/devices", axum::routing::get(api::devices::list_devices))
        .route("/devices/:device_id", axum::routing::get(api::devices::get_device))
        .route("/devices/:device_id", axum::routing::put(api::devices::update_device))
        .route("/devices/:device_id", axum::routing::delete(api::devices::delete_device))
        .route("/devices/:device_id/test", axum::routing::post(api::devices::test_device_connection))
        .route("/devices/:device_id/verify-agent", axum::routing::post(api::devices::verify_agent_installed))
        .route("/devices/:device_id/create-chat", axum::routing::post(api::devices::create_device_chat))
        .route("/devices/chats/remote", axum::routing::get(api::devices::list_remote_chats))
        .route("/devices/chats/:chat_id/send-prompt", axum::routing::post(api::devices::send_remote_prompt))
        .with_state(state)
}

/// Create sample cursor database with test data
#[allow(dead_code)]
pub fn setup_cursor_db() -> (rusqlite::Connection, tempfile::TempDir) {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("cursor.db");
    let conn = rusqlite::Connection::open(&db_path).unwrap();
    
    // Create schema
    conn.execute(
        "CREATE TABLE itemTable (key TEXT PRIMARY KEY, value TEXT)",
        [],
    )
    .unwrap();
    
    // Insert sample chat data
    let chat_id_1 = "test-chat-1";
    let chat_data_1 = serde_json::json!({
        "id": chat_id_1,
        "name": "Test Chat 1",
        "createdAt": "2024-01-01T00:00:00Z",
        "bubbles": [
            {
                "type": "user",
                "text": "Hello, how are you?",
                "createdAt": "2024-01-01T00:00:00Z"
            },
            {
                "type": "assistant",
                "text": "I'm doing well, thank you!",
                "createdAt": "2024-01-01T00:00:01Z"
            }
        ]
    });
    
    conn.execute(
        "INSERT INTO itemTable (key, value) VALUES (?, ?)",
        [
            &format!("workbench.panel.aichat.view.aichat.chatdata.{}", chat_id_1),
            &chat_data_1.to_string(),
        ],
    )
    .unwrap();
    
    let chat_id_2 = "test-chat-2";
    let chat_data_2 = serde_json::json!({
        "id": chat_id_2,
        "name": "Test Chat 2",
        "createdAt": "2024-01-02T00:00:00Z",
        "bubbles": []
    });
    
    conn.execute(
        "INSERT INTO itemTable (key, value) VALUES (?, ?)",
        [
            &format!("workbench.panel.aichat.view.aichat.chatdata.{}", chat_id_2),
            &chat_data_2.to_string(),
        ],
    )
    .unwrap();
    
    (conn, temp_dir)
}

