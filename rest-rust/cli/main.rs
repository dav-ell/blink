/*!
 * Blink CLI - Command-line interface for LLM agent control
 *  
 * Simple, non-interactive CLI for controlling remote cursor-agent instances.
 * Designed to be easily used by LLM agents operating in terminal environments.
 */

use clap::{Parser, Subcommand};
use reqwest::Client;
use serde_json::{json, Value};
use std::error::Error;

const DEFAULT_API_URL: &str = "http://localhost:8000";

#[derive(Parser)]
#[command(name = "blink")]
#[command(about = "Control remote cursor-agent instances", long_about = None)]
struct Cli {
    /// Blink API base URL (or set BLINK_API_URL env var)
    #[arg(long, default_value = DEFAULT_API_URL)]
    base_url: String,

    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Manage remote devices
    Device {
        #[command(subcommand)]
        command: DeviceCommands,
    },
    /// Manage chats
    Chat {
        #[command(subcommand)]
        command: ChatCommands,
    },
    /// Manage jobs
    Job {
        #[command(subcommand)]
        command: JobCommands,
    },
}

#[derive(Subcommand)]
enum DeviceCommands {
    /// List all configured devices
    List {
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// Add a new remote device
    Add {
        /// User-friendly name
        name: String,
        /// SSH hostname or IP
        hostname: String,
        /// SSH username
        username: String,
        /// SSH port
        #[arg(long, default_value_t = 22)]
        port: u16,
        /// Path to cursor-agent on remote
        #[arg(long)]
        cursor_agent_path: Option<String>,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// Test SSH connection to a device
    Test {
        /// Device ID
        device_id: String,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// Delete a device
    Delete {
        /// Device ID
        device_id: String,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
}

#[derive(Subcommand)]
enum ChatCommands {
    /// Create a new remote chat
    Create {
        /// Device ID
        #[arg(long)]
        device: String,
        /// Working directory on remote
        #[arg(long)]
        dir: String,
        /// Optional chat name
        #[arg(long)]
        name: Option<String>,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// Send a prompt to a chat
    Send {
        /// Chat ID
        chat_id: String,
        /// Prompt text
        prompt: String,
        /// Model to use
        #[arg(long)]
        model: Option<String>,
        /// Wait for completion
        #[arg(long)]
        wait: bool,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// List all chats
    List {
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
}

#[derive(Subcommand)]
enum JobCommands {
    /// Get job status
    Status {
        /// Job ID
        job_id: String,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
    /// Wait for job completion
    Wait {
        /// Job ID
        job_id: String,
        /// Timeout in seconds
        #[arg(long, default_value_t = 300)]
        timeout: u64,
        /// Output JSON
        #[arg(long)]
        json: bool,
    },
}

struct ApiClient {
    client: Client,
    base_url: String,
    verbose: bool,
}

impl ApiClient {
    fn new(base_url: String, verbose: bool) -> Self {
        Self {
            client: Client::new(),
            base_url,
            verbose,
        }
    }

    async fn get(&self, endpoint: &str) -> Result<Value, Box<dyn Error>> {
        let url = format!("{}{}", self.base_url, endpoint);
        if self.verbose {
            eprintln!("GET {}", url);
        }
        let response = self.client.get(&url).send().await?;
        let json = response.json().await?;
        Ok(json)
    }

    async fn post(&self, endpoint: &str, data: Value) -> Result<Value, Box<dyn Error>> {
        let url = format!("{}{}", self.base_url, endpoint);
        if self.verbose {
            eprintln!("POST {}", url);
            eprintln!("Body: {}", serde_json::to_string_pretty(&data)?);
        }
        let response = self.client.post(&url).json(&data).send().await?;
        let json = response.json().await?;
        Ok(json)
    }

    async fn delete(&self, endpoint: &str) -> Result<Value, Box<dyn Error>> {
        let url = format!("{}{}", self.base_url, endpoint);
        if self.verbose {
            eprintln!("DELETE {}", url);
        }
        let response = self.client.delete(&url).send().await?;
        let json = response.json().await?;
        Ok(json)
    }
}

fn print_json(data: &Value) {
    println!("{}", serde_json::to_string_pretty(data).unwrap());
}

async fn handle_device_commands(
    client: &ApiClient,
    command: DeviceCommands,
) -> Result<(), Box<dyn Error>> {
    match command {
        DeviceCommands::List { json: output_json } => {
            let result = client.get("/devices").await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            let devices = result["devices"].as_array()
                .ok_or("Invalid response: missing devices array")?;
            
            if devices.is_empty() {
                println!("No devices configured.");
                println!("\nAdd a device with:");
                println!("  blink device add <name> <hostname> <username>");
                return Ok(());
            }
            
            println!("Found {} device(s):\n", devices.len());
            for device in devices {
                println!("• {}", device["name"].as_str().unwrap_or("Unknown"));
                println!("  ID: {}", device["id"].as_str().unwrap_or(""));
                println!(
                    "  Host: {}@{}:{}",
                    device["username"].as_str().unwrap_or(""),
                    device["hostname"].as_str().unwrap_or(""),
                    device["port"].as_i64().unwrap_or(22)
                );
                let active = if device["is_active"].as_bool().unwrap_or(true) {
                    "Yes"
                } else {
                    "No"
                };
                println!("  Active: {}", active);
                if let Some(last_seen) = device["last_seen"].as_str() {
                    println!("  Last Seen: {}", last_seen);
                }
                println!();
            }
        }

        DeviceCommands::Add {
            name,
            hostname,
            username,
            port,
            cursor_agent_path,
            json: output_json,
        } => {
            let mut data = json!({
                "name": name,
                "hostname": hostname,
                "username": username,
                "port": port
            });
            
            if let Some(path) = cursor_agent_path {
                data["cursor_agent_path"] = json!(path);
            }
            
            let result = client.post("/devices", data).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            let device = &result["device"];
            let device_id = device["id"].as_str().unwrap_or("");
            
            println!("✓ Device '{}' added successfully!", name);
            println!("\nDevice ID: {}", device_id);
            println!("Connection: {}@{}:{}", username, hostname, port);
            println!("\nNext steps:");
            println!("  1. Test connection: blink device test {}", device_id);
            println!("  2. Create chat: blink chat create --device {} --dir /path/to/dir", device_id);
        }

        DeviceCommands::Test {
            device_id,
            json: output_json,
        } => {
            let result = client.post(&format!("/devices/{}/test", device_id), json!({})).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            if result["success"].as_bool().unwrap_or(false) {
                println!("✓ Connection successful!");
                println!("Device is reachable and SSH authentication works.");
            } else {
                println!("✗ Connection failed");
                println!("Error: {}", result["stderr"].as_str().unwrap_or("Unknown error"));
                std::process::exit(1);
            }
        }

        DeviceCommands::Delete {
            device_id,
            json: output_json,
        } => {
            let result = client.delete(&format!("/devices/{}", device_id)).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            println!("✓ Device deleted successfully");
        }
    }
    
    Ok(())
}

async fn handle_chat_commands(
    client: &ApiClient,
    command: ChatCommands,
) -> Result<(), Box<dyn Error>> {
    match command {
        ChatCommands::Create {
            device,
            dir,
            name,
            json: output_json,
        } => {
            let mut data = json!({
                "device_id": device,
                "working_directory": dir
            });
            
            if let Some(chat_name) = name {
                data["name"] = json!(chat_name);
            }
            
            let result = client.post(&format!("/devices/{}/create-chat", device), data).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            println!("✓ Chat created successfully!");
            println!("\nChat ID: {}", result["chat_id"].as_str().unwrap_or(""));
            println!("Device: {}", result["device_name"].as_str().unwrap_or("Unknown"));
            println!("Working Directory: {}", result["working_directory"].as_str().unwrap_or(""));
            println!("\nSend a task with:");
            println!("  blink chat send {} \"<your prompt>\"", result["chat_id"].as_str().unwrap_or(""));
        }

        ChatCommands::Send {
            chat_id,
            prompt,
            model,
            wait,
            json: output_json,
        } => {
            let mut data = json!({
                "prompt": prompt
            });
            
            if let Some(m) = model {
                data["model"] = json!(m);
            }
            
            let endpoint = if wait {
                format!("/chats/{}/agent-prompt", chat_id)
            } else {
                format!("/chats/{}/agent-prompt-async", chat_id)
            };
            
            let result = client.post(&endpoint, data).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            if wait {
                println!("✓ Task completed\n");
                println!("Response:");
                if let Some(content) = result["content"]["assistant"].as_str() {
                    println!("{}", content);
                }
            } else {
                println!("✓ Task submitted");
                println!("Job ID: {}", result["job_id"].as_str().unwrap_or(""));
                println!("\nCheck status with:");
                println!("  blink job status {}", result["job_id"].as_str().unwrap_or(""));
            }
        }

        ChatCommands::List {
            json: output_json,
        } => {
            let result = client.get("/chats?limit=50").await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            let chats = result["chats"].as_array()
                .ok_or("Invalid response: missing chats array")?;
            
            if chats.is_empty() {
                println!("No chats found.");
                return Ok(());
            }
            
            println!("Found {} chat(s):\n", chats.len());
            for chat in chats {
                println!("• Chat ID: {}", chat["chat_id"].as_str().unwrap_or(""));
                if let Some(name) = chat["name"].as_str() {
                    println!("  Name: {}", name);
                }
                println!();
            }
        }
    }
    
    Ok(())
}

async fn handle_job_commands(
    client: &ApiClient,
    command: JobCommands,
) -> Result<(), Box<dyn Error>> {
    match command {
        JobCommands::Status {
            job_id,
            json: output_json,
        } => {
            let result = client.get(&format!("/jobs/{}", job_id)).await?;
            
            if output_json {
                print_json(&result);
                return Ok(());
            }
            
            let status = result["status"].as_str().unwrap_or("unknown");
            println!("Job Status: {}", status);
            
            match status {
                "completed" => {
                    println!("\nResult:");
                    if let Some(content) = result["result"]["content"]["assistant"].as_str() {
                        println!("{}", content);
                    }
                }
                "failed" => {
                    println!("\nError: {}", result["error"].as_str().unwrap_or("Unknown error"));
                }
                "pending" | "processing" => {
                    println!("\nJob is still in progress...");
                }
                _ => {}
            }
        }

        JobCommands::Wait {
            job_id,
            timeout,
            json: output_json,
        } => {
            let start = std::time::Instant::now();
            
            loop {
                let result = client.get(&format!("/jobs/{}", job_id)).await?;
                let status = result["status"].as_str().unwrap_or("unknown");
                
                match status {
                    "completed" => {
                        if output_json {
                            print_json(&result);
                        } else {
                            println!("✓ Job completed\n");
                            println!("Result:");
                            if let Some(content) = result["result"]["content"]["assistant"].as_str() {
                                println!("{}", content);
                            }
                        }
                        return Ok(());
                    }
                    "failed" => {
                        if output_json {
                            print_json(&result);
                        } else {
                            eprintln!("✗ Job failed");
                            eprintln!("Error: {}", result["error"].as_str().unwrap_or("Unknown error"));
                        }
                        std::process::exit(1);
                    }
                    "cancelled" => {
                        eprintln!("Job was cancelled");
                        std::process::exit(1);
                    }
                    _ => {
                        if start.elapsed().as_secs() > timeout {
                            eprintln!("✗ Timeout waiting for job completion");
                            std::process::exit(1);
                        }
                        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
                    }
                }
            }
        }
    }
    
    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let cli = Cli::parse();
    
    let client = ApiClient::new(cli.base_url, cli.verbose);
    
    match cli.command {
        Commands::Device { command } => {
            handle_device_commands(&client, command).await?;
        }
        Commands::Chat { command } => {
            handle_chat_commands(&client, command).await?;
        }
        Commands::Job { command } => {
            handle_job_commands(&client, command).await?;
        }
    }
    
    Ok(())
}
