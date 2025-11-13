mod common;

use remote_agent_service::config::Config;
use std::env;

#[test]
fn test_config_from_env_valid() {
    common::cleanup_test_env(); // Clean first
    common::setup_test_env(&common::valid_api_key());
    
    let config = Config::from_env();
    assert!(config.is_ok());
    
    let config = config.unwrap();
    // Should use the value we set or the default
    assert!(config.host == "127.0.0.1" || config.host == "0.0.0.0");
    assert_eq!(config.api_key.len(), 32);
    
    common::cleanup_test_env();
}

#[test]
fn test_config_missing_api_key() {
    common::cleanup_test_env(); // Clean first
    
    env::set_var("HOST", "127.0.0.1");
    env::set_var("PORT", "9876");
    // API_KEY not set
    
    let config = Config::from_env();
    assert!(config.is_err());
    assert!(config.unwrap_err().to_string().contains("API_KEY"));
    
    common::cleanup_test_env();
}

#[test]
fn test_config_api_key_too_short() {
    common::cleanup_test_env(); // Clean first
    
    // Set short API key directly
    env::set_var("API_KEY", &common::invalid_short_api_key());
    env::set_var("HOST", "127.0.0.1");
    env::set_var("PORT", "9876");
    
    let config = Config::from_env();
    assert!(config.is_err(), "Config should fail with short API key");
    let err_msg = config.unwrap_err().to_string();
    assert!(err_msg.contains("16") || err_msg.contains("characters"), 
           "Error message should mention minimum length: {}", err_msg);
    
    common::cleanup_test_env();
}

#[test]
fn test_config_default_values() {
    common::cleanup_test_env(); // Clean first
    
    // Set only required var
    env::set_var("API_KEY", &common::valid_api_key());
    
    let config = Config::from_env();
    assert!(config.is_ok());
    
    let config = config.unwrap();
    assert_eq!(config.host, "0.0.0.0");
    assert_eq!(config.port, 9876);
    assert_eq!(config.execution_timeout, 300);
    
    common::cleanup_test_env();
}

#[test]
fn test_config_custom_port() {
    common::cleanup_test_env(); // Clean first
    common::setup_test_env(&common::valid_api_key());
    env::set_var("PORT", "8765");
    
    let config = Config::from_env().unwrap();
    assert_eq!(config.port, 8765);
    
    common::cleanup_test_env();
}

#[test]
fn test_config_invalid_port() {
    common::cleanup_test_env(); // Clean first
    common::setup_test_env(&common::valid_api_key());
    env::set_var("PORT", "invalid");
    
    let config = Config::from_env();
    assert!(config.is_err());
    
    common::cleanup_test_env();
}

