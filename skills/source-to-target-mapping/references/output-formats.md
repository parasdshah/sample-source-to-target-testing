# Output Formats (normative: follow exactly)

Do not rename, add, remove or reorder sheets or columns. Extra information goes in the `Comments` column. A checker (`scripts/check_stm.py`) tests these formats, so deviations fail the check.

## 1. Project folder and input files

```
projects/<NAME>/inputs/    what you receive
projects/<NAME>/outputs/   what you produce
```

| Input file | Content | Required |
|---|---|---|
| `01_source_field_inventory.csv` | One row per source column. Columns, in order: `table,column,datatype,length,nullable,key,vendor_description,distinct_count,null_pct,min,max,top_values_or_pattern`. Optional 13th column: `blank_pct`. Empty cell = not supplied. | Yes |
| `02_naming_conventions.md` | Part A = source conventions, Part B = target conventions. | Yes (Part B may say "Not supplied") |
| `03_target_model.sql` | `CREATE TABLE` statements for the target, with comments for allowed values. | Yes |
| `04_reference_codes.csv` | Columns: `code_set,source_value,source_meaning,target_value,meaning_status`. `meaning_status` is `Documented`, `Inferred (...)` or `Inferred - confirm with steward`. | If code columns exist |
| `05_sample_<TABLE>.csv` | A few sample rows per source table, header = column names. | Recommended |

If a required input is missing: write the assumption in sheet `0_Header` (item `Assumptions`) and continue. Never invent the missing input.

## 2. Output files (exact names)

| File | Content |
|---|---|
| `01_STM_<SOURCE>_<SCOPE>.xlsx` | The mapping workbook (section 3). Example: `01_STM_MAIL02_EMAIL.xlsx`. |
| `02_ETL_Handoff_Notes.md` | Notes for ETL developers (section 7). |
| `03_Steward_Questions.md` | Open questions (section 8). Same questions as sheet `5_Open_Questions`. |

If you cannot create `.xlsx`: write one CSV per sheet, named `01_STM_<SOURCE>_<SCOPE>__<sheet name>.csv`, UTF-8, comma separated, header row first, values containing commas in double quotes.

## 3. Workbook sheets (exact names, in this order)
`0_Header`, `1_Target_Mapping`, `2_Source_Inventory`, `3_Token_Glossary`, `4_Lookups`, `5_Open_Questions`, `6_Tests_Recon`

### Sheet 0_Header
Columns: `Item`, `Value`. One row for each of these items, in this order:
`STM ID / version` (format `STM-<SOURCE>-<SCOPE> / v0.1 DRAFT (<YYYY-MM-DD>)`), `Source system, version, extract date`, `Target model, version`, `Subject area / target tables`, `Load pattern` (Full / Incremental with the watermark column / CDC / Stream), `Target grain / source grain`, `SCD approach` (per target table: Type 1 / Type 2 / append-only / upsert), `Owners` (Analyst, Steward, ETL lead, Modeler; write `TBD` if unknown), `Assumptions` (numbered list), `Status` (counts of rows by Confidence and Status; number of open questions).

### Sheet 1_Target_Mapping: one row per TARGET column (23 columns, this order)

| # | Column | Allowed values / format |
|---|---|---|
| 1 | STM Row ID | `STM-<AAA>-<nnnn>`: AAA = 3-letter subject code per target table (e.g. ADR, MBX, MSG, RCP), nnnn = 4-digit counter starting at 0001 inside each AAA. Unique. |
| 2 | Target table | `SCHEMA.TABLE` as in the DDL |
| 3 | Target column | exactly as in the DDL |
| 4 | Target business description | short English text |
| 5 | Target datatype | as in the DDL, e.g. `VARCHAR(100)`, `DECIMAL(18,2)` |
| 6 | Nullable / key | e.g. `NOT NULL; PK`, `NULL`, `NOT NULL; FK`, `NOT NULL; business key` |
| 7 | Source table.column(s) | `TABLE.COLUMN`; several separated by `; `; `n/a` for SYSTEM/CONSTANT; `NONE - <what is needed>` if no source exists |
| 8 | Source datatype | e.g. `CHAR(8)`; blank if n/a |
| 9 | Mapping type | exactly one of: `DIRECT`, `TRANSFORM`, `LOOKUP`, `DERIVE`, `CONSTANT`, `SYSTEM`, `SPLIT/MERGE`, `NOT MAPPED` (definitions in `rule-language.md` section 1) |
| 10 | Transformation rule | one executable expression using only functions from `rule-language.md`. Never prose. `TARGET_COLUMN = <expression>` |
| 11 | Join / filter / dedupe | how rows are selected, joined, deduplicated; blank if none |
| 12 | Null handling | what happens when the source value is NULL or blank (see `reject-and-default-policy.md`) |
| 13 | Default value | literal, or blank |
| 14 | Reject / warn handling | `R0n (ROW)` or `R0n (FIELD)` with the trigger; blank if none |
| 15 | Lookup / reference | reference table name (and file) or blank |
| 16 | Data classification | `Public`, `Internal`, `Confidential`, `PII`, `Sensitive` (add detail in brackets if needed) |
| 17 | Masking / exclusion | rule, or blank |
| 18 | Evidence for meaning | text naming the evidence rank (Documented / Steward / Profiled / Usage / Naming / Analogy) with the facts. For Medium and Low rows the text MUST end with `(score NN)` from `inference-and-confidence.md`. |
| 19 | Confidence | `High`, `Medium`, `Low` |
| 20 | Open question | question IDs, e.g. `Q-002, Q-017`, or blank |
| 21 | Test case | test IDs, e.g. `TC-F04, TC-F05` |
| 22 | Status | `Draft`, `Inferred`, `Confirmed`, `Built`, `Tested` |
| 23 | Comments | anything else |

