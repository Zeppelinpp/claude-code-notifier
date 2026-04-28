#!/bin/bash
# CodePing — Claude Code / Codex / Kimi CLI Notifier
# Sends native macOS popup + optional Bark push when the assistant stops.

# Read full JSON input from hook (includes transcript_path)
input=$(cat)

json_string_value() {
  key="$1"
  printf '%s' "$input" |
    tr '\n' ' ' |
    sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    sed 's/\\"/"/g; s/\\\\/\\/g; s/\\n/ /g; s/\\r/ /g; s/\\t/ /g' |
    head -1
}

json_has_key() {
  key="$1"
  printf '%s' "$input" | tr '\n' ' ' | grep -Eq '"'"$key"'"[[:space:]]*:'
}

collapse_text() {
  tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/^(.{100}).+$/\1.../'
}

json_line_string_value() {
  key="$1"
  sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    sed 's/\\"/"/g; s/\\\\/\\/g; s/\\n/ /g; s/\\r/ /g; s/\\t/ /g' |
    tail -1
}

extract_last_assistant_from_transcript() {
  path="$1"
  [ -f "$path" ] || return 0
  awk '
    /"role"[[:space:]]*:[[:space:]]*"assistant"/ && /"text"[[:space:]]*:/ { last=$0 }
    END { if (last) print last }
  ' "$path" | json_line_string_value "text" | collapse_text
}

extract_last_kimi_message() {
  path="$1"
  [ -f "$path" ] || return 0
  line=$(
    awk '
      /"type"[[:space:]]*:[[:space:]]*"ContentPart"/ && /"text"[[:space:]]*:/ { last=$0 }
      /"type"[[:space:]]*:[[:space:]]*"ContentPart"/ && /"think"[[:space:]]*:/ && !last { last=$0 }
      END { if (last) print last }
    ' "$path"
  )
  text=$(printf '%s' "$line" | json_line_string_value "text")
  if [ -z "$text" ]; then
    text=$(printf '%s' "$line" | json_line_string_value "think")
  fi
  printf '%s' "$text" | collapse_text
}

json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Extract the last assistant message from the transcript
message="Wait for Input"

# Try 1: Use last_assistant_message from hook JSON directly (if provided)
hook_message=$(json_string_value "last_assistant_message")
if [ -n "$hook_message" ] && [ "$hook_message" != "null" ]; then
  message="$hook_message"
else
  # Try 2: Parse transcript file
  transcript_path=$(json_string_value "transcript_path")

  if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    extracted=$(extract_last_assistant_from_transcript "$transcript_path")
    if [ -n "$extracted" ]; then
      message="$extracted"
    fi
  fi

  # Try 3: Kimi CLI — parse wire.jsonl from ~/.kimi/sessions/
  if [ "$message" = "Wait for Input" ]; then
    hook_event_name=$(json_string_value "hook_event_name")
    if [ "$hook_event_name" = "Stop" ]; then
      # Try to locate the wire.jsonl for this session
      wire_path=""
      # First: check if hook input provides a session_id
      session_id=$(json_string_value "session_id")
      if [ -n "$session_id" ]; then
        # Search for this session under ~/.kimi/sessions/
        found=$(find ~/.kimi/sessions -name "wire.jsonl" -path "*/${session_id}/*" 2>/dev/null | head -1)
        [ -n "$found" ] && wire_path="$found"
      fi
      # Fallback: find the most recently modified wire.jsonl
      if [ -z "$wire_path" ]; then
        found=$(find ~/.kimi/sessions -name "wire.jsonl" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
        [ -n "$found" ] && wire_path="$found"
      fi
      if [ -n "$wire_path" ] && [ -f "$wire_path" ]; then
        extracted=$(extract_last_kimi_message "$wire_path")
        if [ -n "$extracted" ]; then
          message="$extracted"
        fi
      fi
    fi
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
    Ghostty | ghostty)
      echo "com.mitchellh.ghostty"
      return
      ;;
    iTerm2 | iTerm | iTermServer* | iTermServer)
      echo "com.googlecode.iterm2"
      return
      ;;
    Terminal)
      echo "com.apple.Terminal"
      return
      ;;
    WezTerm | wezterm-gui)
      echo "com.github.wez.wezterm"
      return
      ;;
    kitty)
      echo "net.kovidgoyal.kitty"
      return
      ;;
    Alacritty | alacritty)
      echo "org.alacritty.Alacritty"
      return
      ;;
    Hyper)
      echo "co.zeit.hyper"
      return
      ;;
    Tabby)
      echo "com.eugeny.tabby"
      return
      ;;
    Warp | warp)
      echo "dev.warp.Warp-Stable"
      return
      ;;
    Code | Electron)
      local full_cmd
      full_cmd=$(ps -p "$pid" -o args= 2>/dev/null)
      case "$full_cmd" in
      *Cursor*)
        echo "com.todesktop.230313mzl4w4u92"
        return
        ;;
      *"Visual Studio Code"*)
        echo "com.microsoft.VSCode"
        return
        ;;
      esac
      ;;
    esac
    pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
  done

  # Method 2: terminal-specific environment variables
  [ -n "${GHOSTTY_RESOURCES_DIR:-}" ] && echo "com.mitchellh.ghostty" && return
  [ -n "${ITERM_SESSION_ID:-}" ] && echo "com.googlecode.iterm2" && return
  [ -n "${WARP_SESSION_ID:-}" ] && echo "dev.warp.Warp-Stable" && return
  [ -n "${KITTY_WINDOW_ID:-}" ] && echo "net.kovidgoyal.kitty" && return
  [ -n "${WEZTERM_PANE:-}" ] && echo "com.github.wez.wezterm" && return

  # Method 3: generic TERM_PROGRAM
  [ -n "${TERM_PROGRAM:-}" ] && {
    case "$TERM_PROGRAM" in
    Apple_Terminal) echo "com.apple.Terminal" ;;
    iTerm.app) echo "com.googlecode.iterm2" ;;
    vscode) echo "com.microsoft.VSCode" ;;
    esac
    return
  }

  echo ""
}

