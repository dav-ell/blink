use crate::models::device::{DeviceCreate, DeviceStatus};
use crate::{Result, AppError};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::path::Path;
use std::time::Duration;

/// Configuration for a remote host
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteHostConfig {
    pub name: String,
    pub hostname: String,
    pub ip: String,
    pub port: u16,
    pub username: String,
    pub cursor_agent_path: String,
}

/// Root configuration structure
#[derive(Debug, Deserialize)]
struct HostsConfig {
    hosts: Vec<RemoteHostConfig>,
}

/// Health check response from remote agent
#[derive(Debug, Deserialize)]
struct HealthResponse {
    status: String,
    version: Option<String>,
    cursor_agent_path: Option<String>,
}

/// Result of discovering a single host
#[derive(Debug)]
pub struct DiscoveryResult {
    pub name: String,
    pub status: DiscoveryStatus,
    pub message: String,
}

#[derive(Debug, PartialEq)]
pub enum DiscoveryStatus {
    Success,
    AlreadyExists,
    Unreachable,
    Error,
}

/// Load remote hosts configuration from YAML file
pub fn load_hosts_config<P: AsRef<Path>>(path: P) -> Result<Vec<RemoteHostConfig>> {
    let file_path = path.as_ref();
    
    if !file_path.exists() {
        tracing::warn!("Remote hosts config file not found: {:?}", file_path);
        return Ok(Vec::new());
    }
    
    let contents = std::fs::read_to_string(file_path)
        .map_err(|e| AppError::Internal(format!("Failed to read hosts config: {}", e)))?;
    
    let config: HostsConfig = serde_yaml::from_str(&contents)
        .map_err(|e| AppError::Internal(format!("Failed to parse hosts config: {}", e)))?;
    
    Ok(config.hosts)
}

/// Check if a device with the same endpoint already exists
async fn device_exists_by_endpoint(pool: &SqlitePool, endpoint: &str) -> Result<bool> {
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM devices WHERE api_endpoint = ? AND is_active = 1"
    )
    .bind(endpoint)
    .fetch_one(pool)
    .await?;
    
    Ok(count > 0)
}

/// Get device ID by endpoint
async fn get_device_id_by_endpoint(pool: &SqlitePool, endpoint: &str) -> Result<String> {
    let device_id: String = sqlx::query_scalar(
        "SELECT id FROM devices WHERE api_endpoint = ? AND is_active = 1"
    )
    .bind(endpoint)
    .fetch_one(pool)
    .await?;
    
    Ok(device_id)
}

/// Probe remote host health endpoint
async fn probe_health(client: &Client, ip: &str, port: u16) -> Result<HealthResponse> {
    let url = format!("http://{}:{}/health", ip, port);
    
    let response = client
        .get(&url)
        .timeout(Duration::from_secs(5))
        .send()
        .await
        .map_err(|e| AppError::Http(format!("Failed to connect to {}: {}", url, e)))?;
    
    if !response.status().is_success() {
        return Err(AppError::Http(format!(
            "Health check failed with status: {}",
            response.status()
        )));
    }
    
    let health: HealthResponse = response
        .json()
        .await
        .map_err(|e| AppError::Http(format!("Failed to parse health response: {}", e)))?;
    
    Ok(health)
}

