# Claude Code Notifier

> Beautiful macOS popup + iPhone push notifications for Claude Code. Never miss when your AI finishes thinking.

[![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

When Claude Code stops responding — task complete, waiting for input, or session ended — this notifier delivers a sleek native macOS popup right on your active monitor. Pair it with [Bark](https://github.com/Finb/Bark) and the same alert lands on your iPhone instantly.

---

## ✨ Features

- **Native macOS Popup** — Frosted glass panel with continuous rounded corners, auto dark/light mode, and system Glass sound
- **Multi-Monitor Aware** — Appears on whichever screen your cursor is currently on
- **Click to Focus** — Click the notification to jump straight back to your Terminal / Tmux window
- **Hover to Dismiss** — Elegant close button fades in on hover
- **iPhone Sync** — Push to iPhone via [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) using APNs
- **Claude Branding** — Official Claude Code mascot icon, not the generic desktop app icon

---

## 📸 Preview

```
┌─────────────────────────────┐
│  [🟠]  Claude Code           │
│         Wait for Input        │
│         ~/projects/my-app     │
└─────────────────────────────┘
```

*Frosted glass panel matching your macOS theme, sliding in on the active desktop.*

---

## 🚀 Quick Start

### 1. Download & Install

```bash
# Clone this repository
git clone https://github.com/Zeppelinpp/claude-code-notifier.git

# Move the notifier app to your Applications folder
cp -R claude-code-notifier/ClaudeCodeNotifier.app ~/Applications/
```

### 2. Configure Claude Code Hook

Create a notification script (keep your private keys here, **not** in `settings.json`):

```bash
# ~/.claude/notify.sh
#!/bin/bash
read -r input
cwd=$(echo "$PWD" | sed "s|^$HOME|~|")

# macOS popup
~/Applications/ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier \
    "Claude Code" "$cwd" "Wait for Input" &

# Bark push to iPhone (optional)
BARK_KEY="your-bark-key-here"
ICON_URL="https://raw.githubusercontent.com/Zeppelinpp/claude-code-notifier/main/assets/claudecode-color.png"

python3 -c "
import urllib.parse
t='$BARK_KEY'
path='/'+urllib.parse.quote(t)+'/'+urllib.parse.quote('Claude Code')+'/'+urllib.parse.quote('Wait for Input')+'?'+urllib.parse.urlencode({
    'subtitle': '$cwd',
    'icon': '$ICON_URL'
})
print('https://api.day.app'+path)
" | { read -r url; curl -fsS \"\$url\" > /dev/null 2>&1; }
```

Make it executable:
```bash
chmod +x ~/.claude/notify.sh
```

Add the hook to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/notify.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

### 3. iPhone Push via Bark (Optional)

1. Install [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) on your iPhone
2. Open the app and copy your device key
3. Replace `your-bark-key-here` in `~/.claude/notify.sh`

For more Bark features, visit the [Bark GitHub repository](https://github.com/Finb/Bark).

### 4. Activate

In Claude Code, run `/hooks` once to reload configuration, or restart Claude Code.

---

## 📁 Repository Structure

```
claude-code-notifier/
├── assets/
│   └── claudecode-color.png    # Claude Code mascot icon
├── ClaudeCodeNotifier.app/     # Compiled macOS notifier app
├── README.md
└── README.zh.md
```

---

## 🙏 Credits

- [Bark](https://github.com/Finb/Bark) — Finb's open-source iOS push notification tool
- Claude Code — Anthropic's AI coding assistant

---

## License

MIT
