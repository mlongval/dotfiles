# Installing Claude Code (Native)

If you previously installed Claude Code via brew cask or npm, remove those first:

```sh
brew uninstall --cask claude-code 2>/dev/null || true
npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
```

Then install the native binary:

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

Verify the installation:

```sh
claude --version
```

Then log in:

```sh
claude login
```
