#!/usr/bin/env python3
"""
Repair broken chats by adding missing fields to existing bubbles.
This can fix chats that were created with the old incomplete bubble structure.
"""

import sqlite3
import json
import os
import sys
from datetime import datetime

DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')

def get_db_connection():
    """Get database connection"""
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Database not found at {DB_PATH}")
    return sqlite3.connect(DB_PATH)

def analyze_bubble(bubble_data):
    """Analyze a bubble to see if it's missing fields"""
    required_fields = {
        'supportedTools', 'tokenCount', 'context', 'richText',
        'requestId', 'checkpointId', 'isAgentic', 'unifiedMode'
    }
    
    missing = required_fields - set(bubble_data.keys())
    return missing

def repair_bubble(bubble_data):
    """Add missing fields to a bubble"""
    import uuid
    
    # Add missing arrays
    array_fields = [
        'allThinkingBlocks', 'attachedFileCodeChunksMetadataOnly', 'capabilityContexts',
        'consoleLogs', 'contextPieces', 'cursorRules', 'deletedFiles',
        'diffsForCompressingFiles', 'diffsSinceLastApply', 'documentationSelections',
        'editTrailContexts', 'externalLinks', 'knowledgeItems', 'projectLayouts',
        'relevantFiles', 'suggestedCodeBlocks', 'summarizedComposers', 'todos',
        'uiElementPicked', 'userResponsesToSuggestedCodeBlocks'
    ]
    
    for field in array_fields:
        if field not in bubble_data:
            bubble_data[field] = []
    
    # Add missing boolean fields
    bool_defaults = {
        'editToolSupportsSearchAndReplace': True,
        'isNudge': False,
        'isPlanExecution': False,
        'isQuickSearchQuery': False,
        'isRefunded': False,
        'skipRendering': False,
        'useWeb': False,
        'existedSubsequentTerminalCommand': False,
        'existedPreviousTerminalCommand': False
    }
    
    for field, default in bool_defaults.items():
        if field not in bubble_data:
            bubble_data[field] = default
    
    # Add isAgentic if missing
    if 'isAgentic' not in bubble_data:
        bubble_data['isAgentic'] = bubble_data.get('type') == 1
    
    # Add supportedTools if missing
    if 'supportedTools' not in bubble_data:
        bubble_data['supportedTools'] = [1, 41, 7, 38, 8, 9, 11, 12, 15, 18, 19, 25, 27, 43, 46, 47, 29, 30, 32, 34, 35, 39, 40, 42, 44, 45]
    
    # Add tokenCount if missing
    if 'tokenCount' not in bubble_data:
        bubble_data['tokenCount'] = {"inputTokens": 0, "outputTokens": 0}
    
    # Add context if missing
    if 'context' not in bubble_data:
        bubble_data['context'] = {
            "composers": [], "quotes": [], "selectedCommits": [],
            "selectedPullRequests": [], "selectedImages": [], "folderSelections": [],
            "fileSelections": [], "terminalFiles": [], "selections": [],
            "terminalSelections": [], "selectedDocs": [], "externalLinks": [],
            "cursorRules": [], "cursorCommands": [], "uiElementSelections": [],
            "consoleLogs": [], "mentions": []
        }
    
    # Add requestId if missing
    if 'requestId' not in bubble_data:
        bubble_data['requestId'] = str(uuid.uuid4())
    
    # Add checkpointId if missing
    if 'checkpointId' not in bubble_data:
        bubble_data['checkpointId'] = str(uuid.uuid4())
    
    # Add richText if missing
    if 'richText' not in bubble_data:
        text = bubble_data.get('text', '')
        bubble_data['richText'] = json.dumps({
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
        })
    
    # Add unifiedMode if missing
    if 'unifiedMode' not in bubble_data:
        bubble_data['unifiedMode'] = 5
    
    # Add modelInfo for assistant messages if missing
    if bubble_data.get('type') == 2 and 'modelInfo' not in bubble_data:
        bubble_data['modelInfo'] = {"modelName": "claude-4.5-sonnet"}
    
    # Ensure capabilityStatuses has proper structure
    if 'capabilityStatuses' not in bubble_data or not isinstance(bubble_data['capabilityStatuses'], dict):
        bubble_data['capabilityStatuses'] = {
            "mutate-request": [], "start-submit-chat": [], "before-submit-chat": [],
            "chat-stream-finished": [], "before-apply": [], "after-apply": [],
            "accept-all-edits": [], "composer-done": [], "process-stream": [],
            "add-pending-action": []
        }
    
    return bubble_data

def repair_composer_metadata(metadata):
    """Add missing fields to composer metadata"""
    if '_v' not in metadata:
        metadata['_v'] = 10
    
    if 'hasLoaded' not in metadata:
        metadata['hasLoaded'] = True
    
    if 'text' not in metadata:
        metadata['text'] = ""
    
    if 'richText' not in metadata:
        metadata['richText'] = json.dumps({
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
        })
    
    return metadata

