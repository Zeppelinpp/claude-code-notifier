# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Notifier is a Claude Code plugin that sends native macOS popup notifications (and optional iPhone push via Bark) when Claude Code stops responding. It consists of a Swift macOS app for the popup UI, a bash hook script, and Claude Code plugin manifests.

## Build Commands

### Rebuild the macOS Popup App

```bash
cd src
swiftc popup.swift -o ClaudeCodeNotifier
cp ClaudeCodeNotifier ../ClaudeCodeNotifier.app/Contents/MacOS/
```

Requires macOS 11.0+ and Swift toolchain. The app bundle at `ClaudeCodeNotifier.app/` must retain its `Info.plist`, `Contents/Resources/AppIcon.icns`, and `Contents/Resources/AppIcon.png`.

## Architecture

### Data Flow

1. **Hook Trigger**: Claude Code fires the `Stop` hook (defined in `hooks/hooks.json`)
2. **Message Extraction** (`scripts/notify.sh`): Reads JSON from stdin, extracts `last_assistant_message` if available; otherwise parses `transcript_path` line-by-line for the last assistant text/thinking block
3. **Terminal Detection** (`scripts/notify.sh`): Walks the parent PID chain and checks env vars (`GHOSTTY_RESOURCES_DIR`, `ITERM_SESSION_ID`, etc.) to determine the terminal emulator's bundle ID for click-to-focus
4. **macOS Popup**: Executes `ClaudeCodeNotifier.app/Contents/MacOS/ClaudeCodeNotifier` with args: `[title] [cwd] [message] [terminal_bundle_id]`
5. **Bark Push** (optional): If `BARK_KEY` env var or `~/.claude/plugin-configs/claude-code-notifier/bark-key` exists, sends an HTTP request to `api.day.app`

### Key Files

| File | Purpose |
|------|---------|
| `src/popup.swift` | Swift source for the borderless, frosted-glass notification window. Renders markdown in the body, code-block style for the subtitle path, hover-to-dismiss close button, click-to-focus terminal, 8s auto-dismiss |
| `scripts/notify.sh` | Main hook script. Plugin entry point. Handles message extraction, terminal detection, popup invocation, and Bark push |
| `scripts/setup-bark.sh` | Standalone interactive Bark key configuration (legacy) |
| `hooks/hooks.json` | Plugin hook manifest. References `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh` asynchronously on `Stop` |
| `.claude-plugin/plugin.json` | Plugin marketplace manifest. Version here is the source of truth |
| `.claude-plugin/marketplace.json` | Marketplace registry entry |
| `skills/bark-setup/SKILL.md` | Interactive skill for configuring Bark via Claude Code `/bark-setup` |
| `install.sh` | Legacy standalone installer. Also handles `--uninstall` (removes settings.json hook) and `--bark-only` |

### Plugin vs Legacy Mode

- **Plugin mode** (recommended): Installed via `/plugin install claude-code-notifier@zeppelinpp`. Uses `hooks/hooks.json` + `scripts/notify.sh`. The `CLAUDE_PLUGIN_ROOT` env var is set by Claude Code at runtime.
- **Legacy mode**: `install.sh` copies `notify.sh` to `~/.claude/tools/` and adds a hook to `~/.claude/settings.json`. Use `./install.sh --uninstall` to migrate to plugin mode.

### Bark Key Resolution Order

1. `BARK_KEY` environment variable
2. `~/.claude/plugin-configs/claude-code-notifier/bark-key` (written by `/bark-setup` or `install.sh --bark-only`)

### Transcript Parsing

When `last_assistant_message` is absent from hook JSON, `notify.sh` parses the newline-delimited JSON transcript file. It iterates all lines, tracks the last `type: text` and `type: thinking` entries from assistant messages, prefers text over thinking, collapses whitespace to a single line, and truncates to ~100 chars.
