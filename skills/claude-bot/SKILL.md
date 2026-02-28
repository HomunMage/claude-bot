---
name: claude-bot
description: Start the autonomous multi-agent dev loop — orchestrator + workers in tmux solving tickets from llm.plan.status
disable-model-invocation: true
argument-hint: <project_dir> [cycles] [workers]
---

# claude-bot — Autonomous Dev Loop

Start a tmux-based orchestrator that runs N workers in parallel to solve project tickets autonomously.

## What This Does

1. Creates a tmux session `claude-bot`
2. Runs an orchestrator (Haiku) that reads `llm.plan.status` and assigns tickets to workers
3. Spawns N workers (Sonnet) in separate tmux windows
4. Each worker: git clean → implement ticket → test → format → lint → commit
5. Orchestrator monitors workers (kills if >900s), collects results, loops (50 cycles max)

## Prerequisites

The target project must have:
- `llm.plan.status` — ticket list with `[ ]` / `[x]` checkboxes
- `CLAUDE.md` — dev rules (copy from claude-bot/CLAUDE.md template)
- `README.md` — project overview

## Usage

Start the bot:
```bash
bash examples/start.sh $ARGUMENTS
```

Monitor:
```bash
tmux attach -t claude-bot
```

Stop:
```bash
bash examples/stop.sh $ARGUMENTS
```

## Example Scripts

All scripts are in the [examples/](examples/) directory:

| Script | Purpose |
|--------|---------|
| [start.sh](examples/start.sh) | Entry point — create tmux session, launch orchestrator |
| [stop.sh](examples/stop.sh) | Kill tmux session + cleanup trigger/lock files |
| [orchestrator.sh](examples/orchestrator.sh) | Main loop — plan → spawn → monitor(900s) → collect → repeat |
| [worker.sh](examples/worker.sh) | Generic worker — clean → read context → work → test/fmt/lint → commit |
| [checkpoint.sh](examples/checkpoint.sh) | Git add + commit helper (with lock) |
| [rollback.sh](examples/rollback.sh) | Git reset --hard helper |

## Coordination

- **Git Lock**: `mkdir _git.lock` (atomic) — only one worker commits at a time
- **Trigger Files**: `_trigger_{id}` with DONE/BLOCKED — workers signal completion
- **Timeout**: 900s per worker — orchestrator kills stuck workers and continues
- **Task Queue**: `_task_queue` — orchestrator writes Haiku-planned tasks per cycle