Status assignment when you first write the STM: Confidence High -> `Confirmed`; Medium -> `Inferred`; Low -> `Draft`. Never `Built` or `Tested` (the ETL team sets those).
Every column of every target table in the DDL must have exactly one row.

### Sheet 2_Source_Inventory: one row per SOURCE column (12 columns)
`Source field ID` (`SRC-<SOURCE>-<TABLE>-<COLUMN>`), `Table`, `Column`, `Decoded English name`, `Description`, `Vendor doc?` (`Documented` / `Undocumented`; documented = `vendor_description` not empty), `Datatype` (with length), `Null?` (`Y`/`N`), `Key`, `Profile summary` (copy only numbers from the inventory CSV), `Confidence` (`High`/`Medium`/`Low`), `Disposition`.
Disposition is exactly one of: `Mapped: STM-AAA-nnnn[, STM-AAA-nnnn]` (or a range `STM-AAA-0002..0004`), `Not mapped: <reason>`, `Staged raw only: <reason>`, `Unknown: <impact>`.
Every row of `01_source_field_inventory.csv` must appear once.

### Sheet 3_Token_Glossary (5 columns)
`Token`, `Expansion`, `Rule source` (`Given`, `Derived from documented <COLUMN>`, `Inferred (<evidence>)`), `Confidence`, `Example fields`.

### Sheet 4_Lookups (7 columns)
`Code set`, `Source value`, `Source meaning`, `Target value`, `Status` (copy `meaning_status`, or `Proposed default; confirm (Q-nnn)`), `Effective dates` (`Not supplied; effective dates TBD` if unknown), `Owner`. Include one row per row of `04_reference_codes.csv` plus rows for every default you invented (unlisted values, NULL) marked `Proposed`.

### Sheet 5_Open_Questions (7 columns)
`ID` (`Q-nnn`, 3 digits, unique), `Field(s)`, `Question`, `Evidence`, `Proposed answer`, `Owner`, `Severity / impact`. Severity starts with one of `BLOCKER`, `High`, `Gates production`, `Medium`, `Low` (definitions in `inference-and-confidence.md` section 6).

### Sheet 6_Tests_Recon (4 columns)
`Test ID / Table`, `Target field / Check`, `Input / Query`, `Expected output / Threshold`.
- Field-level test IDs: `TC-<letter(s)><nn>` (for example `TC-F04`). Each has a concrete input value and a concrete expected output.
- Reconciliation IDs: `RC-nn`. Each has a query or comparison and a numeric threshold.
Required coverage: every target column with a non-DIRECT mapping has at least one test; each test set includes the edge cases listed in `self-check.md` section 3.

## 4. Writing rules for all outputs
1. Numbers about the data come only from the supplied inventory, samples or reference files. If a number is not supplied write `not supplied`. Never estimate or compute statistics you cannot see.
2. Every inferred meaning has evidence and a confidence. No exceptions.
3. Use `TBD` only for owner names and effective dates. Any other `TBD`, `TODO`, `...` or `etc.` is a defect.
4. One concept = one name across all sheets (use the exact table and column spelling from the DDL and inventory).

## 5. Template: 02_ETL_Handoff_Notes.md
Use exactly these headings:

```
# ETL Handoff Notes: <SOURCE> <tables> -> DW (STM v0.1 DRAFT)
Companion to `01_STM_...xlsx`. Written for: ETL developers.
## 1. What you can build now vs not      (table: target table | build status; list blockers with Q-ids; list fields NOT to build)
## 2. Load design                         (order of loads; parameters; incremental rule per table; delete handling; restart; volumes)
## 3. Rules that are easy to get wrong    (numbered list, each with the example value from the samples)
## 4. Standard objects                    (reject table DDL, reject codes used, reference tables needed)
## 5. Tool notes                          (Informatica / Talend / Hop, using the snippets in etl-handoff-informatica-talend-hop.md)
## 6. Test and reconciliation             (pointer to sheet 6 and acceptance criteria)
## 7. Sensitive data                      (PII and confidential columns, masking)
```

## 6. Template: 03_Steward_Questions.md
```
# Open Questions: <SOURCE> -> DW (STM v0.1 DRAFT)
Written for: <who answers>. Same list as sheet 5_Open_Questions.
## Blocker (cannot go live without an answer)
## High impact
## Gates production (build can start)
## Medium
## Low
```
Each question: `**Q-nnn: <title>** (owner: <role>)` then `Observed:` (numbers from the profile), `Question:` (one closed question per line), `Proposed:` (your default). See `inference-and-confidence.md` section 6 for the wording rules.
