/// Test utilities for remote agent service
use std::env;

/// Set up test environment with temporary API key
pub fn setup_test_env(api_key: &str) {
    env::set_var("API_KEY", api_key);
    env::set_var("HOST", "127.0.0.1");
    env::set_var("PORT", "0"); // Random port
    env::set_var("CURSOR_AGENT_PATH", "/usr/bin/true"); // Use `true` command for testing
    env::set_var("EXECUTION_TIMEOUT", "10");
}

/// Clean up test environment
pub fn cleanup_test_env() {
    env::remove_var("API_KEY");
    env::remove_var("HOST");
    env::remove_var("PORT");
    env::remove_var("CURSOR_AGENT_PATH");
    env::remove_var("EXECUTION_TIMEOUT");
}

/// Generate a valid test API key
pub fn valid_api_key() -> String {
    "a".repeat(32)
}

/// Generate an invalid (too short) API key
pub fn invalid_short_api_key() -> String {
    "short".to_string()
}

