-- Device Management Database Schema
-- Stores SSH device configurations and remote chat tracking

CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,           -- UUID
    name TEXT NOT NULL,             -- User-friendly name (e.g., "Production Server")
    hostname TEXT NOT NULL,         -- SSH hostname/IP
    username TEXT NOT NULL,         -- SSH username
    port INTEGER DEFAULT 22,        -- SSH port
    cursor_agent_path TEXT,         -- Remote cursor-agent path (optional, defaults to ~/.local/bin/cursor-agent)
    created_at INTEGER NOT NULL,    -- Unix timestamp in milliseconds
    last_seen INTEGER,              -- Last successful connection timestamp
    is_active INTEGER DEFAULT 1     -- 1=active, 0=inactive/deleted
);

CREATE TABLE IF NOT EXISTS remote_chats (
    chat_id TEXT PRIMARY KEY,           -- Cursor chat ID (UUID)
    device_id TEXT NOT NULL,             -- FK to devices.id
    working_directory TEXT NOT NULL,     -- Remote working directory
    name TEXT DEFAULT 'Untitled',        -- Chat name (cached from remote)
    created_at INTEGER NOT NULL,         -- Unix timestamp in milliseconds
    last_updated_at INTEGER,             -- Last message timestamp
    message_count INTEGER DEFAULT 0,     -- Cached message count
    last_message_preview TEXT,           -- First 100 chars of last message
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_devices_active ON devices(is_active);
CREATE INDEX IF NOT EXISTS idx_remote_chats_device ON remote_chats(device_id);
CREATE INDEX IF NOT EXISTS idx_remote_chats_updated ON remote_chats(last_updated_at);

