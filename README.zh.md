# Claude Code Notifier

> 为 Claude Code 打造的精美 macOS 弹窗 & iPhone 推送通知工具。AI 完成思考时，不再错过。

[![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

当 Claude Code 停止响应时——无论是任务完成、等待输入还是会话结束——这款通知器会在你当前活跃显示器上弹出一个精致的 macOS 原生面板。搭配 [Bark](https://github.com/Finb/Bark) 使用，同一时刻你的 iPhone 也会收到推送。

---

## ✨ 功能亮点

- **原生 macOS 弹窗** — 毛玻璃质感面板，连续圆角，自动适配深色/浅色模式，附带系统 Glass 提示音
- **多显示器感知** — 弹窗始终出现在你鼠标当前所在的屏幕
- **一键回切** — 点击通知即可跳回 Terminal / Tmux 窗口
- **悬停关闭** — 优雅的关闭按钮在鼠标悬停时淡入显示
- **iPhone 同步** — 通过 [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865) 经 APNs 实时推送至手机
- **Claude 品牌标识** — 使用 Claude Code 官方吉祥物图标，而非通用桌面图标

---

## 📸 效果预览

```
┌─────────────────────────────┐
│  [🟠]  Claude Code           │
│         Wait for Input        │
│         ~/projects/my-app     │
└─────────────────────────────┘
```

*与你的 macOS 主题一致的毛玻璃面板，在活跃桌面丝滑弹出。*

---

## 🚀 快速开始

### 推荐方式：插件安装

在 Claude Code 设置中注册本仓库为插件市场（`~/.claude/settings.json`）：

```json
{
  "extraKnownMarketplaces": {
    "zeppelinpp": {
      "source": {
        "source": "github",
        "repo": "Zeppelinpp/claude-code-notifier"
      }
    }
  }
}
```

然后在 Claude Code 中安装插件：

```
/plugin install claude-code-notifier@zeppelinpp
```

Done — Stop hook 立即生效。无需手动编写脚本或修改设置。

### 配置 Bark（可选）

如需启用 iPhone 推送，在 Claude Code 中运行内置的配置 skill：

```
/bark-setup
```

Claude 会询问你的 Bark 设备密钥并自动保存，无需手动编辑文件。

或设置环境变量：

```bash
export BARK_KEY="你的-bark-密钥"
```

1. 在 iPhone 上安装 [Bark](https://apps.apple.com/app/bark-customed-notifications/id1403753865)
2. 打开应用，复制你的设备密钥
3. 在 Claude Code 中运行 `/bark-setup` 并粘贴密钥

更多 Bark 高级用法，请访问 [Bark GitHub 仓库](https://github.com/Finb/Bark)。

---

## 🔧 手动安装（Legacy）

如果你不想使用插件系统，可使用独立安装器：

```bash
cd claude-code-notifier
./install.sh          # 交互式：覆盖前询问
./install.sh --force  # 非交互式：自动覆盖，适合更新
```

这会复制应用到 `~/Applications/`、创建 `~/.claude/tools/notify.sh`，并向 `settings.json` 添加 Hook。

从 Legacy Hook 迁移到插件模式：

```bash
./install.sh --uninstall   # 移除 legacy settings.json hook
# 然后在 Claude Code 中使用 /plugin install
```

---

## 📁 仓库结构

```
claude-code-notifier/
├── .claude-plugin/
│   ├── plugin.json          # 插件清单
│   └── marketplace.json     # 市场清单
├── hooks/
│   └── hooks.json           # Claude Code Stop hook
├── skills/
│   └── bark-setup/
│       └── SKILL.md         # 交互式 Bark 配置 skill
├── scripts/
│   ├── notify.sh            # 插件通知脚本
│   └── setup-bark.sh        # Bark 密钥配置
├── ClaudeCodeNotifier.app/  # 已编译的 macOS 通知器应用
├── src/
│   └── popup.swift          # Swift 源码（可自定义）
├── assets/
│   └── claudecode-color.png # Claude Code 吉祥物图标
├── install.sh               # 独立安装器（legacy）
├── README.md
└── README.zh.md
```

---

## 🔨 从源码构建

预编译的 `ClaudeCodeNotifier.app` 开箱即用，但你可以自定义弹窗样式后重新编译：

```bash
cd src
swiftc popup.swift -o ClaudeCodeNotifier
```

然后替换应用包中的二进制文件：

```bash
cp ClaudeCodeNotifier ../ClaudeCodeNotifier.app/Contents/MacOS/
```

需要 macOS 11.0+ 及 Swift 工具链。`popup.swift` 中可自定义的关键项：

- 窗口大小、圆角半径、边距
- 图标大小或图片来源
- 自动消失时间（当前 8 秒）
- 提示音效（当前 "Glass"）
- 点击行为（当前聚焦至最前应用）

---

## 🙏 致谢

- [Bark](https://github.com/Finb/Bark) — Finb 开发的开源 iOS 推送通知工具
- Claude Code — Anthropic 推出的 AI 编程助手

---

## License

MIT
