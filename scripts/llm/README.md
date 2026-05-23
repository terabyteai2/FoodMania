# Low-token Codex and Claude Code launchers

Use these launchers instead of starting agents from the monorepo root.

## Codex

```bash
./scripts/llm/codex-lite backend
./scripts/llm/codex-lite admin
./scripts/llm/codex-lite customer
./scripts/llm/codex-lite platform
```

`codex-lite` uses `~/.codex-lite` with the normal Codex auth symlinked from
`~/.codex/auth.json`, low reasoning effort, no globally enabled plugin catalog,
minimal built-in feature flags, and `--cd` scoped to the selected subsystem.

For harder tasks:

```bash
CODEX_EFFORT=medium ./scripts/llm/codex-lite backend
```

To re-enable the full Codex feature/plugin surface for a task:

```bash
CODEX_FULL_FEATURES=1 ./scripts/llm/codex-lite backend
```

## Claude Code

```bash
./scripts/llm/claude-lite backend
./scripts/llm/claude-lite admin
./scripts/llm/claude-lite customer
./scripts/llm/claude-lite platform
```

`claude-lite` starts in the selected subsystem, uses Sonnet with low effort, skips
project/local settings, disables slash-command discovery, and avoids Chrome
integration.

If `ANTHROPIC_API_KEY` is set, it automatically uses `claude --bare`, which is
the lowest-token Claude Code mode because it skips hooks, LSP, plugin sync,
auto-memory, keychain reads, and `CLAUDE.md` auto-discovery.

For harder tasks:

```bash
CLAUDE_EFFORT=medium ./scripts/llm/claude-lite admin
```
