#!/bin/bash
#
# Installation script for Remote Agent Service
# This script installs the remote agent service on a machine
# Usage: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="remote-agent-service"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/remote-agent-service"
SERVICE_USER=$(whoami)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Remote Agent Service Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root for system-wide install
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Service will be installed system-wide.${NC}"
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/remote-agent-service"
else
    echo -e "${GREEN}Installing as user: $SERVICE_USER${NC}"
fi

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}✗ Rust/Cargo not found${NC}"
    echo -e "${YELLOW}Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "${GREEN}✓ Rust installed${NC}"
else
    echo -e "${GREEN}✓ Rust/Cargo found: $(cargo --version)${NC}"
fi

# Check if cursor-agent is installed
if ! command -v cursor-agent &> /dev/null && ! [ -f "$HOME/.local/bin/cursor-agent" ]; then
    echo -e "${YELLOW}⚠ cursor-agent not found${NC}"
    echo -e "${YELLOW}You'll need to install cursor-agent separately${NC}"
    echo -e "${YELLOW}Visit: https://cursor.com${NC}"
else
    echo -e "${GREEN}✓ cursor-agent found${NC}"
fi

echo ""

# Build the service
echo -e "${BLUE}Building Remote Agent Service...${NC}"

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

# Clone or copy the source (adjust URL as needed)
if [ -d "/Users/davell/Documents/github/blink/remote-agent-service" ]; then
    echo "Using local source..."
    cp -r /Users/davell/Documents/github/blink/remote-agent-service/* .
else
    echo "Cloning from repository..."
    git clone https://github.com/your-repo/blink.git
    cd blink/remote-agent-service
fi

# Build release binary
echo -e "${YELLOW}Compiling (this may take a few minutes)...${NC}"
cargo build --release

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Install binary
echo -e "${BLUE}Installing binary...${NC}"
sudo cp target/release/remote-agent-service "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/remote-agent-service"
echo -e "${GREEN}✓ Binary installed to $INSTALL_DIR/remote-agent-service${NC}"
echo ""

# Setup configuration
echo -e "${BLUE}Setting up configuration...${NC}"
mkdir -p "$CONFIG_DIR"

# Generate API key if not exists
if [ ! -f "$CONFIG_DIR/api_key" ]; then
    API_KEY=$(openssl rand -hex 32)
    echo "$API_KEY" > "$CONFIG_DIR/api_key"
    chmod 600 "$CONFIG_DIR/api_key"
    echo -e "${GREEN}✓ Generated new API key${NC}"
else
    API_KEY=$(cat "$CONFIG_DIR/api_key")
    echo -e "${GREEN}✓ Using existing API key${NC}"
fi

# Create .env file
cat > "$CONFIG_DIR/.env" << EOF
# Remote Agent Service Configuration
HOST=0.0.0.0
PORT=9876
CURSOR_AGENT_PATH=$HOME/.local/bin/cursor-agent
API_KEY=$API_KEY
EXECUTION_TIMEOUT=300
EOF

echo -e "${GREEN}✓ Configuration created at $CONFIG_DIR/.env${NC}"
echo ""

# Install as service
echo -e "${BLUE}Installing as service...${NC}"

# Detect init system
if command -v systemctl &> /dev/null; then
    echo "Detected systemd"
    
    # Create systemd service file
    sudo tee /etc/systemd/system/remote-agent.service > /dev/null << EOF
[Unit]
Description=Remote Agent Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$CONFIG_DIR
EnvironmentFile=$CONFIG_DIR/.env
ExecStart=$INSTALL_DIR/remote-agent-service
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable remote-agent
    
    echo -e "${GREEN}✓ Systemd service installed${NC}"
    echo ""
    echo -e "${BLUE}Starting service...${NC}"
    sudo systemctl start remote-agent
    
    # Check status
    sleep 2
    if sudo systemctl is-active --quiet remote-agent; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Service failed to start${NC}"
        echo -e "${YELLOW}Check logs with: sudo journalctl -u remote-agent -f${NC}"
    fi

elif command -v launchctl &> /dev/null; then
    echo "Detected launchd (macOS)"
    
    PLIST_PATH="$HOME/Library/LaunchAgents/com.remote-agent-service.plist"
    
    # Create launchd plist
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.remote-agent-service</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/remote-agent-service</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$CONFIG_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>API_KEY</key>
        <string>$API_KEY</string>
        <key>HOST</key>
        <string>0.0.0.0</string>
        <key>PORT</key>
        <string>9876</string>
        <key>CURSOR_AGENT_PATH</key>
        <string>$HOME/.local/bin/cursor-agent</string>
        <key>EXECUTION_TIMEOUT</key>
        <string>300</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/remote-agent.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/remote-agent.err</string>
</dict>
</plist>
EOF

    # Load and start service
    launchctl load "$PLIST_PATH"
    launchctl start com.remote-agent-service
    
    echo -e "${GREEN}✓ Launchd service installed${NC}"
    echo ""
    echo -e "${BLUE}Checking service...${NC}"
    sleep 2
    
    if launchctl list | grep -q com.remote-agent-service; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Service failed to start${NC}"
        echo -e "${YELLOW}Check logs at: /tmp/remote-agent.log${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No supported init system found${NC}"
    echo -e "${YELLOW}You'll need to start the service manually:${NC}"
    echo -e "${YELLOW}  cd $CONFIG_DIR && $INSTALL_DIR/remote-agent-service${NC}"
fi

# Cleanup
cd /
rm -rf "$BUILD_DIR"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Service Details:${NC}"
echo -e "  Endpoint: ${YELLOW}http://$(hostname):9876${NC}"
echo -e "  API Key: ${YELLOW}$API_KEY${NC}"
echo -e "  Config: ${YELLOW}$CONFIG_DIR/.env${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Save your API key (shown above)"
echo "  2. Test the service:"
echo -e "     ${YELLOW}curl http://localhost:9876/health${NC}"
echo "  3. Add this device to your orchestrator with:"
echo -e "     ${YELLOW}Endpoint: http://YOUR_IP:9876${NC}"
echo -e "     ${YELLOW}API Key: $API_KEY${NC}"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"

if command -v systemctl &> /dev/null; then
    echo -e "  Status:  ${YELLOW}sudo systemctl status remote-agent${NC}"
    echo -e "  Logs:    ${YELLOW}sudo journalctl -u remote-agent -f${NC}"
    echo -e "  Restart: ${YELLOW}sudo systemctl restart remote-agent${NC}"
    echo -e "  Stop:    ${YELLOW}sudo systemctl stop remote-agent${NC}"
elif command -v launchctl &> /dev/null; then
    echo -e "  Status:  ${YELLOW}launchctl list | grep remote-agent${NC}"
    echo -e "  Logs:    ${YELLOW}tail -f /tmp/remote-agent.log${NC}"
    echo -e "  Restart: ${YELLOW}launchctl kickstart -k gui/\$(id -u)/com.remote-agent-service${NC}"
    echo -e "  Stop:    ${YELLOW}launchctl stop com.remote-agent-service${NC}"
fi

echo ""
echo -e "${GREEN}Happy remote coding! 🚀${NC}"

