use remote_agent_service::executor::execute_cursor_agent;
use tempfile::TempDir;

#[tokio::test]
async fn test_execute_with_valid_directory() {
    let temp_dir = TempDir::new().unwrap();
    let working_dir = temp_dir.path().to_str().unwrap();
    
    // Use `echo` command which exists on all systems
    let result = execute_cursor_agent(
        "echo",
        "test-chat-id",
        "test prompt",
        working_dir,
        "test-model",
        "json",
    )
    .await;
    
    assert!(result.is_ok());
    let result = result.unwrap();
    assert_eq!(result.returncode, 0);
    assert!(result.success);
}

#[tokio::test]
async fn test_execute_with_invalid_directory() {
    let result = execute_cursor_agent(
        "echo",
        "test-chat-id",
        "test prompt",
        "/nonexistent/directory/path",
        "test-model",
        "json",
    )
    .await;
    
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(err.to_string().contains("does not exist"));
}

#[tokio::test]
async fn test_execute_with_nonexistent_command() {
    let temp_dir = TempDir::new().unwrap();
    let working_dir = temp_dir.path().to_str().unwrap();
    
    let result = execute_cursor_agent(
        "/nonexistent/command",
        "test-chat-id",
        "test prompt",
        working_dir,
        "test-model",
        "json",
    )
    .await;
    
    assert!(result.is_err());
}

#[tokio::test]
async fn test_execute_captures_stdout() {
    let temp_dir = TempDir::new().unwrap();
    let working_dir = temp_dir.path().to_str().unwrap();
    
    let result = execute_cursor_agent(
        "echo",
        "test-chat-id",
        "hello world",
        working_dir,
        "test-model",
        "json",
    )
    .await
    .unwrap();
    
    assert!(result.stdout.contains("hello") || result.stdout.contains("world"));
}

#[tokio::test]
async fn test_execute_with_special_characters_in_prompt() {
    let temp_dir = TempDir::new().unwrap();
    let working_dir = temp_dir.path().to_str().unwrap();
    
    let result = execute_cursor_agent(
        "echo",
        "test-chat-id",
        "prompt with $pecial ch@racter$ & symbols!",
        working_dir,
        "test-model",
        "json",
    )
    .await;
    
    assert!(result.is_ok());
}

