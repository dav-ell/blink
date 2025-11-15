/*!
 * Blink MCP Server - Model Context Protocol server for LLM agent control
 *
 * This MCP server exposes Blink's remote agent functionality to LLM agents
 * running in Cursor IDE. It provides tools for device management, chat creation,
 * and task delegation to remote cursor-agent instances.
 */

use reqwest::Client;
use serde_json::{json, Value};
use std::error::Error;

const API_BASE_URL: &str = "http://localhost:8067";

struct BlinkApiClient {
    client: Client,
    base_url: String,
}

impl BlinkApiClient {
    fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: API_BASE_URL.to_string(),
        }
    }

    async fn get(&self, endpoint: &str) -> Result<Value, Box<dyn Error>> {
        let url = format!("{}{}", self.base_url, endpoint);
        let response = self.client.get(&url).send().await?;
        let json = response.json().await?;
        Ok(json)
    }

    async fn post(&self, endpoint: &str, data: Value) -> Result<Value, Box<dyn Error>> {
        let url = format!("{}{}", self.base_url, endpoint);
        let response = self.client.post(&url).json(&data).send().await?;
        let json = response.json().await?;
        Ok(json)
    }

    // Device Management
    async fn list_devices(&self) -> Result<Vec<Value>, Box<dyn Error>> {
        let result = self.get("/devices").await?;
        let devices = result["devices"]
            .as_array()
            .ok_or("Invalid response: missing devices array")?
            .clone();
        Ok(devices)
    }

    async fn add_device(&self, data: Value) -> Result<Value, Box<dyn Error>> {
        self.post("/devices", data).await
    }

    async fn test_device_connection(&self, device_id: &str) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/devices/{}/test", device_id), json!({}))
            .await
    }

    // Chat Management
    async fn create_remote_chat(
        &self,
        device_id: &str,
        data: Value,
    ) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/devices/{}/create-chat", device_id), data)
            .await
    }

    async fn send_prompt_async(&self, chat_id: &str, data: Value) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/chats/{}/agent-prompt-async", chat_id), data)
            .await
    }

    async fn get_job_status(&self, job_id: &str) -> Result<Value, Box<dyn Error>> {
        self.get(&format!("/jobs/{}", job_id)).await
    }

    async fn wait_for_job(&self, job_id: &str, timeout_secs: u64) -> Result<Value, Box<dyn Error>> {
        let start = std::time::Instant::now();
        loop {
            let job = self.get_job_status(job_id).await?;
            let status = job["status"].as_str().unwrap_or("unknown");

            match status {
                "completed" => return Ok(job),
                "failed" => return Err(format!("Job failed: {:?}", job["error"]).into()),
                "cancelled" => return Err("Job was cancelled".into()),
                _ => {
                    if start.elapsed().as_secs() > timeout_secs {
                        return Err(format!("Job timeout after {} seconds", timeout_secs).into());
                    }
                    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
                }
            }
        }
    }

    // Context Management
    async fn get_chat_messages(
        &self,
        chat_id: &str,
        limit: Option<usize>,
    ) -> Result<Value, Box<dyn Error>> {
        let mut url = format!(
            "/chats/{}?include_metadata=true&include_content=true",
            chat_id
        );
        if let Some(l) = limit {
            url = format!("{}&limit={}", url, l);
        }
        self.get(&url).await
    }

    async fn list_remote_chats(&self) -> Result<Vec<Value>, Box<dyn Error>> {
        let result = self.get("/remote-chats").await?;
        let chats = result["chats"]
            .as_array()
            .ok_or("Invalid response: missing chats array")?
            .clone();
        Ok(chats)
    }
}

