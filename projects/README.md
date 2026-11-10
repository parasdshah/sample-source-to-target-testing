# Mapping projects

One folder per source-system → target mapping. Projects are fully independent, so any number can be worked on side by side.

```
projects/
  <SOURCE_SYSTEM>_<SCOPE>/        e.g. CRM01_CUST_ACCT
    inputs/                       source inventory, naming conventions, target DDL, reference codes, samples
    outputs/                      STM workbook, ETL handoff notes
```

## Add a new project
Copy `templates/project/` to `projects/<NEW_NAME>/`, drop the source files into `inputs/`, then run the
`source-to-target-mapping` skill and point it at that project folder (e.g. "map projects/ACME_LOANS").

## Running several together
Tell your LLM or agent which projects to process (e.g. "map every project under projects/ that has no outputs yet").
Each project reads only its own `inputs/` and writes only its own `outputs/`, so they can run in parallel
(one worker or session per project, if your tool supports it) without clashing.
