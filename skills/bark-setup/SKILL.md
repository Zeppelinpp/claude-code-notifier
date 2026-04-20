---
name: bark-setup
description: Configure Bark push notification key for Claude Code Notifier
type: user-invocable
---

# Bark Setup

This skill configures your Bark device key so that Claude Code Notifier can send push notifications to your iPhone when Claude Code stops responding.

## How to use

Run this skill and Claude will ask for your Bark key, then write it to the plugin config file automatically.

## What it does

1. Asks the user for their Bark device key
2. Writes it to `~/.claude/plugin-configs/claude-code-notifier/bark-key`
3. Confirms the configuration is saved

## Instructions

When invoked:

1. Explain what Bark is (open-source iOS push notification app by Finb)
2. Ask the user for their Bark device key
3. Create the config directory if it doesn't exist
4. Write the key to `~/.claude/plugin-configs/claude-code-notifier/bark-key` with permissions 600
5. Confirm success and mention they can test it by triggering a Claude Code Stop event
6. If the user doesn't have Bark yet, provide the App Store link: https://apps.apple.com/app/bark-customed-notifications/id1403753865

If a key already exists, ask if they want to overwrite it.