// MCP Tool definitions
fn get_tool_definitions() -> Vec<Value> {
    vec![
        json!({
            "name": "list_remote_devices",
            "description": "List all configured remote devices (SSH-accessible machines). Returns device ID, name, hostname, and connection status. Use this to find available devices before creating remote chats.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }),
        json!({
            "name": "add_remote_device",
            "description": "Register a new remote device for SSH-based cursor-agent execution. Requires SSH key authentication to be set up. After adding, use test_device_connection to verify connectivity.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "User-friendly name (e.g., 'GPU Server', 'Production')"
                    },
                    "hostname": {
                        "type": "string",
                        "description": "SSH hostname or IP address (can use SSH config aliases)"
                    },
                    "username": {
                        "type": "string",
                        "description": "SSH username"
                    },
                    "port": {
                        "type": "integer",
                        "description": "SSH port (default 22)",
                        "default": 22
                    },
                    "cursor_agent_path": {
                        "type": "string",
                        "description": "Path to cursor-agent on remote (default: ~/.local/bin/cursor-agent)"
                    }
                },
                "required": ["name", "hostname", "username"]
            }
        }),
        json!({
            "name": "test_device_connection",
            "description": "Test SSH connection to a remote device. Verifies that SSH authentication works and the device is reachable. Returns success status and error details if connection fails.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Device UUID (from list_remote_devices or add_remote_device)"
                    }
                },
                "required": ["device_id"]
            }
        }),
        json!({
            "name": "create_remote_chat",
            "description": "Create a new chat conversation on a remote device. The chat will have access to the specified working directory. Returns chat_id for sending tasks.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Device UUID where chat should be created"
                    },
                    "working_directory": {
                        "type": "string",
                        "description": "Absolute path to working directory on remote device"
                    },
                    "name": {
                        "type": "string",
                        "description": "Optional chat name for organization"
                    }
                },
                "required": ["device_id", "working_directory"]
            }
        }),
        json!({
            "name": "send_remote_task",
            "description": "Delegate a task to a remote cursor-agent. Each call to an existing chat has access to all previous messages - context is automatically maintained by cursor-agent. By default (wait=True), this blocks until the task completes and returns the result. Set wait=False for fire-and-forget. For better multi-turn UX, use get_chat_history first, then continue_conversation.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat)"
                    },
                    "prompt": {
                        "type": "string",
                        "description": "Task description or question for the remote agent"
                    },
                    "model": {
                        "type": "string",
                        "description": "AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-5')"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true)",
                        "default": true
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 300)",
                        "default": 300
                    }
                },
                "required": ["chat_id", "prompt"]
            }
        }),
        json!({
            "name": "get_job_result",
            "description": "Check status and retrieve result of an async job. Use this after send_remote_task with wait=false.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "job_id": {
                        "type": "string",
                        "description": "Job UUID (from send_remote_task)"
                    }
                },
                "required": ["job_id"]
            }
        }),
        json!({
            "name": "get_chat_history",
            "description": "Retrieve conversation history from a chat. Shows all messages exchanged with the remote agent. Use this to understand context before sending follow-up tasks. Works with both remote and local chats.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat or existing chat)"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of messages to retrieve (default: all messages)"
                    }
                },
                "required": ["chat_id"]
            }
        }),
        json!({
            "name": "continue_conversation",
            "description": "Continue an existing conversation by sending a follow-up message. The remote agent has full access to all previous messages in the chat. Context is automatically maintained by cursor-agent. This is semantically clearer than send_remote_task for multi-turn conversations.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chat_id": {
                        "type": "string",
                        "description": "Chat UUID (from create_remote_chat)"
                    },
                    "message": {
                        "type": "string",
                        "description": "Your follow-up message or question"
                    },
                    "model": {
                        "type": "string",
                        "description": "AI model to use (e.g., 'sonnet-4.5-thinking', 'gpt-5')"
                    },
                    "wait": {
                        "type": "boolean",
                        "description": "Wait for completion before returning (default: true)",
                        "default": true
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Maximum seconds to wait if wait=true (default: 300)",
                        "default": 300
                    }
                },
                "required": ["chat_id", "message"]
            }
        }),
        json!({
            "name": "list_remote_chats",
            "description": "List all active remote chat sessions. Shows chat ID, device, working directory, message count, and last activity. Use this to find existing chats before creating new ones.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }),
    ]
}

