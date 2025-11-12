#!/bin/bash
# Start the Cursor Chat REST API Server

cd "$(dirname "$0")"

# Load direnv if available
if command -v direnv &> /dev/null; then
    eval "$(direnv export bash 2>/dev/null)"
fi

# Check if venv exists
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
    echo "Installing dependencies..."
    uv pip install -r requirements.txt
fi

# Activate venv if not already active
if [ -z "$VIRTUAL_ENV" ]; then
    source .venv/bin/activate
fi

# Start server using new package structure
echo "Starting Cursor Chat API Server..."
echo "API will be available at http://localhost:8000"
echo "Documentation at http://localhost:8000/docs"
echo ""

.venv/bin/python -m cursor_api.main

