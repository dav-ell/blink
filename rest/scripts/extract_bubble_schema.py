#!/usr/bin/env python3
"""
Extract and document complete bubble and composerData schemas from Cursor database.
This helps understand what fields Cursor expects vs what our API creates.
"""

import sqlite3
import json
import os
from datetime import datetime
from collections import defaultdict

DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'schema_output')

def ensure_output_dir():
    """Create output directory if it doesn't exist"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

def get_db_connection():
    """Get database connection"""
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Database not found at {DB_PATH}")
    return sqlite3.connect(DB_PATH)

def analyze_field_types(data, prefix=""):
    """Recursively analyze field types and structures"""
    field_info = {}
    
    if isinstance(data, dict):
        for key, value in data.items():
            full_key = f"{prefix}.{key}" if prefix else key
            
            if value is None:
                field_info[full_key] = "null"
            elif isinstance(value, bool):
                field_info[full_key] = "boolean"
            elif isinstance(value, int):
                field_info[full_key] = "integer"
            elif isinstance(value, float):
                field_info[full_key] = "float"
            elif isinstance(value, str):
                field_info[full_key] = f"string (len={len(value)})"
            elif isinstance(value, list):
                if len(value) == 0:
                    field_info[full_key] = "array (empty)"
                else:
                    field_info[full_key] = f"array (len={len(value)}, item_type={type(value[0]).__name__})"
                    # Analyze first item if it's a dict
                    if value and isinstance(value[0], dict):
                        nested = analyze_field_types(value[0], full_key + "[0]")
                        field_info.update(nested)
            elif isinstance(value, dict):
                field_info[full_key] = "object"
                nested = analyze_field_types(value, full_key)
                field_info.update(nested)
    
    return field_info

def extract_bubble_schemas():
    """Extract bubble schemas from database"""
    print("=" * 80)
    print("EXTRACTING BUBBLE SCHEMAS")
    print("=" * 80)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get recent chat with messages
    cursor.execute("""
        SELECT key, value FROM cursorDiskKV 
        WHERE key LIKE 'composerData:%' 
        ORDER BY key DESC LIMIT 5
    """)
    
    chat_found = None
    for key, value in cursor.fetchall():
        data = json.loads(value)
        msg_count = len(data.get('fullConversationHeadersOnly', []))
        if msg_count > 0:
            chat_found = key.split(':')[1]
            print(f"Using chat: {data.get('name', 'Untitled')} ({msg_count} messages)")
            break
    
    if not chat_found:
        print("No chats with messages found!")
        return
    
    # Extract bubbles
    cursor.execute(f"""
        SELECT key, value FROM cursorDiskKV 
        WHERE key LIKE 'bubbleId:{chat_found}:%'
        LIMIT 10
    """)
    
    user_bubbles = []
    assistant_bubbles = []
    
    for key, value in cursor.fetchall():
        data = json.loads(value)
        if data.get('type') == 1:
            user_bubbles.append(data)
        elif data.get('type') == 2:
            assistant_bubbles.append(data)
    
    ensure_output_dir()
    
    # Save example user bubble
    if user_bubbles:
        user_bubble = user_bubbles[0]
        output_path = os.path.join(OUTPUT_DIR, 'user_bubble_example.json')
        with open(output_path, 'w') as f:
            json.dump(user_bubble, f, indent=2)
        print(f"\n✓ Saved user bubble example: {output_path}")
        print(f"  Fields: {len(user_bubble.keys())}")
        
        # Analyze fields
        field_info = analyze_field_types(user_bubble)
        field_list_path = os.path.join(OUTPUT_DIR, 'user_bubble_fields.txt')
        with open(field_list_path, 'w') as f:
            f.write("USER BUBBLE FIELDS\n")
            f.write("=" * 80 + "\n\n")
            for field, ftype in sorted(field_info.items()):
                f.write(f"{field}: {ftype}\n")
        print(f"  Field analysis: {field_list_path}")
    
    # Save example assistant bubble
    if assistant_bubbles:
        assistant_bubble = assistant_bubbles[0]
        output_path = os.path.join(OUTPUT_DIR, 'assistant_bubble_example.json')
        with open(output_path, 'w') as f:
            json.dump(assistant_bubble, f, indent=2)
        print(f"\n✓ Saved assistant bubble example: {output_path}")
        print(f"  Fields: {len(assistant_bubble.keys())}")
        
        # Analyze fields
        field_info = analyze_field_types(assistant_bubble)
        field_list_path = os.path.join(OUTPUT_DIR, 'assistant_bubble_fields.txt')
        with open(field_list_path, 'w') as f:
            f.write("ASSISTANT BUBBLE FIELDS\n")
            f.write("=" * 80 + "\n\n")
            for field, ftype in sorted(field_info.items()):
                f.write(f"{field}: {ftype}\n")
        print(f"  Field analysis: {field_list_path}")
    
    conn.close()

def extract_composer_data_schema():
    """Extract composerData schema from database"""
    print("\n" + "=" * 80)
    print("EXTRACTING COMPOSER DATA SCHEMA")
    print("=" * 80)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get recent chat with messages
    cursor.execute("""
        SELECT key, value FROM cursorDiskKV 
        WHERE key LIKE 'composerData:%' 
        ORDER BY key DESC LIMIT 1
    """)
    
    row = cursor.fetchone()
    if not row:
        print("No composer data found!")
        return
    
    key, value = row
    data = json.loads(value)
    
    ensure_output_dir()
    
    # Save example
    output_path = os.path.join(OUTPUT_DIR, 'composer_data_example.json')
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"\n✓ Saved composer data example: {output_path}")
    print(f"  Fields: {len(data.keys())}")
    
    # Analyze fields
    field_info = analyze_field_types(data)
    field_list_path = os.path.join(OUTPUT_DIR, 'composer_data_fields.txt')
    with open(field_list_path, 'w') as f:
        f.write("COMPOSER DATA FIELDS\n")
        f.write("=" * 80 + "\n\n")
        for field, ftype in sorted(field_info.items()):
            f.write(f"{field}: {ftype}\n")
    print(f"  Field analysis: {field_list_path}")
    
    conn.close()

def compare_with_api_structure():
    """Compare Cursor structure with API-created structure"""
    print("\n" + "=" * 80)
    print("COMPARING WITH API STRUCTURE")
    print("=" * 80)
    
    # Read API structure from cursor_chat_api.py
    api_file = os.path.join(os.path.dirname(__file__), '..', 'cursor_chat_api.py')
    with open(api_file, 'r') as f:
        content = f.read()
    
    # Extract create_bubble_data fields (between lines 239-278)
    import re
    pattern = r'def create_bubble_data.*?return\s+{([^}]+)}'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        api_fields = set()
        field_block = match.group(1)
        for line in field_block.split('\n'):
            line = line.strip()
            if line and ':' in line:
                field_name = line.split(':')[0].strip().strip('"')
                if field_name:
                    api_fields.add(field_name)
        
        print(f"\n✓ API creates {len(api_fields)} fields in bubble")
        
        # Load Cursor example
        user_bubble_path = os.path.join(OUTPUT_DIR, 'user_bubble_example.json')
        if os.path.exists(user_bubble_path):
            with open(user_bubble_path, 'r') as f:
                cursor_bubble = json.load(f)
            
            cursor_fields = set(cursor_bubble.keys())
            print(f"✓ Cursor bubble has {len(cursor_fields)} fields")
            
            missing_in_api = cursor_fields - api_fields
            extra_in_api = api_fields - cursor_fields
            
            print(f"\n⚠ Missing in API ({len(missing_in_api)} fields):")
            for field in sorted(missing_in_api):
                print(f"  - {field}")
            
            if extra_in_api:
                print(f"\n✓ Extra in API ({len(extra_in_api)} fields):")
                for field in sorted(extra_in_api):
                    print(f"  - {field}")
            
            # Save comparison report
            report_path = os.path.join(OUTPUT_DIR, 'field_comparison.txt')
            with open(report_path, 'w') as f:
                f.write("FIELD COMPARISON: API vs CURSOR\n")
                f.write("=" * 80 + "\n\n")
                f.write(f"API fields: {len(api_fields)}\n")
                f.write(f"Cursor fields: {len(cursor_fields)}\n")
                f.write(f"Missing in API: {len(missing_in_api)}\n")
                f.write(f"Extra in API: {len(extra_in_api)}\n\n")
                f.write("MISSING IN API:\n")
                f.write("-" * 80 + "\n")
                for field in sorted(missing_in_api):
                    value = cursor_bubble.get(field)
                    f.write(f"{field}: {type(value).__name__} = {repr(value)[:100]}\n")
            print(f"\n✓ Saved comparison report: {report_path}")

def main():
    """Main extraction process"""
    print("\n" + "█" * 80)
    print("  CURSOR DATABASE SCHEMA EXTRACTION")
    print("█" * 80 + "\n")
    
    try:
        extract_bubble_schemas()
        extract_composer_data_schema()
        compare_with_api_structure()
        
        print("\n" + "=" * 80)
        print("EXTRACTION COMPLETE")
        print("=" * 80)
        print(f"\nOutput directory: {OUTPUT_DIR}")
        print("\nFiles created:")
        print("  - user_bubble_example.json")
        print("  - user_bubble_fields.txt")
        print("  - assistant_bubble_example.json")
        print("  - assistant_bubble_fields.txt")
        print("  - composer_data_example.json")
        print("  - composer_data_fields.txt")
        print("  - field_comparison.txt")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

