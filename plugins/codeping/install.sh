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
BARK_CONFIG_DIR="$HOME/.claude/plugin-configs/claude-code-notifier"
BARK_CONFIG_FILE="$BARK_CONFIG_DIR/bark-key"

usage() {
    echo "Claude Code Notifier Installer"
    echo ""
    echo "Usage:"
    echo "  ./install.sh              Full install (app + legacy hook + Bark config)"
    echo "  ./install.sh --force      Full install, auto-overwrite"
    echo "  ./install.sh --bark-only  Only configure Bark key"
    echo "  ./install.sh --uninstall  Remove legacy settings.json hook"
    echo ""
    echo "Plugin users: install the plugin via '/plugin install', then run:"
    echo "  ./install.sh --bark-only"
    exit 0
}

FORCE=false
BARK_ONLY=false
UNINSTALL=false

for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --bark-only) BARK_ONLY=true ;;
        --uninstall) UNINSTALL=true ;;
        --help|-h) usage ;;
    esac
done

# --- Uninstall mode: clean legacy settings.json hook ---
if [ "$UNINSTALL" = true ]; then
    echo "Removing legacy hook from $SETTINGS ..."
    if [ -f "$SETTINGS" ]; then
        python3 -c "
import json, os

settings_path = '$SETTINGS'
cmd = '$NOTIFY_SCRIPT'
home = os.path.expanduser('~')
cmd_norm = os.path.normpath(os.path.expanduser(cmd))

try:
    with open(settings_path, 'r') as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    print('No settings.json found.')
    exit(0)

if 'hooks' not in data or 'Stop' not in data.get('hooks', {}):
    print('No Stop hook found.')
    exit(0)

def normalize_cmd(c):
    return os.path.normpath(os.path.expanduser(c))

old_hooks = data['hooks']['Stop']
new_hooks = []
for entry in old_hooks:
    entry_hooks = entry.get('hooks', [])
    filtered = [
        h for h in entry_hooks
        if not (h.get('type') == 'command' and normalize_cmd(h.get('command', '')) == cmd_norm)
    ]
    if filtered:
        new_hooks.append({'hooks': filtered})

if new_hooks:
    data['hooks']['Stop'] = new_hooks
else:
    del data['hooks']['Stop']
    if not data['hooks']:
        del data['hooks']

with open(settings_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Legacy hook removed.')
"
    fi
    exit 0
fi

# --- Bark-only mode: just configure Bark key ---
if [ "$BARK_ONLY" = true ]; then
    echo "Claude Code Notifier - Bark Configuration"
    echo "========================================="
    echo ""

    CURRENT=""
    if [ -f "$BARK_CONFIG_FILE" ]; then
        CURRENT=$(cat "$BARK_CONFIG_FILE" | tr -d '\n')
        echo "Current Bark key: ${CURRENT:0:8}..."
    fi

    read -r -p "Enter Bark device key (press Enter to keep / skip): " NEW_KEY

    if [ -n "$NEW_KEY" ]; then
        mkdir -p "$BARK_CONFIG_DIR"
        echo -n "$NEW_KEY" > "$BARK_CONFIG_FILE"
        chmod 600 "$BARK_CONFIG_FILE"
        echo "Bark key saved to $BARK_CONFIG_FILE"
    else
        echo "No change."
    fi
    exit 0
fi

# --- Full install mode ---
echo "======================================"
echo "  Claude Code Notifier Installer"
echo "======================================"

# 1. Install app
if [ ! -d "$APP_SRC" ]; then
    echo "Error: ${APP_NAME}.app not found in $SCRIPT_DIR"
    exit 1
fi

echo ""
echo "Installing ${APP_NAME}.app -> ~/Applications/ ..."
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
echo "Done."

# 2. Create/update notify.sh (legacy, for non-plugin users)
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
~/Applications/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier \
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

# 3. Configure Bark key (also saves to plugin config location)
echo ""
read -r -p "Save Bark key for plugin mode too? [y/N] " SAVE_FOR_PLUGIN
if [[ "$SAVE_FOR_PLUGIN" == [yY]* ]]; then
    BARK_KEY_VALUE=""
    if [ -f "$NOTIFY_SCRIPT" ]; then
        BARK_KEY_VALUE=$(grep -o 'BARK_KEY="[^"]*"' "$NOTIFY_SCRIPT" 2>/dev/null | head -1 | sed 's/BARK_KEY="//;s/"$//' || true)
    fi
    if [ -n "$BARK_KEY_VALUE" ] && [ "$BARK_KEY_VALUE" != "your-bark-key-here" ]; then
        mkdir -p "$BARK_CONFIG_DIR"
        echo -n "$BARK_KEY_VALUE" > "$BARK_CONFIG_FILE"
        chmod 600 "$BARK_CONFIG_FILE"
        echo "Bark key saved to plugin config: $BARK_CONFIG_FILE"
    fi
fi

# 4. Configure legacy settings.json hook (for non-plugin users)
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
    print('Legacy Stop hook already configured.')
    print('Tip: If you use the plugin, run ./install.sh --uninstall to remove the legacy hook.')
else:
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
    print('Added legacy Stop hook to settings.json.')
    print('Tip: Consider using the plugin (/plugin install) instead of the legacy hook.')
"

echo ""
echo "======================================"
echo "  Installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. In Claude Code, run: /hooks"
echo "  2. Trigger a Stop event and enjoy."
echo ""
echo "For plugin mode (recommended):"
echo "  ./install.sh --uninstall   # remove legacy hook"
echo "  Then use /plugin install in Claude Code"
echo ""
