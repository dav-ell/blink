use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedAgentOutput {
    pub text: String,
    pub thinking: Option<String>,
    pub tool_calls: Option<Vec<HashMap<String, Value>>>,
}

/// Parse cursor-agent stream-json output
pub fn parse_cursor_agent_output(output: &str) -> Result<ParsedAgentOutput, String> {
    let mut text_parts = Vec::new();
    let mut thinking: Option<String> = None;
    let mut tool_calls: Option<Vec<HashMap<String, Value>>> = None;
    
    for line in output.lines() {
        if line.trim().is_empty() {
            continue;
        }
        
        match serde_json::from_str::<HashMap<String, Value>>(line) {
            Ok(json_obj) => {
                if let Some(event_type) = json_obj.get("type").and_then(|v| v.as_str()) {
                    match event_type {
                        "text" => {
                            if let Some(text) = json_obj.get("text").and_then(|v| v.as_str()) {
                                text_parts.push(text.to_string());
                            }
                        }
                        "thinking" => {
                            if let Some(content) = json_obj.get("thinking").and_then(|v| v.as_str()) {
                                thinking = Some(content.to_string());
                            }
                        }
                        "tool_call" => {
                            if tool_calls.is_none() {
                                tool_calls = Some(Vec::new());
                            }
                            if let Some(calls) = &mut tool_calls {
                                calls.push(json_obj);
                            }
                        }
                        _ => {}
                    }
                }
            }
            Err(_) => {
                // If it's not JSON, treat it as raw text
                text_parts.push(line.to_string());
            }
        }
    }
    
    Ok(ParsedAgentOutput {
        text: text_parts.join(""),
        thinking,
        tool_calls,
    })
}

