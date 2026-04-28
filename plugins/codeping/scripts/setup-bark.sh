#!/bin/bash
# Interactive Bark key configuration for Claude Code Notifier plugin

CONFIG_DIR="$HOME/.claude/plugin-configs/claude-code-notifier"
CONFIG_FILE="$CONFIG_DIR/bark-key"

echo "Claude Code Notifier - Bark Setup"
echo "=================================="
echo ""
echo "Bark is an open-source iOS push notification app."
echo "  App Store: https://apps.apple.com/app/bark-customed-notifications/id1403753865"
echo "  GitHub:    https://github.com/Finb/Bark"
echo ""

CURRENT=""
if [ -f "$CONFIG_FILE" ]; then
    CURRENT=$(cat "$CONFIG_FILE" | tr -d '\n')
    echo "Current Bark key: ${CURRENT:0:8}..."
fi

read -r -p "Enter your Bark device key (press Enter to keep current / skip): " NEW_KEY

if [ -n "$NEW_KEY" ]; then
    mkdir -p "$CONFIG_DIR"
    echo -n "$NEW_KEY" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "Bark key saved to $CONFIG_FILE"
else
    echo "No change made."
fi

echo ""
echo "You can also set BARK_KEY as an environment variable for temporary use."