async fn handle_tool_call(
    client: &BlinkApiClient,
    name: &str,
    arguments: Value,
) -> Result<String, Box<dyn Error>> {
    match name {
        "list_remote_devices" => {
            let devices = client.list_devices().await?;
            if devices.is_empty() {
                return Ok(
                    "No remote devices configured. Use add_remote_device to register a new device."
                        .to_string(),
                );
            }

            let mut output = String::from("📱 **Remote Devices:**\n\n");
            for device in &devices {
                output.push_str(&format!(
                    "• **{}** ({})\n  - Hostname: {}\n  - Status: {}\n  - ID: {}\n\n",
                    device["name"].as_str().unwrap_or("Unknown"),
                    device["username"].as_str().unwrap_or(""),
                    device["hostname"].as_str().unwrap_or(""),
                    device["status"].as_str().unwrap_or("unknown"),
                    device["id"].as_str().unwrap_or("")
                ));
            }
            Ok(output)
        }

        "add_remote_device" => {
            let result = client.add_device(arguments).await?;
            let device = &result["device"];
            Ok(format!(
                "✅ **Device Added Successfully**\n\n\
                 Name: {}\n\
                 ID: {}\n\
                 Hostname: {}\n\n\
                 💡 Next step: Use `test_device_connection` to verify connectivity.",
                device["name"].as_str().unwrap_or("Unknown"),
                device["id"].as_str().unwrap_or(""),
                device["hostname"].as_str().unwrap_or("")
            ))
        }

        "test_device_connection" => {
            let device_id = arguments["device_id"].as_str().ok_or("Missing device_id")?;
            let result = client.test_device_connection(device_id).await?;

            if result["success"].as_bool().unwrap_or(false) {
                Ok(format!(
                    "✅ **Connection Successful**\n\n\
                     Device: {}\n\
                     Status: Online and reachable",
                    result["device_name"].as_str().unwrap_or("Unknown")
                ))
            } else {
                Ok(format!(
                    "❌ **Connection Failed**\n\n\
                     Device: {}\n\
                     Error: {}",
                    result["device_name"].as_str().unwrap_or("Unknown"),
                    result["stderr"].as_str().unwrap_or("Unknown error")
                ))
            }
        }

        "create_remote_chat" => {
            let device_id = arguments["device_id"].as_str().ok_or("Missing device_id")?;
            let result = client
                .create_remote_chat(device_id, arguments.clone())
                .await?;

            Ok(format!(
                "✅ **Remote Chat Created**\n\n\
                 Chat ID: {}\n\
                 Device: {}\n\
                 Working Directory: {}\n\n\
                 💡 Use this chat_id with `send_remote_task` to delegate work.",
                result["chat_id"].as_str().unwrap_or(""),
                result["device_name"].as_str().unwrap_or("Unknown"),
                result["working_directory"].as_str().unwrap_or("")
            ))
        }

        "send_remote_task" => {
            let chat_id = arguments["chat_id"].as_str().ok_or("Missing chat_id")?;
            let wait = arguments["wait"].as_bool().unwrap_or(true);
            let timeout = arguments["timeout"].as_i64().unwrap_or(300) as u64;

            let prompt_data = json!({
                "prompt": arguments["prompt"],
                "model": arguments.get("model")
            });

            let job_result = client.send_prompt_async(chat_id, prompt_data).await?;
            let job_id = job_result["job_id"]
                .as_str()
                .ok_or("Missing job_id in response")?;

            if !wait {
                return Ok(format!(
                    "🚀 **Task Submitted**\n\n\
                     Job ID: {}\n\n\
                     💡 Use `get_job_result` to check status.",
                    job_id
                ));
            }

            // Wait for completion
            let job = client.wait_for_job(job_id, timeout).await?;
            let result = &job["result"];

            Ok(format!(
                "✅ **Task Completed**\n\n\
                 **Agent Response:**\n{}\n\n\
                 Job ID: {}",
                result["content"]["assistant"]
                    .as_str()
                    .unwrap_or("No response"),
                job_id
            ))
        }

        "get_job_result" => {
            let job_id = arguments["job_id"].as_str().ok_or("Missing job_id")?;
            let job = client.get_job_status(job_id).await?;
            let status = job["status"].as_str().unwrap_or("unknown");

            match status {
                "completed" => {
                    let result = &job["result"];
                    Ok(format!(
                        "✅ **Job Completed**\n\n\
                         **Agent Response:**\n{}",
                        result["content"]["assistant"]
                            .as_str()
                            .unwrap_or("No response")
                    ))
                }
                "failed" => Ok(format!(
                    "❌ **Job Failed**\n\n\
                         Error: {}",
                    job["error"].as_str().unwrap_or("Unknown error")
                )),
                "pending" | "processing" => Ok(format!(
                    "⏳ **Job In Progress**\n\n\
                         Status: {}\n\
                         Check again in a few moments.",
                    status
                )),
                _ => Ok(format!("❓ Job status: {}", status)),
            }
        }

        "get_chat_history" => {
            let chat_id = arguments["chat_id"].as_str().ok_or("Missing chat_id")?;
            let limit = arguments
                .get("limit")
                .and_then(|v| v.as_u64())
                .map(|v| v as usize);

            let chat_data = client.get_chat_messages(chat_id, limit).await?;
            let metadata = &chat_data["metadata"];
            let messages = chat_data["messages"]
                .as_array()
                .ok_or("Invalid response: missing messages")?;

            if messages.is_empty() {
                return Ok(format!(
                    "📜 **Chat History: {}**\n\n\
                     No messages yet in this chat.\n\n\
                     💡 Use 'send_remote_task' or 'continue_conversation' to start the conversation.",
                    metadata["name"].as_str().unwrap_or("Untitled")
                ));
            }

            let mut output = format!(
                "📜 **Chat History: {}**\n\
                 Device: {} | Messages: {} | Format: {}\n\n",
                metadata["name"].as_str().unwrap_or("Untitled"),
                metadata
                    .get("device_name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown"),
                chat_data["message_count"].as_u64().unwrap_or(0),
                metadata
                    .get("format")
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown")
            );

            output.push_str("---\n");

            for msg in messages {
                let role = msg["type_label"].as_str().unwrap_or("unknown");
                let text = msg["text"].as_str().unwrap_or("");
                let created_at = msg.get("created_at").and_then(|v| v.as_str()).or_else(|| {
                    msg.get("created_at")
                        .and_then(|v| v.as_i64())
                        .map(|_| "timestamp")
                });

                output.push_str(&format!(
                    "[{}] {}\n{}\n\n",
                    role.chars()
                        .next()
                        .unwrap()
                        .to_uppercase()
                        .collect::<String>()
                        + &role[1..],
                    created_at.unwrap_or(""),
                    text
                ));
            }

            output.push_str(
                "---\n\n💡 Use 'continue_conversation' to add to this chat with full context.",
            );
            Ok(output)
        }

        "continue_conversation" => {
            let chat_id = arguments["chat_id"].as_str().ok_or("Missing chat_id")?;
            let message = arguments["message"].as_str().ok_or("Missing message")?;
            let wait = arguments
                .get("wait")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);
            let timeout = arguments
                .get("timeout")
                .and_then(|v| v.as_i64())
                .unwrap_or(300) as u64;

            let prompt_data = json!({
                "prompt": message,
                "model": arguments.get("model")
            });

            let job_result = client.send_prompt_async(chat_id, prompt_data).await?;
            let job_id = job_result["job_id"]
                .as_str()
                .ok_or("Missing job_id in response")?;

            if !wait {
                return Ok(format!(
                    "🚀 **Message Sent**\n\n\
                     Job ID: {}\n\n\
                     💡 Use `get_job_result` to check status.",
                    job_id
                ));
            }

            // Wait for completion
            let job = client.wait_for_job(job_id, timeout).await?;
            let result = &job["result"];

            Ok(format!(
                "✅ **Response Received**\n\n\
                 **Agent:**\n{}\n\n\
                 Job ID: {}\n\n\
                 💡 Use 'get_chat_history' to see full conversation.",
                result["content"]["assistant"]
                    .as_str()
                    .unwrap_or("No response"),
                job_id
            ))
        }

        "list_remote_chats" => {
            let chats = client.list_remote_chats().await?;

            if chats.is_empty() {
                return Ok("💬 **No Active Remote Chats**\n\n\
                          Use `create_remote_chat` to start a new conversation with a remote agent.".to_string());
            }

            let mut output = String::from("💬 **Active Remote Chats:**\n\n");

            for (idx, chat) in chats.iter().enumerate() {
                output.push_str(&format!(
                    "{}. **{}**\n\
                     - ID: {}\n\
                     - Device: {}\n\
                     - Directory: {}\n\
                     - Messages: {}\n\
                     - Last Active: {}\n\n",
                    idx + 1,
                    chat["name"].as_str().unwrap_or("Untitled"),
                    chat["chat_id"].as_str().unwrap_or(""),
                    chat.get("device_name")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Unknown"),
                    chat["working_directory"].as_str().unwrap_or(""),
                    chat.get("message_count")
                        .and_then(|v| v.as_i64())
                        .unwrap_or(0),
                    chat.get("last_updated_at")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Unknown")
                ));
            }

            output.push_str("💡 Use 'get_chat_history' to see messages or 'continue_conversation' to add to a chat.");
            Ok(output)
        }

        _ => Err(format!("Unknown tool: {}", name).into()),
    }
}

