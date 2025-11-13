use crate::{
    models::device::{Device, DeviceCreate, DeviceStatus, DeviceUpdate, RemoteChat, RemoteChatCreate},
    services, AppError, AppState, Result,
};
use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::Arc;

#[derive(Deserialize)]
pub struct ListDevicesQuery {
    #[serde(default)]
    include_inactive: bool,
}


#[derive(Deserialize)]
pub struct RemoteChatListQuery {
    device_id: Option<String>,
}

/// POST /devices - Create a new device
pub async fn create_device(
    State(state): State<Arc<AppState>>,
    Json(device_create): Json<DeviceCreate>,
) -> Result<Json<Value>> {
    let device = services::create_device(&state.job_pool, device_create).await?;
    
    Ok(Json(json!({
        "status": "success",
        "device": device
    })))
}

/// GET /devices - List all devices
pub async fn list_devices(
    State(state): State<Arc<AppState>>,
    Query(query): Query<ListDevicesQuery>,
) -> Result<Json<Value>> {
    let mut devices = services::get_all_devices(&state.job_pool).await?;
    
    // Filter inactive devices if requested
    if !query.include_inactive {
        devices.retain(|d| d.is_active);
    }
    
    Ok(Json(json!({
        "total": devices.len(),
        "devices": devices
    })))
}

/// GET /devices/:id - Get device details
pub async fn get_device(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
) -> Result<Json<Device>> {
    let device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    Ok(Json(device))
}

/// PUT /devices/:id - Update device
pub async fn update_device(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
    Json(update): Json<DeviceUpdate>,
) -> Result<Json<Value>> {
    // Get existing device
    let mut device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    // Apply updates
    if let Some(name) = update.name {
        device.name = name;
    }
    if let Some(api_endpoint) = update.api_endpoint {
        device.api_endpoint = api_endpoint;
    }
    if update.api_key.is_some() {
        device.api_key = update.api_key;
    }
    if update.cursor_agent_path.is_some() {
        device.cursor_agent_path = update.cursor_agent_path;
    }
    
    // Update in database
    sqlx::query(
        r#"
        UPDATE devices 
        SET name = ?, api_endpoint = ?, api_key = ?, cursor_agent_path = ?
        WHERE id = ?
        "#,
    )
    .bind(&device.name)
    .bind(&device.api_endpoint)
    .bind(device.api_key.as_deref())
    .bind(device.cursor_agent_path.as_deref())
    .bind(&device_id)
    .execute(&state.job_pool)
    .await?;
    
    Ok(Json(json!({
        "status": "success",
        "device": device
    })))
}

/// DELETE /devices/:id - Delete device
pub async fn delete_device(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
) -> Result<Json<Value>> {
    // Check if device exists
    let _device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    services::delete_device(&state.job_pool, &device_id).await?;
    
    Ok(Json(json!({
        "status": "success",
        "message": "Device deleted successfully"
    })))
}

/// POST /devices/:id/test - Test HTTP connection to remote agent
pub async fn test_device_connection(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
) -> Result<Json<Value>> {
    let device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    let response = services::test_http_connection(&device, state.settings.remote_agent_connect_timeout).await?;
    
    // Update device status
    if response.success {
        services::update_device_last_seen(&state.job_pool, &device_id).await?;
    } else {
        services::update_device_status(
            &state.job_pool,
            &device_id,
            DeviceStatus::Offline,
        )
        .await?;
    }
    
    Ok(Json(json!({
        "success": response.success,
        "returncode": response.returncode,
        "stdout": response.stdout,
        "stderr": response.stderr,
        "device_id": response.device_id,
        "device_name": response.device_name
    })))
}

/// POST /devices/:id/verify-agent - Verify remote agent service is running
pub async fn verify_agent_installed(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
) -> Result<Json<Value>> {
    let device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    let response = services::test_http_connection(
        &device,
        state.settings.remote_agent_connect_timeout,
    )
    .await?;
    
    Ok(Json(json!({
        "installed": response.success,
        "success": response.success,
        "stdout": response.stdout,
        "stderr": response.stderr,
        "version": response.stdout.lines().next().unwrap_or("unknown"),
    })))
}

/// POST /devices/:id/create-chat - Create remote chat
pub async fn create_device_chat(
    State(state): State<Arc<AppState>>,
    Path(device_id): Path<String>,
    Json(mut chat_create): Json<RemoteChatCreate>,
) -> Result<Json<Value>> {
    // Get device
    let device = services::get_device(&state.job_pool, &device_id)
        .await?
        .ok_or(AppError::NotFound(format!("Device not found: {}", device_id)))?;
    
    // Set device_id on the create request
    chat_create.device_id = device_id.clone();
    
    // Create chat via SSH on remote device
    let chat_id = uuid::Uuid::new_v4().to_string();
    
    // Store remote chat association
    let remote_chat = services::create_remote_chat(&state.job_pool, chat_create).await?;
    
    // Update device last_seen
    services::update_device_last_seen(&state.job_pool, &device_id).await?;
    
    tracing::info!(
        "Created remote chat {} on device {} ({})",
        chat_id,
        device.name,
        device_id
    );
    
    Ok(Json(json!({
        "status": "success",
        "chat_id": chat_id,
        "device_id": remote_chat.device_id,
        "device_name": device.name,
        "working_directory": remote_chat.working_directory,
        "name": remote_chat.name
    })))
}