# Resolve plugin root before using it for assets
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
APP_PATH="${PLUGIN_ROOT}/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier"

# Detect which CLI invoked this hook and set title/icon accordingly
CLI_NAME="Claude Code"
ICON_PATH=""
BARK_ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/CodePing/main/assets/claudecode-color.png"

if [ -n "${CODEX_PLUGIN_ROOT:-}" ]; then
  # Codex plugin mode
  CLI_NAME="Codex"
  ICON_PATH="${PLUGIN_ROOT}/assets/codex-color.png"
  BARK_ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/CodePing/main/assets/codex-color.png"
elif [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  # Not Claude Code — check the hook payload shape before falling back to Kimi.
  hook_event_name=$(json_string_value "hook_event_name")
  transcript_path=$(json_string_value "transcript_path")
  codex_payload="false"
  if json_has_key "model" || json_has_key "permission_mode" || json_has_key "turn_id" || json_has_key "stop_hook_active" || printf '%s' "$transcript_path" | grep -q '/.codex/sessions/'; then
    codex_payload="true"
  fi
  if [ "$codex_payload" = "true" ]; then
    CLI_NAME="Codex"
    ICON_PATH="${PLUGIN_ROOT}/assets/codex-color.png"
    BARK_ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/CodePing/main/assets/codex-color.png"
  elif [ "$hook_event_name" = "Stop" ]; then
    CLI_NAME="Kimi"
    ICON_PATH="${PLUGIN_ROOT}/assets/kimi-color.png"
    BARK_ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/CodePing/main/assets/kimi-color.png"
  fi
fi

cwd=$(echo "$PWD" | sed "s|^$HOME|~|")
terminal_bundle_id=$(find_terminal_bundle_id)

# macOS popup (async)
"$APP_PATH" "$CLI_NAME" "$cwd" "$message" "$terminal_bundle_id" "$ICON_PATH" &

# --- Optional Bark push to iPhone ---
BARK_CONFIG_FILES=(
  "$HOME/.codex/plugin-configs/codeping/bark-key"
  "$HOME/.claude/plugin-configs/claude-code-notifier/bark-key"
)
BARK_KEY="${BARK_KEY:-}"

if [ -z "$BARK_KEY" ]; then
  for config_file in "${BARK_CONFIG_FILES[@]}"; do
    if [ -f "$config_file" ]; then
      BARK_KEY=$(cat "$config_file" | tr -d '\n')
      [ -n "$BARK_KEY" ] && break
    fi
  done
fi

if [ -n "$BARK_KEY" ] && [ "$BARK_KEY" != "your-bark-key-here" ]; then
  bark_payload=$(printf '{"device_key":"%s","title":"%s","markdown":"%s","subtitle":"%s","icon":"%s"}' \
    "$(printf '%s' "$BARK_KEY" | json_escape)" \
    "$(printf '%s' "$CLI_NAME" | json_escape)" \
    "$(printf '%s' "$message" | json_escape)" \
    "$(printf '%s' "$cwd" | json_escape)" \
    "$(printf '%s' "$BARK_ICON_URL" | json_escape)")
  curl -fsS -m 10 \
    -H 'Content-Type: application/json' \
    -d "$bark_payload" \
    https://api.day.app/push >/dev/null 2>&1 || true
fi
