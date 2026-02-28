# claude-bot — Autonomous Multi-Agent Dev Loop

A two-phase system for autonomous development using Claude Code CLI.

## How It Works

```
Phase 1: Planning (interactive)              Phase 2: Execution (autonomous)
┌──────────────────────────────┐           ┌──────────────────────────────┐
│  User + Claude discuss:      │           │  Orchestrator loops:         │
│  1. Read project, understand │  produces │  1. Plan tasks (Haiku)       │
│  2. Design architecture      │ ───────→  │  2. Spawn workers in tmux    │
│  3. Break into small tickets │           │  3. Monitor (kill >900s)     │
│  4. Write .tmp/llm.plan.*    │           │  4. Collect results          │
│  5. Write CLAUDE.md          │           │  5. Next cycle (x50)         │
└──────────────────────────────┘           └──────────────────────────────┘
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- `tmux` installed

## Install

```bash
# Copy the skill to your personal Claude skills directory
cp -r .claude/skills/claude-bot ~/.claude/skills/
```

## Usage

### Phase 1: Plan (interactive)

Open Claude Code in your project and discuss what to build. Claude will break it into small tickets, write `.tmp/llm.plan.status`, and design custom runner scripts at `.tmp/claude-bot/`.

### Phase 2: Run (autonomous)

```bash
# Start the bot (scripts are in your project's .tmp/claude-bot/ after planning)
bash .tmp/claude-bot/start.sh /path/to/your/project

# Or invoke via skill
/claude-bot /path/to/your/project
```

### Monitor & Stop

```bash
# Watch workers in real-time
tmux attach -t claude-bot

# Stop everything
bash .tmp/claude-bot/stop.sh /path/to/your/project
```

## Project Files

After planning, these files live in your **target project**:

| File | Required | Purpose |
|------|----------|---------|
| `CLAUDE.md` | Yes | Dev rules for workers |
| `README.md` | Yes | Project overview |
| `.tmp/llm.plan.status` | Yes | Ticket list with `[ ]`/`[x]` checkboxes |
| `.tmp/llm.working.log` | Auto-created | Log of completed work |
| `.tmp/llm.working.notes` | Optional | Detailed working notes |
| `.tmp/claude-bot/*.sh` | Designed by Claude | Custom runner scripts tailored to the project |

## Scripts

During planning, Claude designs custom scripts in `.tmp/claude-bot/` tailored to the project (e.g., `worker1.sh`, `worker2.sh` for parallel workers, or `workers.sh` for multi-role collaboration). Reference examples live in `.claude/skills/claude-bot/example-scripts/`.

## Tips

- **Keep tickets small**: Each should take <15 min. Workers get killed at 900s.
- **Watch the first cycle**: Verify workers understand the project.
- **Rollback if needed**: `bash rollback.sh /path/to/project <commit-hash>`

## License

MIT
