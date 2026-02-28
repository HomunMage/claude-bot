# claude-bot — Autonomous Multi-Agent Dev Loop

A two-phase system for autonomous development using Claude Code CLI.

Inspired by the **Ralph Wiggum Loop** — AI works in infinite cycles (50 max) until all tickets are done.

## Two-Phase Workflow

```
Phase 1: /claude-plan (interactive)        Phase 2: /claude-bot (autonomous)
┌──────────────────────────────┐           ┌──────────────────────────────┐
│  User + Claude discuss:      │           │  Orchestrator loops:         │
│  1. Read project, understand │  produces │  1. Plan tasks (Haiku)       │
│  2. Design architecture      │ ───────→  │  2. Spawn workers in tmux    │
│  3. Break into small tickets │           │  3. Monitor (kill >900s)     │
│  4. Write llm.plan.status    │           │  4. Collect results          │
│  5. Write CLAUDE.md          │           │  5. Next cycle (×50)         │
└──────────────────────────────┘           └──────────────────────────────┘
```

**Phase 1** is a conversation — you discuss what to build, Claude breaks it into small testable tickets, and writes the plan files. Nothing runs autonomously yet.

**Phase 2** is fully autonomous — the orchestrator spawns workers in tmux, each picks a ticket, implements it, tests, formats, lints, commits. Loop until done.

## Architecture

```
tmux session: "claude-bot"
 ├── window 0: orchestrator.sh (Haiku — plans tasks, monitors workers)
 ├── window 1: worker.sh #1   (Sonnet — picks ticket, codes, tests, commits)
 ├── window 2: worker.sh #2   (Sonnet — picks ticket, codes, tests, commits)
 └── ...N workers
```

### Orchestrator Cycle (50 rounds max)

```
┌─────────────────────────────────────────────┐
│  1. Plan: read llm.plan.status              │
│     → call claude (haiku) to assign tasks   │
│  2. Spawn: launch N workers in tmux windows │
│  3. Monitor: poll _trigger_{id} files       │
│     → kill workers if >900s                 │
│  4. Collect: read DONE/BLOCKED results      │
│  5. Sleep 5s → next cycle                   │
└─────────────────────────────────────────────┘
```

### Worker Cycle (one ticket per round)

```
┌─────────────────────────────────────────────┐
│  1. Clean: git status → reset --hard if dirty│
│  2. Read: CLAUDE.md, llm.plan.status,       │
│           llm.working.log, README.md        │
│  3. Work: implement the assigned ticket     │
│  4. Test: auto-detect & run tests           │
│  5. Format: prettier / cargo fmt / ruff     │
│  6. Lint: eslint / clippy / ruff check      │
│  7. Commit: git add + commit (with lock)    │
│  8. Signal: write DONE to _trigger_{id}     │
└─────────────────────────────────────────────┘
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- `tmux` installed
- Target project must have:
  - `llm.plan.status` — ticket list with `[ ]` / `[x]` checkboxes
  - `CLAUDE.md` — dev rules (copy from this repo's template)
  - `README.md` — project overview

## Quick Start

### Option A: Use Claude Code Skills (recommended)

```bash
# Install skills to your personal directory
cp -r claude-bot/skills/claude-plan ~/.claude/skills/
cp -r claude-bot/skills/claude-bot ~/.claude/skills/

# Phase 1: Plan (interactive — discuss with Claude)
/claude-plan /path/to/your/project

# Phase 2: Run (autonomous — Claude works in tmux loop)
/claude-bot /path/to/your/project
```

### Option B: Manual setup

```bash
# 1. Copy CLAUDE.md to your target project
cp claude-bot/CLAUDE.md /path/to/your/project/CLAUDE.md

# 2. Create llm.plan.status with tickets
cat > /path/to/your/project/llm.plan.status << 'EOF'
# Project Tickets

## Phase 1: Setup
- [ ] Initialize project scaffold
- [ ] Add database models
- [ ] Create API endpoints

## Phase 2: Features
- [ ] Implement user authentication
- [ ] Add search functionality
EOF

# 3. Start the bot
bash claude-bot/skills/claude-bot/examples/start.sh /path/to/your/project

# 4. Monitor
tmux attach -t claude-bot

