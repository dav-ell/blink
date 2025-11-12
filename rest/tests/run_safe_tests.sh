#!/bin/bash
# Safe test runner with database backup/restore
set -e

cd "$(dirname "$0")/.."

# Configuration
DB_PATH="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
BACKUP_PATH="/tmp/cursor_db_backup_$(date +%Y%m%d_%H%M%S).vscdb"
LOCK_FILE="/tmp/cursor_test.lock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Safe Test Runner with DB Backup"
echo "=========================================="

# Function to check if Cursor is running
check_cursor_running() {
    if pgrep -x "Cursor" > /dev/null; then
        echo -e "${RED}ERROR: Cursor is currently running!${NC}"
        echo "Please close Cursor before running tests that modify the database."
        echo "Tests that only read from the database can run with Cursor open."
        return 1
    fi
    return 0
}

# Function to backup database
backup_database() {
    if [ -f "$DB_PATH" ]; then
        echo -e "${YELLOW}Backing up database...${NC}"
        cp "$DB_PATH" "$BACKUP_PATH"
        echo -e "${GREEN}✓ Database backed up to: $BACKUP_PATH${NC}"
        return 0
    else
        echo -e "${RED}ERROR: Database not found at: $DB_PATH${NC}"
        return 1
    fi
}

# Function to restore database
restore_database() {
    if [ -f "$BACKUP_PATH" ]; then
        echo -e "${YELLOW}Restoring database from backup...${NC}"
        cp "$BACKUP_PATH" "$DB_PATH"
        echo -e "${GREEN}✓ Database restored${NC}"
        rm "$BACKUP_PATH"
        echo -e "${GREEN}✓ Backup file cleaned up${NC}"
        return 0
    else
        echo -e "${YELLOW}No backup file found, skipping restore${NC}"
        return 1
    fi
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    echo ""
    echo "=========================================="
    echo "Cleaning up..."
    echo "=========================================="
    
    # Remove lock file
    rm -f "$LOCK_FILE"
    
    # Restore database if backup exists
    if [ -f "$BACKUP_PATH" ]; then
        restore_database
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ All tests completed successfully${NC}"
    else
        echo -e "${RED}✗ Tests failed with exit code: $exit_code${NC}"
    fi
    
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Check if tests modify database
WRITE_TESTS="test_agent_sync.py test_agent_async.py test_e2e_workflows.py test_existing_chat_integration.py"
RUN_MODE="${1:-all}"

if [ "$RUN_MODE" = "write" ] || [ "$RUN_MODE" = "all" ]; then
    echo "Tests will modify database - checking if Cursor is running..."
    if ! check_cursor_running; then
        exit 1
    fi
    
    echo "Creating database backup..."
    if ! backup_database; then
        exit 1
    fi
    
    # Create lock file
    touch "$LOCK_FILE"
fi

# Activate virtual environment
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi

echo ""
echo "=========================================="
echo "Running Tests"
echo "=========================================="

# Run tests based on mode
case "$RUN_MODE" in
    "read")
        echo "Running read-only tests..."
        pytest tests/test_api.py tests/test_batch_info.py tests/test_summary_endpoint.py -v
        ;;
    "write")
        echo "Running tests that modify database..."
        pytest tests/test_agent_sync.py tests/test_agent_async.py tests/test_e2e_workflows.py -v
        ;;
    "all")
        echo "Running all tests..."
        pytest tests/ -v
        ;;
    *)
        echo "Usage: $0 [read|write|all]"
        echo "  read  - Run only read-only tests (safe with Cursor open)"
        echo "  write - Run tests that modify database (requires Cursor closed)"
        echo "  all   - Run all tests (requires Cursor closed)"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Test run complete!"
echo "=========================================="

