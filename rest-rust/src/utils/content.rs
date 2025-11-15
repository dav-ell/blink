use serde_json::Value;
use std::collections::HashMap;

/// Extract separated content from a bubble
pub fn extract_separated_content(bubble: &HashMap<String, Value>) -> HashMap<String, Value> {
    let mut result = HashMap::new();

    // Extract text
    result.insert(
        "text".to_string(),
        bubble
            .get("text")
            .cloned()
            .unwrap_or(Value::String(String::new())),
    );

    // Extract tool calls
    if let Some(tool_calls) = extract_tool_calls(bubble) {
        result.insert("tool_calls".to_string(), tool_calls);
    }

    // Extract thinking
    if let Some(thinking) = extract_thinking(bubble) {
        result.insert("thinking".to_string(), Value::String(thinking));
    }

    // Extract code blocks (filter to only dicts)
    if let Some(Value::Array(code_blocks)) = bubble.get("codeBlocks") {
        let filtered: Vec<Value> = code_blocks
            .iter()
            .filter(|v| v.is_object())
            .cloned()
            .collect();
        if !filtered.is_empty() {
            result.insert("code_blocks".to_string(), Value::Array(filtered));
        }
    }

    // Extract todos (filter to only dicts)
    if let Some(Value::Array(todos)) = bubble.get("todos") {
        let filtered: Vec<Value> = todos.iter().filter(|v| v.is_object()).cloned().collect();
        if !filtered.is_empty() {
            result.insert("todos".to_string(), Value::Array(filtered));
        }
    }

    result
}

/// Extract tool calls from bubble as structured data
fn extract_tool_calls(bubble: &HashMap<String, Value>) -> Option<Value> {
    let tool_data = bubble.get("toolFormerData")?.as_object()?;

    // Skip error tool calls without name
    if !tool_data.contains_key("name") {
        if let Some(additional_data) = tool_data.get("additionalData") {
            if additional_data.get("status").and_then(|v| v.as_str()) == Some("error") {
                return None;
            }
        }
        let mut unknown = HashMap::new();
        unknown.insert("name".to_string(), Value::String("unknown".to_string()));
        unknown.insert(
            "description".to_string(),
            Value::String("incomplete data".to_string()),
        );
        return Some(Value::Array(vec![Value::Object(
            unknown.into_iter().collect(),
        )]));
    }

    let tool_name = tool_data.get("name")?.as_str()?.to_string();
    let raw_args = tool_data
        .get("rawArgs")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    let args: HashMap<String, Value> = serde_json::from_str(raw_args).unwrap_or_default();

    let mut tool_call = HashMap::new();
    tool_call.insert("name".to_string(), Value::String(tool_name));
    tool_call.insert(
        "explanation".to_string(),
        args.get("explanation")
            .cloned()
            .unwrap_or(Value::String(String::new())),
    );
    tool_call.insert(
        "command".to_string(),
        args.get("command")
            .cloned()
            .unwrap_or(Value::String(String::new())),
    );
    tool_call.insert(
        "arguments".to_string(),
        Value::Object(args.into_iter().collect()),
    );

    Some(Value::Array(vec![Value::Object(
        tool_call.into_iter().collect(),
    )]))
}

/// Extract thinking/reasoning content from bubble
fn extract_thinking(bubble: &HashMap<String, Value>) -> Option<String> {
    let thinking = bubble.get("thinking")?;

    match thinking {
        Value::String(s) => Some(s.clone()),
        Value::Object(obj) => obj
            .get("text")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .or_else(|| Some(thinking.to_string())),
        _ => Some(thinking.to_string()),
    }
}
