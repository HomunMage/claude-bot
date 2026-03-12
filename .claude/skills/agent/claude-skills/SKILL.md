---
name: claude-skills
description: Guide for creating Claude Code skills (SKILL.md). Use when building, structuring, or debugging custom skills/slash commands.
user-invocable: false
---

# Skill = SKILL.md + optional files

```
.claude/skills/<name>/
├── SKILL.md          # YAML frontmatter + markdown body
├── reference.md      # Lazy-loaded detail (no context cost)
└── scripts/          # Helper scripts
```

## Frontmatter

```yaml
---
name: skill-name
description: WHEN to trigger — Claude matches on this. Write like a search query.
argument-hint: [arg]                    # Autocomplete hint
allowed-tools: Read, Grep, Bash        # Auto-approved tools
# Visibility (pick one pattern):
#   default                            → user `/cmd` ✓, auto-load ✓
#   disable-model-invocation: true     → user `/cmd` ✓, auto-load ✗ (side-effects!)
#   user-invocable: false              → user `/cmd` ✗, auto-load ✓ (internal lib)
# Isolation:
#   context: fork                      → subagent, no conversation history
#   agent: Explore                     → subagent type (needs context: fork)
---
```

## Body Variables

`$ARGUMENTS` all args · `$0 $1 $2` positional · `${CLAUDE_SKILL_DIR}` skill dir · `` !`cmd` `` shell injection

## Scope

`.claude/skills/` project > `~/.claude/skills/` global

## Principles

- `description` = trigger. Precision matters.
- SKILL.md < 500 lines. Offload → `reference.md`.
- Side-effects → `disable-model-invocation: true`.
- Reusable internal logic → `user-invocable: false`.
