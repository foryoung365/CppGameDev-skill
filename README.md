# CppGameDev Plugin

This repository is a Claude Code plugin package for gameplay-focused agent work on a C++ MMORPG game server codebase. Its job is to keep requests routed through a shared intake path, keep gameplay context visible before edits, and keep SVN delivery constrained to complete features or complete fixes.

This plugin is self-contained. Upstream Superpowers and ECC ideas have already been distilled into the local plugin files here, and no upstream repository copy is part of the delivered package.

## Plugin Layout

This repository is a Claude Code plugin package, not a standalone `.claude/` project overlay.

- Plugin root runtime assets live in `skills/`, `agents/`, and `commands/`.
- `.claude-plugin/` contains only `plugin.json`.
- `settings.json` activates the default main runtime agent for the plugin.

## Start Here

Use these plugin entry points first:

- [`commands/intake.md`](./commands/intake.md)
- [`agents/gameplay-main.md`](./agents/gameplay-main.md)
- [`docs/operator/quickstart.md`](./docs/operator/quickstart.md)

Human-readable mirrors are available here:

- [`docs/workflow/request-lifecycle.md`](./docs/workflow/request-lifecycle.md)
- [`docs/gameplay/context-card.md`](./docs/gameplay/context-card.md)
- [`docs/svn/commit-policy.md`](./docs/svn/commit-policy.md)

Internal maintainer provenance lives here:

- [`docs/upstream-mapping.md`](./docs/upstream-mapping.md)
- [`docs/superpowers`](./docs/superpowers)

## Command Names

Use the plugin namespace:

- `/cpp-mmorpg-gameplay:intake`
- `/cpp-mmorpg-gameplay:gp-debug`
- `/cpp-mmorpg-gameplay:gp-review`
- `/cpp-mmorpg-gameplay:svn-handoff`

## Marketplace

This repository now ships both the plugin manifest and a marketplace catalog.

Offline local marketplace add:

```text
/plugin marketplace add I:\CppGameDev
/plugin install cpp-mmorpg-gameplay@foryoung365-plugins
```

GitHub marketplace add:

```text
/plugin marketplace add foryoung365/CppGameDev
/plugin install cpp-mmorpg-gameplay@foryoung365-plugins
```

The marketplace catalog now uses a relative plugin source, so the same catalog works both from a local filesystem path and from the GitHub repository clone that Claude Code creates when you add the marketplace by repo name.

## Validation

Run the structural verification script:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-toolkit.ps1
```

Smoke-test the plugin locally with Claude Code:

```powershell
claude --plugin-dir I:\CppGameDev
```

## Publication Boundary

Published with the plugin:

- runtime assets in `skills/`, `agents/`, `commands/`, `settings.json`, and `.claude-plugin/plugin.json`
- marketplace catalog in `.claude-plugin/marketplace.json`
- `README.md`
- `docs/operator/quickstart.md`

Internal maintainer docs:

- `docs/upstream-mapping.md`
- `docs/superpowers/`

## Runtime Notes

- Project conventions override imported ECC defaults when they conflict.
- The runtime request path is `request -> gameplay-context-guard -> task-intake-router -> pre-plan`.
- SVN delivery is feature-sized.
- SVN commits are allowed only at one complete feature or one complete fix granularity.
- A fresh successful compile is required before any commit-ready conclusion, and compile success does not replace targeted validation.
- The plugin does not define project-specific build commands; compile proof should use the host project's standard build script or build command from that project's `claude.md` or equivalent local runtime config.
- Published docs are human-facing only; runtime authority stays in plugin assets.
