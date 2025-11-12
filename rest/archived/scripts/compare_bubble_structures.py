#!/usr/bin/env python3
"""
Compare bubble structures between API-created and Cursor-created messages.
This helps identify which fields are critical for Cursor IDE to load chats.
"""

import sqlite3
import json
import os
from datetime import datetime

DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'schema_output')

def get_db_connection():
    """Get database connection"""
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Database not found at {DB_PATH}")
    return sqlite3.connect(DB_PATH)

def load_cursor_bubble():
    """Load a Cursor-created bubble example"""
    path = os.path.join(OUTPUT_DIR, 'user_bubble_example.json')
    with open(path, 'r') as f:
        return json.load(f)

def create_api_bubble_structure():
    """Create API bubble structure as currently implemented"""
    return {
        "_v": 3,
        "type": 1,
        "text": "Example text",
        "bubbleId": "00000000-0000-0000-0000-000000000000",
        "createdAt": datetime.now().isoformat().replace('+00:00', 'Z'),
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
        "multiFileLinterErrors": [],
        "diffHistories": [],
        "recentLocationsHistory": [],
        "recentlyViewedFiles": [],
        "isAgentic": False,
        "fileDiffTrajectories": [],
        "existedSubsequentTerminalCommand": False,
        "existedPreviousTerminalCommand": False,
        "docsReferences": [],
        "webReferences": [],
        "aiWebSearchResults": [],
        "requestId": "",
        "attachedFoldersListDirResults": [],
        "humanChanges": [],
        "attachedHumanChanges": False
    }

def categorize_fields(cursor_bubble, api_bubble):
    """Categorize fields by type and importance"""
    cursor_fields = set(cursor_bubble.keys())
    api_fields = set(api_bubble.keys())
    
    missing = cursor_fields - api_fields
    extra = api_fields - cursor_fields
    common = cursor_fields & api_fields
    
    # Categorize missing fields
    required_looking = []
    array_fields = []
    dict_fields = []
    bool_fields = []
    string_fields = []
    
    for field in missing:
        value = cursor_bubble[field]
        if isinstance(value, list):
            array_fields.append(field)
        elif isinstance(value, dict):
            dict_fields.append(field)
        elif isinstance(value, bool):
            bool_fields.append(field)
        elif isinstance(value, str):
            string_fields.append(field)
        else:
            required_looking.append(field)
    
    return {
        'missing': missing,
        'extra': extra,
        'common': common,
        'categorized': {
            'arrays': array_fields,
            'dicts': dict_fields,
            'bools': bool_fields,
            'strings': string_fields,
            'other': required_looking
        }
    }

def generate_comparison_report():
    """Generate detailed comparison report"""
    print("=" * 80)
    print("BUBBLE STRUCTURE COMPARISON")
    print("=" * 80)
    
    cursor_bubble = load_cursor_bubble()
    api_bubble = create_api_bubble_structure()
    
    analysis = categorize_fields(cursor_bubble, api_bubble)
    
    print(f"\nCursor bubble: {len(cursor_bubble.keys())} fields")
    print(f"API bubble: {len(api_bubble.keys())} fields")
    print(f"Common fields: {len(analysis['common'])}")
    print(f"Missing in API: {len(analysis['missing'])}")
    print(f"Extra in API: {len(analysis['extra'])}")
    
    print("\n" + "=" * 80)
    print("MISSING FIELDS BY CATEGORY")
    print("=" * 80)
    
    cat = analysis['categorized']
    
    print(f"\n📋 Array fields ({len(cat['arrays'])}):")
    for field in sorted(cat['arrays']):
        value = cursor_bubble[field]
        print(f"  - {field}: {len(value)} items")
    
    print(f"\n📦 Dict/Object fields ({len(cat['dicts'])}):")
    for field in sorted(cat['dicts']):
        value = cursor_bubble[field]
        print(f"  - {field}: {list(value.keys()) if value else 'empty'}")
    
    print(f"\n🔲 Boolean fields ({len(cat['bools'])}):")
    for field in sorted(cat['bools']):
        value = cursor_bubble[field]
        print(f"  - {field}: {value}")
    
    print(f"\n📝 String fields ({len(cat['strings'])}):")
    for field in sorted(cat['strings']):
        value = cursor_bubble[field]
        print(f"  - {field}: '{value[:50]}{'...' if len(value) > 50 else ''}'")
    
    if cat['other']:
        print(f"\n❓ Other fields ({len(cat['other'])}):")
        for field in sorted(cat['other']):
            value = cursor_bubble[field]
            print(f"  - {field}: {type(value).__name__} = {repr(value)[:50]}")
    
    # Identify likely critical fields
    print("\n" + "=" * 80)
    print("LIKELY CRITICAL FIELDS")
    print("=" * 80)
    
    critical_candidates = []
    
    # RequestId is usually important
    if 'requestId' in analysis['missing']:
        critical_candidates.append(('requestId', 'Unique request identifier'))
    
    # SupportedTools might be important
    if 'supportedTools' in analysis['missing']:
        critical_candidates.append(('supportedTools', 'Array of tool IDs'))
    
    # TokenCount might be required
    if 'tokenCount' in analysis['missing']:
        critical_candidates.append(('tokenCount', 'Input/output token counts'))
    
    # Context structures
    if 'context' in analysis['missing']:
        critical_candidates.append(('context', 'Context dictionary'))
    
    # RichText might be required for rendering
    if 'richText' in analysis['missing']:
        critical_candidates.append(('richText', 'Lexical editor state'))
    
    if critical_candidates:
        print("\n⚠️  These fields are likely required:")
        for field, desc in critical_candidates:
            value = cursor_bubble.get(field)
            print(f"\n  {field}:")
            print(f"    Description: {desc}")
            print(f"    Type: {type(value).__name__}")
            print(f"    Value: {repr(value)[:100]}")
    
    # Save detailed report
    report_path = os.path.join(OUTPUT_DIR, 'detailed_comparison.txt')
    with open(report_path, 'w') as f:
        f.write("DETAILED BUBBLE STRUCTURE COMPARISON\n")
        f.write("=" * 80 + "\n\n")
        f.write(f"Cursor fields: {len(cursor_bubble.keys())}\n")
        f.write(f"API fields: {len(api_bubble.keys())}\n")
        f.write(f"Missing in API: {len(analysis['missing'])}\n\n")
        
        f.write("MISSING FIELDS WITH VALUES:\n")
        f.write("-" * 80 + "\n\n")
        for field in sorted(analysis['missing']):
            value = cursor_bubble[field]
            f.write(f"{field}:\n")
            f.write(f"  Type: {type(value).__name__}\n")
            f.write(f"  Value: {json.dumps(value, indent=2)[:500]}\n\n")
    
    print(f"\n✓ Saved detailed report: {report_path}")

def main():
    """Main comparison process"""
    try:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        generate_comparison_report()
        
        print("\n" + "=" * 80)
        print("COMPARISON COMPLETE")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

