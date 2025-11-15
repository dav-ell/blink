use chrono::Utc;
use sqlx::SqlitePool;
use uuid::Uuid;

/// Insert test devices into database
#[allow(dead_code)]
pub async fn insert_test_devices(pool: &SqlitePool) -> Vec<String> {
    let device_id_1 = Uuid::new_v4().to_string();
    let device_id_2 = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();

    sqlx::query(
        "INSERT INTO devices (id, name, hostname, username, port, created_at, status) 
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&device_id_1)
    .bind("Test Device 1")
    .bind("test1.example.com")
    .bind("testuser")
    .bind(22)
    .bind(&now)
    .bind("unknown")
    .execute(pool)
    .await
    .unwrap();

    sqlx::query(
        "INSERT INTO devices (id, name, hostname, username, port, created_at, status) 
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&device_id_2)
    .bind("Test Device 2")
    .bind("test2.example.com")
    .bind("testuser")
    .bind(2222)
    .bind(&now)
    .bind("online")
    .execute(pool)
    .await
    .unwrap();

    vec![device_id_1, device_id_2]
}

/// Insert test jobs into database
#[allow(dead_code)]
pub async fn insert_test_jobs(pool: &SqlitePool, chat_id: &str) -> Vec<String> {
    let job_id_1 = Uuid::new_v4().to_string();
    let job_id_2 = Uuid::new_v4().to_string();
    let job_id_3 = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();

    // Pending job
    sqlx::query(
        "INSERT INTO jobs (id, chat_id, prompt, model, status, created_at) 
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&job_id_1)
    .bind(chat_id)
    .bind("Test prompt 1")
    .bind("sonnet-4.5-thinking")
    .bind("pending")
    .bind(&now)
    .execute(pool)
    .await
    .unwrap();

    // Processing job
    sqlx::query(
        "INSERT INTO jobs (id, chat_id, prompt, model, status, created_at, started_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&job_id_2)
    .bind(chat_id)
    .bind("Test prompt 2")
    .bind("sonnet-4.5-thinking")
    .bind("processing")
    .bind(&now)
    .bind(&now)
    .execute(pool)
    .await
    .unwrap();

    // Completed job
    let result = serde_json::json!({
        "content": {
            "assistant": "Test response"
        }
    });

    sqlx::query(
        "INSERT INTO jobs (id, chat_id, prompt, model, status, created_at, started_at, completed_at, result) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    )
    .bind(&job_id_3)
    .bind(chat_id)
    .bind("Test prompt 3")
    .bind("sonnet-4.5-thinking")
    .bind("completed")
    .bind(&now)
    .bind(&now)
    .bind(&now)
    .bind(result.to_string())
    .execute(pool)
    .await
    .unwrap();

    vec![job_id_1, job_id_2, job_id_3]
}

/// Insert test remote chats
#[allow(dead_code)]
pub async fn insert_test_remote_chats(pool: &SqlitePool, device_id: &str) -> Vec<String> {
    let chat_id_1 = Uuid::new_v4().to_string();
    let chat_id_2 = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();

    sqlx::query(
        "INSERT INTO remote_chats (chat_id, device_id, working_directory, name, created_at) 
         VALUES (?, ?, ?, ?, ?)",
    )
    .bind(&chat_id_1)
    .bind(device_id)
    .bind("/opt/project1")
    .bind("Test Remote Chat 1")
    .bind(&now)
    .execute(pool)
    .await
    .unwrap();

    sqlx::query(
        "INSERT INTO remote_chats (chat_id, device_id, working_directory, name, created_at) 
         VALUES (?, ?, ?, ?, ?)",
    )
    .bind(&chat_id_2)
    .bind(device_id)
    .bind("/opt/project2")
    .bind("Test Remote Chat 2")
    .bind(&now)
    .execute(pool)
    .await
    .unwrap();

    vec![chat_id_1, chat_id_2]
}
