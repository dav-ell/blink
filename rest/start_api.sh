#!/bin/bash
# Start the Cursor Chat REST API Server

cd "$(dirname "$0")"

# Check if venv exists
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
    echo "Installing dependencies..."
    uv pip install -r requirements_api.txt
fi

# Activate venv and start server
echo "Starting Cursor Chat API Server..."
.venv/bin/python cursor_chat_api.py

