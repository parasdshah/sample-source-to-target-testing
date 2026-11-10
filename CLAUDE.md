# Repo layout
- `projects/<NAME>/inputs|outputs` — one self-contained mapping project per folder. Never read from or write to another project's folders.
- `templates/project/` — empty skeleton to copy for a new project.
- `.claude/skills/source-to-target-mapping` — shared skill used by all projects.
When asked to map a project, use that project's `inputs/` and write results to its `outputs/`. For multiple projects, run them in parallel, one subagent per project.
