# Issue Tracking with bd (beads)

All issue tracking in this project uses `bd`. Do not use markdown TODO
lists, external trackers, or any other tracking system.

## Commands

- **Check ready work**: `bd ready --json`
- **Create issue**: `bd create "Title" --description="Details" -t bug -p 1 --json`
- **Link discovered work**: `bd create "Title" --description="Details" -p 1 --deps discovered-from:bd-123 --json`
- **Claim**: `bd update <id> --claim --json`
- **Close**: `bd close <id> --reason "Done" --json`
- **Sync**: `bd sync`

Always use `--json` for programmatic output.

## Issue Types & Priorities

Types: `bug`, `feature`, `task`, `epic`, `chore`

Priorities: `0` critical, `1` high, `2` medium (default), `3` low, `4` backlog

## Workflow

1. `bd ready` — find unblocked work
2. `bd update <id> --claim` — claim it
3. Implement, test, document
4. If you discover new work, create a linked issue with `discovered-from`
5. `bd close <id> --reason "Done"`

## Session Completion

Before ending a session, push is mandatory:

```bash
bd sync
git pull --rebase
git push
```

Work is not complete until `git push` succeeds. Never leave changes
stranded locally.

## Rules

- **bd is the single source of truth.** No markdown TODOs, no external
  trackers, no duplicate systems.
- **Check before asking.** Run `bd ready` before asking what to work on.
- **Link related work.** Use `discovered-from` dependencies when new issues
  emerge during implementation.
