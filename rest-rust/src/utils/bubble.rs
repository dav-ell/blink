use serde_json::{json, Value};
use std::collections::HashMap;

/// Create bubble data for a message
pub fn create_bubble_data(
    _bubble_id: &str,
    bubble_type: i32,
    text: &str,
) -> HashMap<String, Value> {
    let now_ms = chrono::Utc::now().timestamp_millis();
    
    let mut bubble_data = HashMap::new();
    bubble_data.insert("type".to_string(), json!(bubble_type));
    bubble_data.insert("text".to_string(), json!(text));
    bubble_data.insert("createdAt".to_string(), json!(now_ms));
    
    bubble_data
}

/// Validate bubble structure
pub fn validate_bubble_structure(bubble_data: &HashMap<String, Value>) -> bool {
    bubble_data.contains_key("type") 
        && bubble_data.contains_key("text")
}

/// Extract text content from bubble
pub fn extract_message_content(bubble_data: &HashMap<String, Value>) -> String {
    bubble_data
        .get("text")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string()
}

