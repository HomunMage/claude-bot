# Dev Rules

## On Start — Read These First

1. `README.md` — project overview, architecture, tech stack
2. `llm.plan.status` — ticket list and current status (pick `[ ]` tickets to work on)
3. `llm.working.log` — abstract of recent completed work
4. `.claude/llm.working.notes` — detailed working notes (if exists, read for more context)
5. Any `llm*.md` files — design docs, API specs, references

## Work Cycle

### Step 1: Clean Slate
```bash
git status
# If there are uncommitted changes → git reset --hard HEAD
# Start every session with a clean working tree
```

### Step 2: Pick ONE Ticket
- Read `llm.plan.status`
- Find the first `[ ]` (unchecked) ticket
- Work on ONLY that ticket — one ticket per session

### Step 3: Implement
- Make the smallest possible change to complete the ticket
- Stay in scope — don't refactor unrelated code
- Don't add features beyond what the ticket asks

### Step 4: Test
Auto-detect project type and run tests:
- `package.json` → `npm test`
- `Cargo.toml` → `cargo test`
- `pyproject.toml` or `setup.py` → `pytest`
- `go.mod` → `go test ./...`
- `Makefile` with test target → `make test`

All tests MUST pass before proceeding.

### Step 5: Format + Lint
Auto-detect and run formatters/linters:
- JS/TS → `npx prettier --write .` and `npx eslint --fix .`
- Rust → `cargo fmt` and `cargo clippy -- -D warnings`
- Python → `ruff format .` and `ruff check --fix .`
- Go → `gofmt -w .` and `golangci-lint run`

### Step 6: Git Commit
```bash
# Acquire lock (if multi-worker)
while ! mkdir _git.lock 2>/dev/null; do sleep 2; done

git add -A
git commit -m "ticket: <short description of what was done>"

# Release lock
rmdir _git.lock
```

### Step 7: Update Status
1. Mark the ticket `[x]` in `llm.plan.status`
2. Append a summary to `llm.working.log`:
   ```
   [W{id}] <what was done> — <files changed>
   ```

## Rules

- **ONE ticket per session.** Small steps. Do not batch multiple tickets.
- **Never ask questions.** Make reasonable decisions and document them in the commit message.
- **Stay in your assigned scope.** Don't touch files outside your task boundary.
- **If stuck after 3 attempts:** `git stash`, write BLOCKED to the trigger file, stop.
- **All tests must pass** before committing. If tests fail, fix them or stash and report BLOCKED.
- **Don't break existing tests.** If your change breaks unrelated tests, investigate before committing.
- **Commit messages matter.** Use format: `ticket: <verb> <what>` (e.g., `ticket: add user auth endpoint`)