/// Try to read API key from deployment keys file
fn read_api_key_for_host(hostname: &str) -> Option<String> {
    let keys_file = std::env::current_dir()
        .ok()?
        .parent()?
        .join(".remote_api_keys.json");
    
    if !keys_file.exists() {
        return None;
    }
    
    let contents = std::fs::read_to_string(&keys_file).ok()?;
    let keys: serde_json::Value = serde_json::from_str(&contents).ok()?;
    
    keys.get(hostname)
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

/// Discover and register a single remote host
async fn discover_host(
    pool: &SqlitePool,
    client: &Client,
    host: &RemoteHostConfig,
) -> DiscoveryResult {
    let endpoint = format!("http://{}:{}", host.ip, host.port);
    
    // Check if device already exists
    let device_exists = match device_exists_by_endpoint(pool, &endpoint).await {
        Ok(exists) => exists,
        Err(e) => {
            tracing::error!("Database error checking for device: {}", e);
            return DiscoveryResult {
                name: host.name.clone(),
                status: DiscoveryStatus::Error,
                message: format!("Database error: {}", e),
            };
        }
    };
    
    // Probe health endpoint
    match probe_health(client, &host.ip, host.port).await {
        Ok(health) => {
            tracing::info!(
                "Health check succeeded for {}: status={}, version={:?}",
                host.name,
                health.status,
                health.version
            );
            
            if device_exists {
                // Device already exists, just update its status to online
                if let Ok(device_id) = get_device_id_by_endpoint(pool, &endpoint).await {
                    if let Err(e) = crate::services::update_device_status(
                        pool,
                        &device_id,
                        DeviceStatus::Online,
                    )
                    .await
                    {
                        tracing::warn!("Failed to update device status for {}: {}", host.name, e);
                    } else {
                        tracing::info!("Updated status to online for device: {} ({})", host.name, endpoint);
                    }
                }
                
                return DiscoveryResult {
                    name: host.name.clone(),
                    status: DiscoveryStatus::AlreadyExists,
                    message: format!("Already registered at {}", endpoint),
                };
            }
            
            // Try to get API key from deployment keys file
            let api_key = read_api_key_for_host(&host.hostname);
            
            if api_key.is_none() {
                tracing::warn!(
                    "No API key found for {} in .remote_api_keys.json",
                    host.hostname
                );
            }
            
            // Create new device
            let device_create = DeviceCreate {
                name: host.name.clone(),
                api_endpoint: endpoint.clone(),
                api_key,
                cursor_agent_path: Some(host.cursor_agent_path.clone()),
            };
            
            match crate::services::create_device(pool, device_create).await {
                Ok(device) => {
                    tracing::info!("Successfully registered device: {} ({})", device.name, device.id);
                    
                    // Update status to online
                    if let Err(e) = crate::services::update_device_status(
                        pool,
                        &device.id,
                        DeviceStatus::Online,
                    )
                    .await
                    {
                        tracing::warn!("Failed to update device status: {}", e);
                    }
                    
                    DiscoveryResult {
                        name: host.name.clone(),
                        status: DiscoveryStatus::Success,
                        message: format!("Registered at {} (id: {})", endpoint, device.id),
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to create device {}: {}", host.name, e);
                    DiscoveryResult {
                        name: host.name.clone(),
                        status: DiscoveryStatus::Error,
                        message: format!("Failed to register: {}", e),
                    }
                }
            }
        }
        Err(e) => {
            tracing::warn!("Health check failed for {} ({}): {}", host.name, endpoint, e);
            DiscoveryResult {
                name: host.name.clone(),
                status: DiscoveryStatus::Unreachable,
                message: format!("Unreachable: {}", e),
            }
        }
    }
}

/// Discover all remote hosts from configuration file
pub async fn discover_remote_hosts(pool: &SqlitePool, config_path: &Path) -> Vec<DiscoveryResult> {
    tracing::info!("Starting remote host discovery...");
    
    // Load configuration
    let hosts = match load_hosts_config(config_path) {
        Ok(hosts) if !hosts.is_empty() => hosts,
        Ok(_) => {
            tracing::info!("No hosts configured in {}", config_path.display());
            return Vec::new();
        }
        Err(e) => {
            tracing::error!("Failed to load hosts config: {}", e);
            return Vec::new();
        }
    };
    
    tracing::info!("Found {} host(s) in configuration", hosts.len());
    
    // Create HTTP client
    let client = Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .expect("Failed to create HTTP client");
    
    // Discover each host
    let mut results = Vec::new();
    for host in hosts {
        let result = discover_host(pool, &client, &host).await;
        results.push(result);
    }
    
    // Log summary
    let success_count = results
        .iter()
        .filter(|r| r.status == DiscoveryStatus::Success)
        .count();
    let already_exists_count = results
        .iter()
        .filter(|r| r.status == DiscoveryStatus::AlreadyExists)
        .count();
    let unreachable_count = results
        .iter()
        .filter(|r| r.status == DiscoveryStatus::Unreachable)
        .count();
    let error_count = results
        .iter()
        .filter(|r| r.status == DiscoveryStatus::Error)
        .count();
    
    tracing::info!(
        "Discovery complete: {} new, {} existing, {} unreachable, {} errors",
        success_count,
        already_exists_count,
        unreachable_count,
        error_count
    );
    
    results
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_load_hosts_config_missing_file() {
        let result = load_hosts_config("/nonexistent/path.yaml");
        assert!(result.is_ok());
        assert_eq!(result.unwrap().len(), 0);
    }
}

