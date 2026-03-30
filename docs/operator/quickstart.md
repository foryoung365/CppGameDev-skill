# Operator Quickstart

This plugin is packaged for Claude Code and is meant to be loaded from the plugin root.

## Load The Plugin

Use:

```powershell
claude --plugin-dir I:\CppGameDev
```

After Claude Code starts, use `/help` to confirm the plugin namespace is visible.

If you want to consume it through the marketplace flow instead of `--plugin-dir`, use:

```text
/plugin marketplace add I:\CppGameDev
/plugin install cpp-mmorpg-gameplay@foryoung365-plugins
```

Or, if you want Claude Code to fetch the marketplace from GitHub:

```text
/plugin marketplace add foryoung365/CppGameDev
/plugin install cpp-mmorpg-gameplay@foryoung365-plugins
```

## Start With These Commands

- `/cpp-mmorpg-gameplay:intake`
- `/cpp-mmorpg-gameplay:gp-debug`
- `/cpp-mmorpg-gameplay:gp-review`
- `/cpp-mmorpg-gameplay:svn-handoff`

## When To Use Each One

- `intake`: start normal gameplay work and get the context card plus `pre-plan`
- `gp-debug`: diagnose a gameplay symptom when the root cause is still unknown
- `gp-review`: run project-aware C++ review plus gameplay-risk review
- `svn-handoff`: prepare a feature-sized SVN delivery handoff with validation evidence

## Human Reading Order

If you want the human-readable policy mirrors, read:

- `docs/workflow/request-lifecycle.md`
- `docs/gameplay/context-card.md`
- `docs/svn/commit-policy.md`

Runtime authority still lives in plugin assets such as `skills/`, `agents/`, and `commands/`, not in docs alone.

## Build Integration Boundary

This plugin enforces the rule that commit-ready work needs a fresh successful compile, but it does not define project-specific build commands.
Use the active project's standard build script or build command from that project's `claude.md` or equivalent local runtime config.
