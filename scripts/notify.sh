#!/bin/bash
# Claude Code Notifier - Plugin Hook
# Sends macOS popup notification when Claude Code stops.
# Optional Bark push to iPhone via BARK_KEY env var or config file.

# Read full JSON input from Claude Code hook (includes transcript_path)
input=$(cat)

# Extract the last assistant message from the transcript
message="Wait for Input"
transcript_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null)

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    extracted=$(python3 -c "
import json, sys, os
path = os.path.expanduser('$transcript_path')
try:
    last_text = None
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get('type') != 'assistant':
                continue
            msg = d.get('message', {})
            if msg.get('role') != 'assistant':
                continue
            content = msg.get('content', [])
            if not isinstance(content, list):
                continue
            for item in content:
                if item.get('type') == 'text':
                    text = item.get('text', '').strip()
                    if text:
                        last_text = text
    if last_text:
        # Collapse whitespace to a single line
        last_text = ' '.join(last_text.split())
        # Limit to ~100 chars
        if len(last_text) > 100:
            last_text = last_text[:97] + '...'
        print(last_text)
except Exception:
    pass
" 2>/dev/null)
    if [ -n "$extracted" ]; then
        message="$extracted"
    fi
fi

# Detect the terminal emulator that is running this shell.
find_terminal_bundle_id() {
    # Method 1: walk up the parent process chain
    local pid=$$
    while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
        local cmd
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null | sed 's/^-//' | xargs basename 2>/dev/null)
        case "$cmd" in
            Ghostty|ghostty) echo "com.mitchellh.ghostty"; return ;;
            iTerm2|iTerm|iTermServer*|iTermServer) echo "com.googlecode.iterm2"; return ;;
            Terminal) echo "com.apple.Terminal"; return ;;
            WezTerm|wezterm-gui) echo "com.github.wez.wezterm"; return ;;
            kitty) echo "net.kovidgoyal.kitty"; return ;;
            Alacritty|alacritty) echo "org.alacritty.Alacritty"; return ;;
            Hyper) echo "co.zeit.hyper"; return ;;
            Tabby) echo "com.eugeny.tabby"; return ;;
            Warp|warp) echo "dev.warp.Warp-Stable"; return ;;
            Code|Electron)
                local full_cmd
                full_cmd=$(ps -p "$pid" -o args= 2>/dev/null)
                case "$full_cmd" in
                    *Cursor*) echo "com.todesktop.230313mzl4w4u92"; return ;;
                    *"Visual Studio Code"*) echo "com.microsoft.VSCode"; return ;;
                esac
                ;;
        esac
        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
    done

    # Method 2: terminal-specific environment variables
    [ -n "${GHOSTTY_RESOURCES_DIR:-}" ] && echo "com.mitchellh.ghostty" && return
    [ -n "${ITERM_SESSION_ID:-}" ]     && echo "com.googlecode.iterm2" && return
    [ -n "${WARP_SESSION_ID:-}" ]      && echo "dev.warp.Warp-Stable" && return
    [ -n "${KITTY_WINDOW_ID:-}" ]      && echo "net.kovidgoyal.kitty" && return
    [ -n "${WEZTERM_PANE:-}" ]         && echo "com.github.wez.wezterm" && return

    # Method 3: generic TERM_PROGRAM
    [ -n "${TERM_PROGRAM:-}" ] && {
        case "$TERM_PROGRAM" in
            Apple_Terminal) echo "com.apple.Terminal" ;;
            iTerm.app)      echo "com.googlecode.iterm2" ;;
            vscode)         echo "com.microsoft.VSCode" ;;
        esac
        return
    }

    echo ""
}

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
APP_PATH="${PLUGIN_ROOT}/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier"

cwd=$(echo "$PWD" | sed "s|^$HOME|~|")
terminal_bundle_id=$(find_terminal_bundle_id)

# macOS popup (async)
"$APP_PATH" "Claude Code" "$cwd" "$message" "$terminal_bundle_id" &

# --- Optional Bark push to iPhone ---
BARK_CONFIG_DIR="$HOME/.claude/plugin-configs/claude-code-notifier"
BARK_CONFIG_FILE="$BARK_CONFIG_DIR/bark-key"
BARK_KEY="${BARK_KEY:-}"

if [ -z "$BARK_KEY" ] && [ -f "$BARK_CONFIG_FILE" ]; then
    BARK_KEY=$(cat "$BARK_CONFIG_FILE" | tr -d '\n')
fi

if [ -n "$BARK_KEY" ] && [ "$BARK_KEY" != "your-bark-key-here" ]; then
    ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/claude-code-notifier/main/assets/claudecode-color.png"
    env _CCN_MSG="$message" python3 -c "
import urllib.parse, os
msg = os.environ.get('_CCN_MSG', 'Wait for Input')
t='${BARK_KEY}'
path='/'+urllib.parse.quote(t)+'/'+urllib.parse.quote('Claude Code')+'/'+urllib.parse.quote(msg)+'?'+urllib.parse.urlencode({
    'subtitle': '${cwd}',
    'icon': '${ICON_URL}'
})
print('https://api.day.app'+path)
" | { read -r url; curl -fsS "$url" > /dev/null 2>&1; }
fi