/// GET /devices/chats/remote - List remote chats
pub async fn list_remote_chats(
    State(state): State<Arc<AppState>>,
    Query(query): Query<RemoteChatListQuery>,
) -> Result<Json<Value>> {
    let chats: Vec<RemoteChat> = if let Some(device_id) = query.device_id {
        sqlx::query_as::<_, crate::models::device::RemoteChatRow>(
            "SELECT * FROM remote_chats WHERE device_id = ? ORDER BY created_at DESC",
        )
        .bind(&device_id)
        .fetch_all(&state.job_pool)
        .await?
        .into_iter()
        .map(Into::into)
        .collect()
    } else {
        sqlx::query_as::<_, crate::models::device::RemoteChatRow>(
            "SELECT * FROM remote_chats ORDER BY created_at DESC",
        )
        .fetch_all(&state.job_pool)
        .await?
        .into_iter()
        .map(Into::into)
        .collect()
    };
    
    // Enrich with device information
    let mut chat_list = Vec::new();
    for chat in chats {
        let device = services::get_device(&state.job_pool, &chat.device_id).await?;
        let mut chat_json = serde_json::to_value(&chat)?;
        if let Some(obj) = chat_json.as_object_mut() {
            obj.insert(
                "device_name".to_string(),
                json!(device.as_ref().map(|d| d.name.as_str()).unwrap_or("Unknown")),
            );
            obj.insert(
                "device_status".to_string(),
                json!(device
                    .as_ref()
                    .map(|d| match d.status {
                        DeviceStatus::Online => "online",
                        DeviceStatus::Offline => "offline",
                        DeviceStatus::Unknown => "unknown",
                    })
                    .unwrap_or("unknown")),
            );
        }
        chat_list.push(chat_json);
    }
    
    Ok(Json(json!({
        "total": chat_list.len(),
        "chats": chat_list
    })))
}

/// POST /devices/chats/:chat_id/send-prompt - Send prompt to remote chat via HTTP
pub async fn send_remote_prompt(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
    Json(request): Json<crate::models::request::AgentPromptRequest>,
) -> Result<Json<Value>> {
    // Get remote chat
    let remote_chat = services::get_remote_chat(&state.job_pool, &chat_id)
        .await?
        .ok_or(AppError::NotFound(format!("Remote chat not found: {}", chat_id)))?;
    
    // Get device
    let device = services::get_device(&state.job_pool, &remote_chat.device_id)
        .await?
        .ok_or(AppError::NotFound(format!(
            "Device not found: {}",
            remote_chat.device_id
        )))?;
    
    // Execute cursor-agent remotely via HTTP
    let model_str = if !request.model.is_empty() {
        Some(request.model.as_str())
    } else {
        None
    };
    
    let response = services::execute_remote_cursor_agent(
        &state.settings,
        &device,
        &chat_id,
        &request.prompt,
        &remote_chat.working_directory,
        model_str,
        "stream-json",
    )
    .await?;
    
    if !response.success {
        return Err(AppError::CursorAgent(format!(
            "Failed to execute remote command: {}",
            response.stderr
        )));
    }
    
    // Parse the agent output
    let parsed_output = crate::utils::parse_cursor_agent_output(&response.stdout)
        .map_err(|e| AppError::Internal(format!("Failed to parse agent output: {}", e)))?;
    
    // Create a simple output structure for response
    let output_text = parsed_output.text.clone();
    let output_thinking = parsed_output.thinking.clone();
    
    // Update remote chat metadata with text preview
    let preview = if output_text.len() > 200 {
        Some(&output_text[..200])
    } else {
        Some(output_text.as_str())
    };
    services::update_remote_chat_metadata(&state.job_pool, &chat_id, preview).await?;
    
    // Update device last_seen
    services::update_device_last_seen(&state.job_pool, &remote_chat.device_id).await?;
    
    Ok(Json(json!({
        "chat_id": chat_id,
        "device_id": device.id,
        "device_name": device.name,
        "working_directory": remote_chat.working_directory,
        "output": {
            "text": output_text,
            "thinking": output_thinking,
            "tool_calls": parsed_output.tool_calls
        },
        "success": true
    })))
}
