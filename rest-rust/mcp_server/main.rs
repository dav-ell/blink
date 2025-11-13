/*!
 * Blink MCP Server - Model Context Protocol server for LLM agent control
 * 
 * This MCP server exposes Blink's remote agent functionality to LLM agents
 * running in Cursor IDE. It provides tools for device management, chat creation,
 * and task delegation to remote cursor-agent instances.
 */

use serde_json::{json, Value};
use std::error::Error;
use reqwest::Client;

const API_BASE_URL: &str = "http://localhost:8000";

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
        let devices = result["devices"].as_array()
            .ok_or("Invalid response: missing devices array")?
            .clone();
        Ok(devices)
    }

    async fn add_device(&self, data: Value) -> Result<Value, Box<dyn Error>> {
        self.post("/devices", data).await
    }

    async fn test_device_connection(&self, device_id: &str) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/devices/{}/test", device_id), json!({})).await
    }

    // Chat Management
    async fn create_remote_chat(&self, device_id: &str, data: Value) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/devices/{}/create-chat", device_id), data).await
    }

    async fn send_prompt_async(&self, chat_id: &str, data: Value) -> Result<Value, Box<dyn Error>> {
        self.post(&format!("/chats/{}/agent-prompt-async", chat_id), data).await
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
            "description": "Delegate a task to a remote cursor-agent. By default (wait=True), this blocks until the task completes and returns the result. Set wait=False for fire-and-forget.",
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
                return Ok("No remote devices configured. Use add_remote_device to register a new device.".to_string());
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
            let device_id = arguments["device_id"].as_str()
                .ok_or("Missing device_id")?;
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
            let device_id = arguments["device_id"].as_str()
                .ok_or("Missing device_id")?;
            let result = client.create_remote_chat(device_id, arguments.clone()).await?;
            
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
            let chat_id = arguments["chat_id"].as_str()
                .ok_or("Missing chat_id")?;
            let wait = arguments["wait"].as_bool().unwrap_or(true);
            let timeout = arguments["timeout"].as_i64().unwrap_or(300) as u64;
            
            let prompt_data = json!({
                "prompt": arguments["prompt"],
                "model": arguments.get("model")
            });
            
            let job_result = client.send_prompt_async(chat_id, prompt_data).await?;
            let job_id = job_result["job_id"].as_str()
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
                result["content"]["assistant"].as_str().unwrap_or("No response"),
                job_id
            ))
        }

        "get_job_result" => {
            let job_id = arguments["job_id"].as_str()
                .ok_or("Missing job_id")?;
            let job = client.get_job_status(job_id).await?;
            let status = job["status"].as_str().unwrap_or("unknown");
            
            match status {
                "completed" => {
                    let result = &job["result"];
                    Ok(format!(
                        "✅ **Job Completed**\n\n\
                         **Agent Response:**\n{}",
                        result["content"]["assistant"].as_str().unwrap_or("No response")
                    ))
                }
                "failed" => {
                    Ok(format!(
                        "❌ **Job Failed**\n\n\
                         Error: {}",
                        job["error"].as_str().unwrap_or("Unknown error")
                    ))
                }
                "pending" | "processing" => {
                    Ok(format!(
                        "⏳ **Job In Progress**\n\n\
                         Status: {}\n\
                         Check again in a few moments.",
                        status
                    ))
                }
                _ => {
                    Ok(format!("❓ Job status: {}", status))
                }
            }
        }

        _ => Err(format!("Unknown tool: {}", name).into()),
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    eprintln!("🚀 Blink MCP Server starting...");
    
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
                eprintln!("Failed to parse request: {}", e);
                continue;
            }
        };
        
        let method = request["method"].as_str().unwrap_or("");
        
        match method {
            "tools/list" => {
                let response = json!({
                    "tools": get_tool_definitions()
                });
                println!("{}", serde_json::to_string(&response)?);
            }
            
            "tools/call" => {
                let tool_name = request["params"]["name"].as_str().unwrap_or("");
                let arguments = request["params"]["arguments"].clone();
                
                match handle_tool_call(&client, tool_name, arguments).await {
                    Ok(content) => {
                        let response = json!({
                            "content": [{
                                "type": "text",
                                "text": content
                            }]
                        });
                        println!("{}", serde_json::to_string(&response)?);
                    }
                    Err(e) => {
                        let response = json!({
                            "content": [{
                                "type": "text",
                                "text": format!("Error: {}", e)
                            }],
                            "isError": true
                        });
                        println!("{}", serde_json::to_string(&response)?);
                    }
                }
            }
            
            _ => {
                eprintln!("Unknown method: {}", method);
            }
        }
    }
    
    Ok(())
}
