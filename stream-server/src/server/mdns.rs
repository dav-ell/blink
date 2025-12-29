//! mDNS service advertisement for Bonjour discovery

use anyhow::Result;
use mdns_sd::{ServiceDaemon, ServiceInfo};
use tracing::info;

/// Handle to the mDNS service daemon
pub struct MdnsHandle {
    daemon: ServiceDaemon,
    service_fullname: String,
}

impl Drop for MdnsHandle {
    fn drop(&mut self) {
        if let Err(e) = self.daemon.unregister(&self.service_fullname) {
            tracing::warn!("Failed to unregister mDNS service: {}", e);
        }
    }
}

/// Advertise the Blink stream server via mDNS/Bonjour
///
/// This allows iOS clients to discover the server on the local network
/// without needing to know its IP address.
pub fn advertise_service(port: u16, server_name: &str) -> Result<MdnsHandle> {
    let daemon = ServiceDaemon::new()?;

    let service_type = "_blink._tcp.local.";
    let instance_name = "Blink Stream Server";

    // Get the hostname for the service
    let hostname = hostname::get()
        .ok()
        .and_then(|h| h.into_string().ok())
        .unwrap_or_else(|| "localhost".to_string());

    let host_full = format!("{}.local.", hostname);

    // Create TXT records with metadata
    let properties = [("version", "1"), ("name", server_name)];

    let service_info = ServiceInfo::new(
        service_type,
        instance_name,
        &host_full,
        "",
        port,
        &properties[..],
    )?;

    let service_fullname = service_info.get_fullname().to_string();

    daemon.register(service_info)?;

    info!(
        "mDNS: Registered {} on {}:{}",
        service_fullname, host_full, port
    );

    Ok(MdnsHandle {
        daemon,
        service_fullname,
    })
}


