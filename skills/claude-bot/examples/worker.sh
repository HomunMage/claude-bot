#!/bin/bash
# worker.sh — Generic worker: clean → read context → work → test/fmt/lint → commit
# Usage: bash worker.sh <project_dir> <worker_id> [task_description]

set -uo pipefail

PROJECT_DIR="${1:?Usage: worker.sh <project_dir> <worker_id> [task_description]}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
WORKER_ID="${2:?Worker ID required}"
TASK_DESC="${3:-}"
TRIGGER_FILE="${PROJECT_DIR}/_trigger_${WORKER_ID}"
LOG_FILE="${PROJECT_DIR}/out/worker_${WORKER_ID}.log"
GIT_LOCK="${PROJECT_DIR}/_git.lock"

mkdir -p "${PROJECT_DIR}/out"

log() {
  echo "$(date '+%H:%M:%S') [W${WORKER_ID}] $1" | tee -a "$LOG_FILE"
}

log "Worker ${WORKER_ID} starting..."
[ -n "$TASK_DESC" ] && log "Task: ${TASK_DESC}"

# ─── Phase 1: Clean ─────────────────────────────────────────────────────────
log "Phase 1: Checking git status..."
cd "$PROJECT_DIR" || exit 1

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  log "Dirty working tree detected. Resetting to HEAD..."
  git reset --hard HEAD 2>&1 | tee -a "$LOG_FILE"
  git clean -fd 2>&1 | tee -a "$LOG_FILE"
  log "Clean slate restored."
fi

# ─── Phase 2: Build context ─────────────────────────────────────────────────
CONTEXT=""

# Read CLAUDE.md (dev rules)
if [ -f "${PROJECT_DIR}/CLAUDE.md" ]; then
  CONTEXT="${CONTEXT}
--- CLAUDE.md (Dev Rules) ---
$(cat "${PROJECT_DIR}/CLAUDE.md")
"
fi

# Read README.md
if [ -f "${PROJECT_DIR}/README.md" ]; then
  CONTEXT="${CONTEXT}
--- README.md ---
$(head -200 "${PROJECT_DIR}/README.md")
"
fi

# Read llm.plan.status (ticket list)
if [ -f "${PROJECT_DIR}/llm.plan.status" ]; then
  CONTEXT="${CONTEXT}
--- llm.plan.status (Tickets) ---
$(cat "${PROJECT_DIR}/llm.plan.status")
"
fi

# Read llm.working.log (abstract of recent work)
if [ -f "${PROJECT_DIR}/llm.working.log" ]; then
  CONTEXT="${CONTEXT}
--- llm.working.log (Recent Work) ---
$(tail -50 "${PROJECT_DIR}/llm.working.log")
"
fi

# Read .claude/llm.working.notes (detailed notes)
if [ -f "${PROJECT_DIR}/.claude/llm.working.notes" ]; then
  CONTEXT="${CONTEXT}
--- .claude/llm.working.notes (Detailed Notes) ---
$(tail -100 "${PROJECT_DIR}/.claude/llm.working.notes")
"
fi

# Read any other llm*.md files
for f in "${PROJECT_DIR}"/llm*.md; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f")
  case "$BASENAME" in
    llm.plan.status|llm.working.log) continue ;;
  esac
  CONTEXT="${CONTEXT}
--- ${BASENAME} ---
$(head -200 "$f")
"
done

# ─── Phase 3: Work ──────────────────────────────────────────────────────────
if [ -n "$TASK_DESC" ]; then
  TASK_PROMPT="YOUR ASSIGNED TASK: ${TASK_DESC}
Focus ONLY on this specific task. Do not work on other tasks."
else
  TASK_PROMPT="Pick the first unchecked [ ] ticket from llm.plan.status and implement it."
fi

log "Phase 2: Calling Claude to work on task..."

CLAUDECODE= claude -p \
  --dangerously-skip-permissions \
  --model sonnet \
  "You are Worker ${WORKER_ID} on an autonomous dev team.
Working directory: ${PROJECT_DIR}

${CONTEXT}

${TASK_PROMPT}

WORKFLOW — Follow these steps IN ORDER:

1. UNDERSTAND: Read the relevant source files for your ticket.

2. IMPLEMENT: Write the code changes. Keep changes minimal and focused.

3. TEST: Auto-detect project type and run tests:
   - If package.json exists → npm test (or yarn test)
   - If Cargo.toml exists → cargo test
   - If pyproject.toml or setup.py → pytest
   - If go.mod → go test ./...
   - If Makefile with test target → make test

4. FORMAT + LINT:
   - JS/TS → npx prettier --write . && npx eslint --fix .
   - Rust → cargo fmt && cargo clippy -- -D warnings
   - Python → ruff format . && ruff check --fix .
   - Go → gofmt -w . && golangci-lint run
   (Only run formatters/linters that exist in the project)

5. GIT COMMIT (with lock):
   while ! mkdir ${GIT_LOCK} 2>/dev/null; do sleep 2; done
   git add -A
   git commit -m 'ticket: <description>'
   rmdir ${GIT_LOCK}

6. UPDATE STATUS:
   - Edit llm.plan.status: change [ ] to [x] for your completed ticket
   - Append to llm.working.log: [W${WORKER_ID}] <what you did> — <files changed>
   - Git commit the status update:
     while ! mkdir ${GIT_LOCK} 2>/dev/null; do sleep 2; done
     git add llm.plan.status llm.working.log
     git commit -m 'status: mark ticket done [W${WORKER_ID}]'
     rmdir ${GIT_LOCK}

7. SIGNAL: Write to ${TRIGGER_FILE}:
   echo 'DONE' > ${TRIGGER_FILE}

IF STUCK after 3 attempts:
   git stash
   echo 'BLOCKED' > ${TRIGGER_FILE}
   Stop immediately.

RULES:
- ONE ticket only. Do not batch.
- All tests must pass before committing.
- Never ask questions. Make reasonable decisions.
- Keep changes small and focused.
" 2>&1 | tee -a "$LOG_FILE"

# ─── Phase 4: Ensure signal ─────────────────────────────────────────────────
if [ ! -f "$TRIGGER_FILE" ]; then
  log "No trigger file found. Writing BLOCKED."
  echo "BLOCKED" > "$TRIGGER_FILE"
fi

log "Worker ${WORKER_ID} finished. Result: $(cat "$TRIGGER_FILE")"
