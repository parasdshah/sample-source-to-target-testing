# Repository guide (for any LLM or coding agent)

## Layout
- `skills/<skill-name>/SKILL.md` : tool-neutral skills (plain Markdown, details in each skill's `references/`). The single source of truth. Do not duplicate skill content elsewhere.
- `projects/<NAME>/inputs|outputs` : one self-contained mapping project per folder. Never read from or write to another project's folders.
- `templates/project/` : empty skeleton to copy for a new project.
- Adapters (pointers only, no content): `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.claude/skills/*`.

## How to work
1. To map a project, read `skills/source-to-target-mapping/SKILL.md` and follow it, using that project's `inputs/` and writing to its `outputs/`.
2. For several projects, handle each independently; run them in parallel only if your tool supports it.
3. If you cannot create files or `.xlsx`, return CSV or Markdown blocks (see section 0 of the skill).
4. Questions for stewards go in the project's `outputs/03_Steward_Questions.md`.