fn send_result_response(result: Value, request_id: &Option<Value>) -> Result<(), Box<dyn Error>> {
    let mut response = json!({
        "jsonrpc": "2.0",
        "result": result,
    });
    response["id"] = request_id.clone().unwrap_or(Value::Null);
    println!("{}", serde_json::to_string(&response)?);
    Ok(())
}

fn send_error_response(
    code: i32,
    message: String,
    data: Option<Value>,
    request_id: &Option<Value>,
) -> Result<(), Box<dyn Error>> {
    let mut error_obj = json!({
        "code": code,
        "message": message,
    });
    if let Some(data_value) = data {
        error_obj["data"] = data_value;
    }

    let mut response = json!({
        "jsonrpc": "2.0",
        "error": error_obj,
    });
    response["id"] = request_id.clone().unwrap_or(Value::Null);
    println!("{}", serde_json::to_string(&response)?);
    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Don't print to stderr - MCP protocol expects clean stderr
    // eprintln!("🚀 Blink MCP Server starting...");

    let client = BlinkApiClient::new();

    // Simple stdio-based MCP protocol implementation
    // In production, you would use a proper MCP library
    let stdin = std::io::stdin();
    let mut line = String::new();

    loop {
        line.clear();
        if stdin.read_line(&mut line)? == 0 {
            break;
        }

        let request: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                let error_response = json!({
                    "jsonrpc": "2.0",
                    "id": null,
                    "error": {
                        "code": -32700,
                        "message": format!("Parse error: {}", e)
                    }
                });
                println!("{}", serde_json::to_string(&error_response).unwrap_or_else(|_| "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Failed to serialize error\"}}".to_string()));
                continue;
            }
        };

        let request_id = request.get("id").cloned();
        let method = match request.get("method").and_then(|m| m.as_str()) {
            Some(m) => m,
            None => {
                send_error_response(
                    -32600,
                    "Invalid request: missing method".to_string(),
                    None,
                    &request_id,
                )?;
                continue;
            }
        };

        match method {
            "tools/list" => {
                let result = json!({
                    "tools": get_tool_definitions()
                });
                send_result_response(result, &request_id)?;
            }

            "tools/call" => {
                let tool_name = request["params"]["name"].as_str().unwrap_or("");
                let arguments = request["params"]["arguments"].clone();

                match handle_tool_call(&client, tool_name, arguments).await {
                    Ok(content) => {
                        let result = json!({
                            "content": [{
                                "type": "text",
                                "text": content
                            }]
                        });
                        send_result_response(result, &request_id)?;
                    }
                    Err(e) => {
                        send_error_response(
                            -32000,
                            "Tool invocation failed".to_string(),
                            Some(json!({
                                "details": format!("{}", e)
                            })),
                            &request_id,
                        )?;
                    }
                }
            }

            _ => {
                send_error_response(
                    -32601,
                    format!("Unknown method: {}", method),
                    None,
                    &request_id,
                )?;
            }
        }
    }

    Ok(())
}
