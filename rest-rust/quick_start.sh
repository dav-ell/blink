#!/bin/bash
set -e

echo "🚀 Blink Rust Server - Quick Start"
echo "=================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from Python config..."
    if [ -f ../rest/.env ]; then
        cp ../rest/.env .env
        echo "✅ Copied .env from ../rest/"
    else
        echo "❌ No .env file found in ../rest/ either"
        echo "Please create a .env file with:"
        echo "  DB_PATH=/path/to/cursor.db"
        echo "  CURSOR_AGENT_PATH=/path/to/cursor-agent"
        exit 1
    fi
fi

echo "📦 Building release binaries..."
cargo build --release

echo ""
echo "✅ Build complete!"
echo ""
echo "Available binaries:"
echo "  - ./target/release/blink-api  (REST API server)"
echo "  - ./target/release/blink-cli  (CLI wrapper)"
echo "  - ./target/release/blink-mcp  (MCP server)"
echo ""
echo "To start the REST API server:"
echo "  ./target/release/blink-api"
echo ""
echo "To use the CLI:"
echo "  ./target/release/blink-cli --help"
echo ""
echo "To start the MCP server:"
echo "  ./target/release/blink-mcp"
echo ""
