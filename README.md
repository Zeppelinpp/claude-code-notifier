# CodePing

> Beautiful macOS popup + iPhone push notifications for AI coding agents. Never miss when your AI finishes thinking.

[![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[English](README.md) · [中文](README.zh.md)

When your AI coding agent stops responding — task complete, waiting for input, or session ended — CodePing delivers a sleek native macOS popup right on your active monitor. Pair it with [Bark](https://github.com/Finb/Bark) and the same alert lands on your iPhone instantly.

**Supported agents:** [Claude Code](https://claude.ai/code) · [Kimi CLI](https://platform.kimi.com/)

---

## ✨ Features

- **Multi-CLI Support** — Auto-detects Claude Code, Kimi CLI, and more coming
- **Per-CLI Branding** — Each agent gets its own icon in the popup and on your iPhone
- **Native macOS Popup** — Frosted glass panel with continuous rounded corners, auto dark/light mode, and system Glass sound
- **Multi-Monitor Aware** — Appears on whichever screen your cursor is currently on
- **Click to Focus** — Click the notification to jump straight back to the terminal app you were using (Ghostty, iTerm2, Terminal.app, etc.)
- **Hover to Dismiss** — Elegant close button fades in on hover
- **iPhone Sync** — Push to iPhone via [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) using APNs

---

## 📸 Preview

![Claude Code Preview](assets/Claude-Code-Preview.png)
![Kimi Preview](assets/Kimi-Preview.png)

*Frosted glass panel matching your macOS theme, sliding in on the active desktop. Icon switches automatically based on which CLI triggered it.*

---

## 🚀 Quick Start

<details open>
<summary><b>Claude Code (Plugin)</b></summary>

Register this repository as a marketplace in your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "extraKnownMarketplaces": {
    "zeppelinpp": {
      "source": {
        "source": "github",
        "repo": "Zeppelinpp/CodePing"
      }
    }
  }
}
```

Then install the plugin inside Claude Code:

```
/plugin install codeping@zeppelinpp
```

</details>

<details>
<summary><b>Kimi CLI (Hook)</b></summary>

Add to your Kimi CLI config (`~/.kimi/config.toml`):

```toml
[[hooks]]
event = "Stop"
command = "/absolute/path/to/CodePing/scripts/notify.sh"
matcher = ""
timeout = 30
```

Replace `/absolute/path/to/CodePing` with the actual path where you cloned this repository.

</details>

### Configure Bark (Optional)

To enable iPhone push notifications, run the built-in setup skill inside Claude Code:

```
/bark-setup
```

Claude will ask for your Bark device key and save it automatically. No manual file editing needed.

Or set the environment variable:

```bash
export BARK_KEY="your-bark-key-here"
```

1. Install [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) on your iPhone
2. Open the app and copy your device key
3. Run `/bark-setup` in Claude Code and paste your key

For more Bark features, visit the [Bark GitHub repository](https://github.com/Finb/Bark).

---

## 🔧 Manual Install (Legacy)

If you prefer not to use the plugin system, use the standalone installer:

```bash
cd CodePing
./install.sh          # interactive: asks before overwriting
./install.sh --force  # non-interactive: auto-overwrite for updates
```

This copies the app to `~/Applications/`, creates `~/.claude/tools/notify.sh`, and adds a hook to `settings.json`.

To migrate from legacy hook to plugin mode:

```bash
./install.sh --uninstall   # removes legacy settings.json hook
# then use /plugin install inside Claude Code
```

---

## 🔨 Build from Source

The precompiled `ClaudeCodeNotifier.app` works out of the box, but you can customize the popup and rebuild:

```bash
cd src
swiftc popup.swift -o ClaudeCodeNotifier
```

Then replace the binary in the app bundle:

```bash
cp ClaudeCodeNotifier ../ClaudeCodeNotifier.app/Contents/MacOS/
```

Requires macOS 11.0+ and Swift toolchain. Key things you might customize in `popup.swift`:

- Window size, corner radius, padding
- Icon size or image source
- Auto-dismiss timeout (currently 8 seconds)
- Sound effect (currently "Glass")
- Click behavior (focuses the originating terminal app, falls back to frontmost app)

---

## 🙏 Credits

- [Bark](https://github.com/Finb/Bark) — Finb's open-source iOS push notification tool
- [Claude Code](https://github.com/anthropics/claude-code) — Anthropic's AI coding assistant
- [Kimi CLI](https://github.com/MoonshotAI/kimi-cli) — Moonshot AI's coding assistant

---

## License

MIT
