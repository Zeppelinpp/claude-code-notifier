# Publish

Publish a new version of the Claude Code Notifier plugin.

1. Run `git status` to see current changes.
2. If there are no changes, abort and report "Nothing to publish."
3. Generate a concise commit message summarizing the functional changes (not version bumps).
4. Bump the patch version in `.claude-plugin/plugin.json` (e.g., 1.0.3 → 1.0.4).
5. Stage changes in groups of relevant files: `git add`
6. Commit with the generated message.
7. Push: `git push origin main`
8. Report the published version.

Focus on the core feature changes to commit and publish
