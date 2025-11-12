#!/usr/bin/env python3
"""
Test minimal bubble structure by creating test chats with varying field sets.
This helps identify the minimum required fields for Cursor IDE to load chats.
"""

import sqlite3
import json
import os
import uuid
from datetime import datetime, timezone

DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')

def get_db_connection():
    """Get database connection"""
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Database not found at {DB_PATH}")
    return sqlite3.connect(DB_PATH)

def create_minimal_bubble(bubble_id, msg_type, text):
    """Create absolute minimal bubble (current API)"""
    return {
        "_v": 3,
        "type": msg_type,
        "text": text,
        "bubbleId": bubble_id,
        "createdAt": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
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
        "capabilityStatuses": {},
    }

def create_enhanced_bubble(bubble_id, msg_type, text):
    """Create bubble with likely critical fields added"""
    base = create_minimal_bubble(bubble_id, msg_type, text)
    
    # Add likely critical fields
    base.update({
        # Array fields that were always empty in examples
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
        
        # Boolean fields
        "isAgentic": msg_type == 1,  # True for user messages
        "existedSubsequentTerminalCommand": False,
        "existedPreviousTerminalCommand": False,
        "editToolSupportsSearchAndReplace": True,
        "isNudge": False,
        "isPlanExecution": False,
        "isQuickSearchQuery": False,
        "isRefunded": False,
        "skipRendering": False,
        "useWeb": False,
        
        # Critical complex fields
        "supportedTools": [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45],
        "tokenCount": {"inputTokens": 0, "outputTokens": 0},
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
        
        # String fields
        "requestId": str(uuid.uuid4()),
        "checkpointId": str(uuid.uuid4()),
        "richText": json.dumps({
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
        }),
        
        # Other fields
        "unifiedMode": 5,
    })
    
    # For assistant messages, add modelInfo
    if msg_type == 2:
        base["modelInfo"] = {"modelName": "claude-4.5-sonnet"}
    
    return base

def create_test_chat(test_name, bubble_creator_func):
    """Create a test chat with specified bubble creator"""
    print(f"\n{'=' * 80}")
    print(f"Creating test chat: {test_name}")
    print(f"{'=' * 80}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Generate IDs
        chat_id = str(uuid.uuid4())
        user_bubble_id = str(uuid.uuid4())
        assistant_bubble_id = str(uuid.uuid4())
        
        # Create chat metadata
        chat_metadata = {
            "_v": 10,
            "composerId": chat_id,
            "name": f"TEST: {test_name}",
            "richText": json.dumps({
                "root": {
                    "children": [{
                        "children": [],
                        "format": "",
                        "indent": 0,
                        "type": "paragraph",
                        "version": 1
                    }],
                    "format": "",
                    "indent": 0,
                    "type": "root",
                    "version": 1
                }
            }),
            "hasLoaded": True,
            "text": "",
            "fullConversationHeadersOnly": [
                {"bubbleId": user_bubble_id, "type": 1},
                {"bubbleId": assistant_bubble_id, "type": 2}
            ],
            "createdAt": int(datetime.now().timestamp() * 1000),
            "lastUpdatedAt": int(datetime.now().timestamp() * 1000),
            "isArchived": False,
            "isDraft": False,
            "totalLinesAdded": 0,
            "totalLinesRemoved": 0,
        }
        
        # Insert composer data
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'composerData:{chat_id}', json.dumps(chat_metadata))
        )
        
        # Create bubbles
        user_bubble = bubble_creator_func(user_bubble_id, 1, "Test user message")
        assistant_bubble = bubble_creator_func(assistant_bubble_id, 2, "Test assistant response")
        
        # Insert bubbles
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'bubbleId:{chat_id}:{user_bubble_id}', json.dumps(user_bubble))
        )
        cursor.execute(
            "INSERT INTO cursorDiskKV (key, value) VALUES (?, ?)",
            (f'bubbleId:{chat_id}:{assistant_bubble_id}', json.dumps(assistant_bubble))
        )
        
        conn.commit()
        
        print(f"✓ Created test chat: {chat_id}")
        print(f"  User bubble fields: {len(user_bubble.keys())}")
        print(f"  Assistant bubble fields: {len(assistant_bubble.keys())}")
        print(f"\n⚠️  MANUAL TEST REQUIRED:")
        print(f"  1. Open Cursor IDE")
        print(f"  2. Open Composer/Chat panel")
        print(f"  3. Look for chat: 'TEST: {test_name}'")
        print(f"  4. Try to open it and verify it loads without error")
        print(f"  5. Check if messages display correctly")
        
        return chat_id
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None
    finally:
        conn.close()

def main():
    """Run test scenarios"""
    print("\n" + "█" * 80)
    print("  MINIMAL BUBBLE TESTING")
    print("█" * 80)
    
    print("\n⚠️  WARNING: This will create test chats in your Cursor database.")
    print("Make sure to backup your database first if needed.")
    response = input("\nContinue? (yes/no): ")
    
    if response.lower() != 'yes':
        print("Aborted.")
        return 0
    
    # Test 1: Minimal bubble (current API)
    chat1 = create_test_chat("Minimal Fields (Current API)", create_minimal_bubble)
    
    # Test 2: Enhanced bubble (with all fields)
    chat2 = create_test_chat("Enhanced Fields (All Fields)", create_enhanced_bubble)
    
    print("\n" + "=" * 80)
    print("TEST CHATS CREATED")
    print("=" * 80)
    print(f"\nTest Chat IDs:")
    if chat1:
        print(f"  1. Minimal: {chat1}")
    if chat2:
        print(f"  2. Enhanced: {chat2}")
    
    print("\n" + "=" * 80)
    print("NEXT STEPS")
    print("=" * 80)
    print("\n1. Open Cursor IDE")
    print("2. Navigate to Composer/Chat history")
    print("3. Try to open both test chats")
    print("4. Observe which one loads successfully:")
    print("   - If 'Minimal' works: Current API is fine")
    print("   - If 'Enhanced' works but 'Minimal' doesn't: Need to add missing fields")
    print("   - If neither works: May need additional fields")
    print("\n5. Report results back to update the API implementation")
    
    return 0

if __name__ == "__main__":
    exit(main())

