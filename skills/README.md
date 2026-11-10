# Skills

Tool-neutral instruction packs. Each folder has a `SKILL.md` (plain Markdown) and optional `references/`. Nothing here depends on a particular LLM or agent.

| Skill | Purpose |
|---|---|
| `source-to-target-mapping` | Map a source system to a target model and produce the STM, ETL handoff notes and steward questions |

## Using a skill
- **Agents with file access** (Claude Code, Codex, Cursor, Copilot agent, Gemini CLI, and similar): they read `AGENTS.md` (or their adapter file), which points here. Say: "map projects/<NAME>".
- **Chat-only LLMs**: start a conversation with the prompt below, then attach or paste the files it lists.

```
You are following the skill below. Read it fully, then do the task.
SKILL: <paste skills/source-to-target-mapping/SKILL.md>
REFERENCES (paste the ones the skill points to): references/*.md
INPUTS: <paste projects/<NAME>/inputs/* files>
TASK: Produce the STM sheets as CSV blocks, the ETL handoff notes, and the steward questions.
```

## Adding a skill
Create `skills/<name>/SKILL.md` with a name and description header, write it as plain Markdown, and keep vendor-specific adapters (such as `.claude/skills/<name>/SKILL.md`) to a few lines that point back here.
