#!/bin/bash

# Blink Chat Viewer - Quick Start Script

echo "=================================================="
echo "  Blink Chat Viewer - Quick Start"
echo "=================================================="
echo ""

# Check if Python is available
if command -v python3 &> /dev/null; then
    echo "✓ Python 3 detected"
    echo ""
    echo "Starting web server on http://localhost:3000"
    echo "Make sure Rust backend is running on http://localhost:8067"
    echo "Press Ctrl+C to stop the server"
    echo ""
    echo "=================================================="
    echo ""
    
    # Open browser (optional)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open http://localhost:3000
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        xdg-open http://localhost:3000 2>/dev/null || echo "Please open http://localhost:3000 in your browser"
    fi
    
    # Start Python server
    python3 -m http.server 3000
else
    echo "✗ Python 3 not found"
    echo ""
    echo "Please install Python 3 or use another web server:"
    echo "  - npm: npx http-server -p 3000"
    echo "  - php: php -S localhost:3000"
    echo ""
    exit 1
fi

