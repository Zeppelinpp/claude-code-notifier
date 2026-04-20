#!/bin/bash
# Claude Code Notifier - Plugin Hook
# Sends macOS popup notification when Claude Code stops.
# Optional Bark push to iPhone via BARK_KEY env var or config file.

read -r input

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
APP_PATH="${PLUGIN_ROOT}/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier"

cwd=$(echo "$PWD" | sed "s|^$HOME|~|")

# macOS popup (async)
"$APP_PATH" "Claude Code" "$cwd" "Wait for Input" &

# --- Optional Bark push to iPhone ---
BARK_CONFIG_DIR="$HOME/.claude/plugin-configs/claude-code-notifier"
BARK_CONFIG_FILE="$BARK_CONFIG_DIR/bark-key"
BARK_KEY="${BARK_KEY:-}"

if [ -z "$BARK_KEY" ] && [ -f "$BARK_CONFIG_FILE" ]; then
    BARK_KEY=$(cat "$BARK_CONFIG_FILE" | tr -d '\n')
fi

if [ -n "$BARK_KEY" ] && [ "$BARK_KEY" != "your-bark-key-here" ]; then
    ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/claude-code-notifier/main/assets/claudecode-color.png"
    python3 -c "
import urllib.parse
t='${BARK_KEY}'
path='/'+urllib.parse.quote(t)+'/'+urllib.parse.quote('Claude Code')+'/'+urllib.parse.quote('Wait for Input')+'?'+urllib.parse.urlencode({
    'subtitle': '${cwd}',
    'icon': '${ICON_URL}'
})
print('https://api.day.app'+path)
" | { read -r url; curl -fsS "$url" > /dev/null 2>&1; }
fi
