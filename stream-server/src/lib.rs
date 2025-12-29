//! Blink Stream Server - macOS window streaming via WebRTC
//!
//! This crate provides a WebSocket/WebRTC server for streaming macOS windows
//! to iOS/Flutter clients.

pub mod capture;
pub mod config;
pub mod input;
pub mod server;
pub mod webrtc_handler;

pub use config::Config;
pub use server::Server;

