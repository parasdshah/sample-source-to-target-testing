# Self-check (run before you tell the user the STM is ready)

Weaker models forget things. This file turns "be careful" into checks you can run.

## 1. Run the checker (if you can run Python)
```
pip install openpyxl
python skills/source-to-target-mapping/scripts/check_stm.py projects/<NAME>
```
It prints `FAIL` lines (must be fixed), `WARN` lines (fix or explain in your summary) and `RESULT: PASS` or `RESULT: FAIL`. Do not report the STM as ready while the result is FAIL.

## 2. What each automatic check means (do these by hand if you cannot run Python)
| Check | What it tests | How to fix a failure |
|---|---|---|
| C01 files | `02_ETL_Handoff_Notes.md` and `03_Steward_Questions.md` exist next to the workbook | Write the missing file |
| C02 sheets | the seven sheets exist with the exact names and order | Rename or add sheets |
| C03 columns | sheet 1 has the 23 standard columns, sheet 2 has 12, sheet 5 starts with 7 | Restore the standard header (`output-formats.md`) |
| C04 row ids | `STM-AAA-nnnn`, all unique | Renumber the later duplicate |
| C05 coverage | every `CREATE TABLE` column in the DDL has exactly one row in sheet 1; no extra rows | Add the missing row or delete the extra |
| C06 values | mapping type, confidence and status use only the allowed words | Move any explanation into Comments or the evidence text |
| C07 mandatory | a NOT NULL target column is never `NOT MAPPED`, unless the row is `Draft` and cites a `BLOCKER` question | Add a source, default or derivation, or raise a BLOCKER question and set status `Draft` |
| C08 low confirmed | a `Low` row is not `Confirmed`, `Built` or `Tested` | Set status `Draft` |
| C09 rule | non-trivial rows have a rule written as `COLUMN = expression` | Rewrite using `rule-language.md` |
| C10 score | Medium and Low rows end the evidence with `(score NN)`; a no-source row is not High | Compute the score (`inference-and-confidence.md` section 3) |
| C11 source coverage | every inventory row appears exactly once in sheet 2 | Add the row |
| C12 disposition | each disposition is one of the four allowed forms; every STM id in it exists | Fix the text or the id |
| C13 references | every `Q-nnn` and `TC-`/`RC-` id cited exists in sheet 5 or 6; severities use the allowed words; every non-DIRECT row has a test | Add the question or test |
| C14 question file | every sheet-5 question appears in `03_Steward_Questions.md` | Copy it across |
| C15 lookups | every code set in `04_reference_codes.csv` appears in sheet 4 and is used by a rule | Add the rows or the rule |
| C16 placeholder | no `TODO`, `...`, `etc.` | Replace with real text or `not supplied` |
| C17 invented numbers | every `distinct N` in a profile summary exists in the inventory file | Copy the number from the inventory |
| C18 header | sheet 0 has the required items | Add them |

## 3. Manual checks the script cannot do
1. **Datatype and length.** For each DIRECT or TRANSFORM row: target length >= source length (otherwise add an R04 rule), same datatype family. Example: source `CHAR(8)` to target `DATE` is a TRANSFORM, not a DIRECT.
2. **Every code column.** For each source column ending in `_CD`, `_TYP`, `_STS`: a `LOOKUP` rule, a reference-table row, and a no-match behaviour.
3. **Every date/timestamp column.** Format stated, sentinel values handled, timezone stated. Test: valid, sentinel, invalid, NULL.
4. **Sentinels.** Every value the conventions call "not available" is handled in the rule.
5. **Grain.** `0_Header` states source and target grain. Every join in sheet 1 lists the join key and says whether it can multiply rows.
6. **Keys.** Every foreign key target column names its parent table and the missing-parent behaviour (R06 suspense or default member).
7. **PII.** Every PII or Sensitive column has a masking rule.
8. **Numbers.** Any number you wrote in the summary or notes (percentages, counts) can be found in the inputs, or is arithmetic on numbers that can.
9. **Naming.** Spelling of tables and columns is identical in all sheets and files (copy from the DDL and the inventory).

## 4. Edge cases every test set must include (sheet 6)
For each target column with a TRANSFORM, DERIVE or LOOKUP rule, write tests for:
| Column kind | Required cases |
|---|---|
| Any nullable input | NULL; blank string; spaces only |
| String | maximum length; value with leading and trailing spaces; value with special characters or quotes |
| Date from text | valid; each sentinel; impossible date (`20260230`); wrong length; NULL |
| Timestamp conversion | a normal value; a value that crosses midnight (the date changes); a leap day if relevant |
| Code lookup | each known code; an unlisted code; NULL |
| Flag | `Y`, `N`, NULL, and any unexpected value |
| Number | zero; negative; maximum scale; NULL (not converted to 0) |
| Key / FK | existing parent; missing parent; duplicate business key in one batch |
Each test states a concrete input and a concrete expected output. Use the values from the sample files where they exist (cite the sample row).

Reconciliation checks (RC-nn) must cover: row counts per table with rejects and suspense, sums of every numeric measure, distinct counts of every business key, null rates for nullable columns, distribution of every code column, orphan foreign keys, and duplicate business keys, each with a numeric threshold.

## 5. Final summary the user receives
State, in this order:
1. Files written (names).
2. Counts: target columns mapped (by Confidence), source columns by disposition, questions by severity.
3. Blockers (question IDs and one line each).
4. Anything you could not do or had to assume.
5. The checker result (`PASS`, or the remaining `FAIL`/`WARN` lines).