# 5. Stop
bash claude-bot/skills/claude-bot/examples/stop.sh /path/to/your/project
```

## File Conventions

These files live in your **target project** (not in claude-bot):

| File | Required | Purpose |
|------|----------|---------|
| `CLAUDE.md` | Yes | Dev rules — workers read this first |
| `README.md` | Yes | Project overview |
| `llm.plan.status` | Yes | Ticket list with `[ ]`/`[x]` checkboxes |
| `llm.working.log` | Auto-created | Abstract of completed work (append-only) |
| `.tmp/llm.working.notes` | Optional | Detailed working notes |
| `llm*.md` | Optional | Design docs, references, specs |

### llm.plan.status format

```markdown
# Project Tickets

## Phase 1: Core
- [x] Initialize project scaffold
- [ ] Add database models         ← worker picks this
- [ ] Create API endpoints

## Phase 2: Features
- [ ] Implement authentication
- [ ] Add search functionality
```

Rules for tickets:
- Each ticket must be **small enough** to implement, test, and commit in <15 minutes
- Use `[ ]` for pending, `[x]` for done
- Workers mark `[x]` after committing

### llm.working.log format (auto-generated by workers)

```markdown
[W1] Initialized project scaffold — created package.json, tsconfig, src/ structure
[W2] Added database models — User, Post, Comment with Prisma schema
[W1] Created API endpoints — /users, /posts CRUD with Express router
```

## Coordination Mechanisms

| Mechanism | How | Why |
|-----------|-----|-----|
| **Git Lock** | `mkdir _git.lock` (atomic) | Only one worker commits at a time |
| **Trigger Files** | `_trigger_{id}` with DONE/BLOCKED | Workers signal completion to orchestrator |
| **Task Queue** | `_task_queue` file | Orchestrator writes planned tasks |
| **Timeout** | 900s (15 min) | Kill stuck workers, orchestrator continues |

## Scripts

All scripts live in `skills/claude-bot/examples/`:

| Script | Usage | Description |
|--------|-------|-------------|
| `start.sh` | `bash start.sh <project_dir> [cycles] [workers]` | Start tmux session with orchestrator |
| `stop.sh` | `bash stop.sh [project_dir]` | Stop everything, clean up |
| `orchestrator.sh` | (called by start.sh) | Main loop — plan, spawn, monitor, collect |
| `worker.sh` | (called by orchestrator) | Single worker — clean, work, test, commit |
| `checkpoint.sh` | `bash checkpoint.sh <project_dir> "msg"` | Manual git checkpoint |
| `rollback.sh` | `bash rollback.sh <project_dir> [hash]` | Git reset --hard |

## Claude Code Skills

Two skills, matching the two phases:

```bash
# Install both skills
cp -r claude-bot/skills/claude-plan ~/.claude/skills/
cp -r claude-bot/skills/claude-bot ~/.claude/skills/
```

| Skill | Invoke | Phase | Mode |
|-------|--------|-------|------|
| `/claude-plan` | `/claude-plan /path/to/project` | Phase 1 | Interactive — discuss with user |
| `/claude-bot` | `/claude-bot /path/to/project` | Phase 2 | Autonomous — tmux loop |

## Model Usage

| Role | Model | Why |
|------|-------|-----|
| Orchestrator (planner) | Haiku | Fast, cheap — only reads status and assigns tasks |
| Worker | Sonnet | Smart enough to code, test, and commit correctly |

## Logs

```
<project_dir>/out/
├── orchestrator.log     # Planning decisions, worker status, cycle tracking
├── worker_1.log         # Full Claude output for worker 1
├── worker_2.log         # Full Claude output for worker 2
└── ...
```

## Tips

- **Keep tickets small**: If a ticket takes >15 min, split it. Workers get killed at 900s.
- **Watch the first cycle**: `tmux attach -t claude-bot` to verify workers understand the project.
- **Use llm.working.notes for context**: Workers read this for detailed background. Write design decisions, API specs, data models here.
- **Rollback if needed**: `bash rollback.sh /path/to/project <commit-hash>`
- **Add more workers**: Workers are generic — increase `num_workers` for independent tasks. But don't exceed the number of non-overlapping tickets.

## License

MIT
