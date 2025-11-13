#!/bin/bash
# Fake cursor-agent for testing
# Returns valid stream-json format responses

set -e

# Parse command line arguments
COMMAND=""
CHAT_ID=""
PROMPT=""
MODEL="sonnet-4.5-thinking"

while [[ $# -gt 0 ]]; do
    case $1 in
        --create-chat)
            COMMAND="create-chat"
            shift
            ;;
        --resume)
            CHAT_ID="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --print|--force)
            shift
            ;;
        --output-format)
            shift 2
            ;;
        --working-directory)
            shift 2
            ;;
        --version)
            echo "cursor-agent 1.0.0-test"
            exit 0
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Simulate different responses based on command
if [ "$COMMAND" = "create-chat" ]; then
    # Return a new chat ID
    CHAT_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    echo "{\"type\":\"chat_created\",\"chat_id\":\"$CHAT_ID\"}"
    echo "$CHAT_ID"
elif [ -n "$CHAT_ID" ] && [ -n "$PROMPT" ]; then
    # Simulate agent response in stream-json format
    echo "{\"type\":\"text\",\"text\":\"This is a test response to: $PROMPT\"}"
    echo "{\"type\":\"done\"}"
else
    echo "Error: Invalid arguments" >&2
    exit 1
fi

