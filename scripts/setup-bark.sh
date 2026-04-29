#!/bin/bash
# Interactive Bark key configuration for CodePing plugin

CLAUDE_CONFIG_DIR="$HOME/.claude/plugin-configs/claude-code-notifier"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/bark-key"

CODEX_CONFIG_DIR="$HOME/.codex/plugin-configs/codeping"
CODEX_CONFIG_FILE="$CODEX_CONFIG_DIR/bark-key"

echo "CodePing - Bark Setup"
echo "====================="
echo ""
echo "Bark is an open-source iOS push notification app."
echo "  App Store: https://apps.apple.com/app/bark-customed-notifications/id1403753865"
echo "  GitHub:    https://github.com/Finb/Bark"
echo ""

CURRENT=""
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    CURRENT=$(cat "$CLAUDE_CONFIG_FILE" | tr -d '\n')
    echo "Current Bark key: ${CURRENT:0:8}..."
fi

read -r -p "Enter your Bark device key (press Enter to keep current / skip): " NEW_KEY

if [ -n "$NEW_KEY" ]; then
    mkdir -p "$CLAUDE_CONFIG_DIR"
    echo -n "$NEW_KEY" > "$CLAUDE_CONFIG_FILE"
    chmod 600 "$CLAUDE_CONFIG_FILE"

    mkdir -p "$CODEX_CONFIG_DIR"
    echo -n "$NEW_KEY" > "$CODEX_CONFIG_FILE"
    chmod 600 "$CODEX_CONFIG_FILE"

    echo "Bark key saved to:"
    echo "  - $CLAUDE_CONFIG_FILE"
    echo "  - $CODEX_CONFIG_FILE"
else
    echo "No change made."
fi

echo ""
echo "You can also set BARK_KEY as an environment variable for temporary use."
