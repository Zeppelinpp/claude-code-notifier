#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClaudeCodeNotifier"
APP_SRC="$SCRIPT_DIR/${APP_NAME}.app"
APP_DST="$HOME/Applications/${APP_NAME}.app"
NOTIFY_DIR="$HOME/.claude/tools"
NOTIFY_SCRIPT="$NOTIFY_DIR/notify.sh"
SETTINGS="$HOME/.claude/settings.json"
ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/claude-code-notifier/main/assets/claudecode-color.png"

FORCE=false
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE=true
fi

echo "======================================"
echo "  Claude Code Notifier Installer"
echo "======================================"

# --- 1. Install app ---
if [ ! -d "$APP_SRC" ]; then
    echo "Error: ${APP_NAME}.app not found in $SCRIPT_DIR"
    exit 1
fi

echo ""
echo "Installing ${APP_NAME}.app -> ~/Applications/ ..."
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
echo "Done."

# --- 2. Create/update notify.sh ---
mkdir -p "$NOTIFY_DIR"

CREATE_NOTIFY=false
if [ "$FORCE" = true ]; then
    CREATE_NOTIFY=true
elif [ -f "$NOTIFY_SCRIPT" ]; then
    echo ""
    echo "Found existing notify.sh at $NOTIFY_SCRIPT"
    read -r -p "Overwrite? [y/N] " ans
    if [[ "$ans" == [yY]* ]]; then
        CREATE_NOTIFY=true
    else
        echo "Skipping notify.sh (keeping existing)."
    fi
else
    CREATE_NOTIFY=true
fi

if [ "$CREATE_NOTIFY" = true ]; then
    # Re-use existing Bark key if present
    BARK_KEY=""
    if [ -f "$NOTIFY_SCRIPT" ]; then
        BARK_KEY=$(grep -o 'BARK_KEY="[^"]*"' "$NOTIFY_SCRIPT" 2>/dev/null | head -1 | sed 's/BARK_KEY="//;s/"$//' || true)
    fi

    if [ -z "$BARK_KEY" ] || [ "$BARK_KEY" = "your-bark-key-here" ]; then
        if [ "$FORCE" = true ]; then
            BARK_KEY="your-bark-key-here"
        else
            echo ""
            echo "Bark push to iPhone (optional)."
            echo "  Get your device key from the Bark iOS app."
            read -r -p "Enter Bark key (press Enter to skip): " BARK_KEY
        fi
    else
        echo "Reusing existing Bark key from current notify.sh."
    fi

    if [ -z "$BARK_KEY" ]; then
        BARK_KEY="your-bark-key-here"
    fi

    cat > "$NOTIFY_SCRIPT" <<EOF
#!/bin/bash
# Claude Code notification hook: Mac popup + Bark push to iPhone

read -r input

cwd=\$(echo "\$PWD" | sed "s|^\$HOME|~|")

# Mac local popup (async)
~/Applications/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier \\
    "Claude Code" "\$cwd" "Wait for Input" &

# Bark push to iPhone
BARK_KEY="${BARK_KEY}"
ICON_URL="${ICON_URL}"

python3 -c "
import urllib.parse
t='\${BARK_KEY}'
path='/'+urllib.parse.quote(t)+'/'+urllib.parse.quote('Claude Code')+'/'+urllib.parse.quote('Wait for Input')+'?'+urllib.parse.urlencode({
    'subtitle': '\${cwd}',
    'icon': '\${ICON_URL}'
})
print('https://api.day.app'+path)
" | { read -r url; curl -fsS "\$url" > /dev/null 2>&1; }
EOF

    chmod +x "$NOTIFY_SCRIPT"
    echo "Created $NOTIFY_SCRIPT"
fi

# --- 3. Configure settings.json ---
echo ""
echo "Checking Claude Code settings.json ..."

if [ ! -f "$SETTINGS" ]; then
    mkdir -p "$(dirname "$SETTINGS")"
    echo '{}' > "$SETTINGS"
fi

python3 -c "
import json, sys, os

settings_path = '$SETTINGS'
cmd = '$NOTIFY_SCRIPT'

# Normalize paths for comparison: expand ~ and resolve
home = os.path.expanduser('~')
cmd_norm = os.path.normpath(os.path.expanduser(cmd))

try:
    with open(settings_path, 'r') as f:
        data = json.load(f)
except json.JSONDecodeError:
    data = {}

stop_hooks = data.setdefault('hooks', {}).setdefault('Stop', [])

def normalize_cmd(c):
    return os.path.normpath(os.path.expanduser(c))

exists = any(
    any(
        h.get('type') == 'command' and normalize_cmd(h.get('command', '')) == cmd_norm
        for h in entry.get('hooks', [])
    )
    for entry in stop_hooks
)

if exists:
    print('Stop hook already configured.')
else:
    # Also remove any duplicates with absolute path
    clean_hooks = []
    for entry in stop_hooks:
        entry_hooks = entry.get('hooks', [])
        new_hooks = [
            h for h in entry_hooks
            if not (h.get('type') == 'command' and normalize_cmd(h.get('command', '')) == cmd_norm)
        ]
        if new_hooks:
            clean_hooks.append({'hooks': new_hooks})

    clean_hooks.append({
        'hooks': [{
            'type': 'command',
            'command': cmd,
            'async': True
        }]
    })
    data['hooks']['Stop'] = clean_hooks

    with open(settings_path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('Added Stop hook to settings.json.')
"

echo ""
echo "======================================"
echo "  Installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. In Claude Code, run: /hooks"
echo "  2. Trigger a Stop event and enjoy your notifications."
echo ""