def repair_chat(chat_id, dry_run=True):
    """Repair a specific chat"""
    print(f"\n{'=' * 80}")
    print(f"REPAIRING CHAT: {chat_id}")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE UPDATE'}")
    print(f"{'=' * 80}\n")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get all bubbles for this chat
        cursor.execute(
            "SELECT key, value FROM cursorDiskKV WHERE key LIKE ?",
            (f'bubbleId:{chat_id}:%',)
        )
        
        bubbles = []
        for key, value in cursor.fetchall():
            bubble_data = json.loads(value)
            bubbles.append((key, bubble_data))
        
        if not bubbles:
            print(f"❌ No bubbles found for chat {chat_id}")
            return False
        
        print(f"Found {len(bubbles)} bubbles")
        
        # Analyze and repair each bubble
        repaired_count = 0
        for key, bubble_data in bubbles:
            missing = analyze_bubble(bubble_data)
            
            if missing:
                bubble_id = key.split(':')[-1]
                msg_type = 'user' if bubble_data.get('type') == 1 else 'assistant'
                print(f"\n  {msg_type} bubble {bubble_id[:8]}...")
                print(f"    Missing {len(missing)} fields: {', '.join(sorted(missing))}")
                
                # Repair
                repaired = repair_bubble(bubble_data)
                repaired_count += 1
                
                if not dry_run:
                    cursor.execute(
                        "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
                        (json.dumps(repaired), key)
                    )
                    print(f"    ✓ Repaired")
                else:
                    print(f"    → Would repair")
        
        # Repair composer metadata
        cursor.execute(
            "SELECT value FROM cursorDiskKV WHERE key = ?",
            (f'composerData:{chat_id}',)
        )
        row = cursor.fetchone()
        if row:
            metadata = json.loads(row[0])
            repaired_metadata = repair_composer_metadata(metadata)
            
            if repaired_metadata != metadata:
                print(f"\n  Composer metadata needs repair")
                if not dry_run:
                    cursor.execute(
                        "UPDATE cursorDiskKV SET value = ? WHERE key = ?",
                        (json.dumps(repaired_metadata), f'composerData:{chat_id}')
                    )
                    print(f"    ✓ Repaired")
                else:
                    print(f"    → Would repair")
        
        if not dry_run:
            conn.commit()
            print(f"\n✅ Successfully repaired {repaired_count} bubbles")
        else:
            print(f"\n✓ Dry run complete - would repair {repaired_count} bubbles")
            print(f"\nTo apply repairs, run: python3 {sys.argv[0]} {chat_id} --apply")
        
        return True
        
    except Exception as e:
        conn.rollback()
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        conn.close()

def list_recent_chats():
    """List recent chats to help user find broken ones"""
    print("=" * 80)
    print("RECENT CHATS")
    print("=" * 80 + "\n")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT key, value FROM cursorDiskKV 
        WHERE key LIKE 'composerData:%'
        ORDER BY key DESC LIMIT 20
    """)
    
    chats = []
    for key, value in cursor.fetchall():
        try:
            data = json.loads(value)
            chat_id = key.split(':')[1]
            name = data.get('name', 'Untitled')
            msg_count = len(data.get('fullConversationHeadersOnly', []))
            last_updated = data.get('lastUpdatedAt', 0)
            chats.append((last_updated, chat_id, name, msg_count))
        except:
            pass
    
    chats.sort(reverse=True)
    
    for i, (ts, chat_id, name, msg_count) in enumerate(chats[:20], 1):
        dt = datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d %H:%M') if ts else 'N/A'
        print(f"{i:2}. [{dt}] {name[:50]}")
        print(f"    {chat_id} ({msg_count} messages)")
    
    conn.close()

def main():
    """Main repair process"""
    print("\n" + "█" * 80)
    print("  CHAT REPAIR TOOL")
    print("  Fix broken chats created with incomplete bubble structure")
    print("█" * 80 + "\n")
    
    if len(sys.argv) < 2:
        print("Usage:")
        print(f"  {sys.argv[0]} <chat_id> [--apply]")
        print(f"  {sys.argv[0]} --list")
        print("\nOptions:")
        print("  <chat_id>  : Chat ID to repair")
        print("  --apply    : Apply repairs (default is dry-run)")
        print("  --list     : List recent chats")
        print("\nExample:")
        print(f"  {sys.argv[0]} 99866935-88a5-49fc-aa99-9597ec205651")
        print(f"  {sys.argv[0]} 99866935-88a5-49fc-aa99-9597ec205651 --apply")
        return 1
    
    if sys.argv[1] == '--list':
        list_recent_chats()
        return 0
    
    chat_id = sys.argv[1]
    dry_run = '--apply' not in sys.argv
    
    if dry_run:
        print("⚠️  DRY RUN MODE - No changes will be made")
        print("    Add --apply flag to actually repair the chat\n")
    else:
        print("⚠️  LIVE MODE - Changes will be written to database")
        print("    Make sure you have a backup if needed\n")
        response = input("Continue? (yes/no): ")
        if response.lower() != 'yes':
            print("Aborted.")
            return 0
    
    success = repair_chat(chat_id, dry_run)
    
    if success and not dry_run:
        print("\n" + "=" * 80)
        print("REPAIR COMPLETE")
        print("=" * 80)
        print("\n✓ Chat has been repaired")
        print("✓ Try opening it in Cursor IDE to verify it loads correctly")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())

