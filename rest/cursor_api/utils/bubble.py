"""Bubble data structure creation and validation"""

import json
import uuid as uuid_lib
from datetime import datetime, timezone
from typing import Dict, Any


def create_bubble_data(
    bubble_id: str,
    message_type: int,
    text: str,
    thinking: str = None,
    tool_calls: list = None
) -> Dict[str, Any]:
    """Create a complete bubble data structure matching Cursor's format
    
    This includes all fields that Cursor expects to properly load and display chats.
    Missing fields can cause the Cursor IDE to fail when loading the chat.
    
    Args:
        bubble_id: Unique bubble UUID
        message_type: Message type (1=user, 2=assistant)
        text: Message text content
        thinking: Optional thinking/reasoning content
        tool_calls: Optional list of tool call dictionaries
        
    Returns:
        Complete bubble data dictionary
    """
    
    # Generate a unique request ID for this bubble
    request_id = str(uuid_lib.uuid4())
    checkpoint_id = str(uuid_lib.uuid4())
    
    # Create Lexical editor richText structure
    rich_text = {
        "root": {
            "children": [{
                "children": [{
                    "detail": 0,
                    "format": 0,
                    "mode": "normal",
                    "style": "",
                    "text": text,
                    "type": "text",
                    "version": 1
                }],
                "direction": None,
                "format": "",
                "indent": 0,
                "type": "paragraph",
                "version": 1
            }],
            "direction": None,
            "format": "",
            "indent": 0,
            "type": "root",
            "version": 1
        }
    }
    
    bubble = {
        "_v": 3,
        "type": message_type,  # 1=user, 2=assistant
        "text": text,
        "bubbleId": bubble_id,
        "createdAt": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        
        # Core arrays (usually empty for basic messages)
        "approximateLintErrors": [],
        "lints": [],
        "codebaseContextChunks": [],
        "commits": [],
        "pullRequests": [],
        "attachedCodeChunks": [],
        "assistantSuggestedDiffs": [],
        "gitDiffs": [],
        "interpreterResults": [],
        "images": [],
        "attachedFolders": [],
        "attachedFoldersNew": [],
        "toolResults": [],
        "notepads": [],
        "capabilities": [],
        "multiFileLinterErrors": [],
        "diffHistories": [],
        "recentLocationsHistory": [],
        "recentlyViewedFiles": [],
        "fileDiffTrajectories": [],
        "docsReferences": [],
        "webReferences": [],
        "aiWebSearchResults": [],
        "attachedFoldersListDirResults": [],
        "humanChanges": [],
        
        # Additional arrays required by Cursor
        "allThinkingBlocks": [],
        "attachedFileCodeChunksMetadataOnly": [],
        "capabilityContexts": [],
        "consoleLogs": [],
        "contextPieces": [],
        "cursorRules": [],
        "deletedFiles": [],
        "diffsForCompressingFiles": [],
        "diffsSinceLastApply": [],
        "documentationSelections": [],
        "editTrailContexts": [],
        "externalLinks": [],
        "knowledgeItems": [],
        "projectLayouts": [],
        "relevantFiles": [],
        "suggestedCodeBlocks": [],
        "summarizedComposers": [],
        "todos": [],
        "uiElementPicked": [],
        "userResponsesToSuggestedCodeBlocks": [],
        
        # Capability statuses (required structure)
        "capabilityStatuses": {
            "mutate-request": [],
            "start-submit-chat": [],
            "before-submit-chat": [],
            "chat-stream-finished": [],
            "before-apply": [],
            "after-apply": [],
            "accept-all-edits": [],
            "composer-done": [],
            "process-stream": [],
            "add-pending-action": []
        },
        
        # Boolean flags
        "isAgentic": message_type == 1,  # True for user messages
        "existedSubsequentTerminalCommand": False,
        "existedPreviousTerminalCommand": False,
        "editToolSupportsSearchAndReplace": True,
        "isNudge": False,
        "isPlanExecution": False,
        "isQuickSearchQuery": False,
        "isRefunded": False,
        "skipRendering": False,
        "useWeb": False,
        
        # Critical fields for Cursor IDE
        "supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45],
        "tokenCount": {
            "inputTokens": 0,
            "outputTokens": 0
        },
        "context": {
            "composers": [],
            "quotes": [],
            "selectedCommits": [],
            "selectedPullRequests": [],
            "selectedImages": [],
            "folderSelections": [],
            "fileSelections": [],
            "terminalFiles": [],
            "selections": [],
            "terminalSelections": [],
            "selectedDocs": [],
            "externalLinks": [],
            "cursorRules": [],
            "cursorCommands": [],
            "uiElementSelections": [],
            "consoleLogs": [],
            "mentions": []
        },
        
        # Identifiers
        "requestId": request_id,
        "checkpointId": checkpoint_id,
        
        # Rich text representation (Lexical editor format)
        "richText": json.dumps(rich_text),
        
        # Unified mode (standard value)
        "unifiedMode": 5,
    }
    
    # Add thinking content if provided
    if thinking:
        bubble["thinking"] = {"text": thinking}
    
    # Add tool calls if provided (convert our simplified format to Cursor's format)
    if tool_calls:
        # For now, store the first tool call in toolFormerData
        # Cursor's format stores tool calls in toolFormerData field
        if len(tool_calls) > 0:
            tool = tool_calls[0]
            bubble["toolFormerData"] = {
                "name": tool.get("name", "unknown"),
                "rawArgs": json.dumps(tool.get("arguments", {})),
                "additionalData": {}
            }
    
    # Add model info for assistant messages
    if message_type == 2:
        bubble["modelInfo"] = {
            "modelName": "claude-4.5-sonnet"
        }
    
    return bubble


def validate_bubble_structure(bubble_data: Dict[str, Any]) -> bool:
    """Validate that bubble has required fields matching Cursor's format
    
    Args:
        bubble_data: Bubble dictionary to validate
        
    Returns:
        True if valid, False otherwise
    """
    required_fields = [
        "_v", "type", "text", "bubbleId", "createdAt",
        "approximateLintErrors", "lints", "capabilities", "capabilityStatuses"
    ]
    return all(field in bubble_data for field in required_fields)

