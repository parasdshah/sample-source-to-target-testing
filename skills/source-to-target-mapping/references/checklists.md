# Checklists

Every item says HOW to check it. Run `scripts/check_stm.py` for the items marked `[auto]`; do the others by reading. `self-check.md` explains each automatic check and the manual ones in detail.

## 1. Intake (before mapping)
| Item | How to check | If missing |
|---|---|---|
| Source field list (`01_source_field_inventory.csv`) | file exists; header has the 12 required columns | Stop and ask. Cannot proceed without it. |
| Documented vs undocumented count | count rows where `vendor_description` is non-empty | Report the percentage in the summary |
| Naming conventions (`02_naming_conventions.md`) | Part A present | Use the dictionary only; all meanings Medium or lower; state the assumption |
| Target conventions (Part B) | Part B present or says `Not supplied` | Infer from the DDL; add the Part B question |
| Target model (`03_target_model.sql`) | every `CREATE TABLE` parses; keys and NOT NULL visible | Stop and ask. |
| Reference codes (`04_reference_codes.csv`) | exists if any column name ends in `_CD` or `_TYP` or `_STS` | Ask; propose codes from the profile; mark Inferred |
| Sample rows (`05_sample_*.csv`) | one per source table | Proceed; tests use values from the inventory only |
| Existing SQL/reports | any file provided | Proceed; usage evidence = none |
| Load pattern and tool | stated in the request or inputs | Assume Incremental on the update timestamp if one exists, else Full; state the assumption |
| Sensitivity rules | stated | Apply the default classification list in section 5 of this file |

## 2. Mapping quality (per target table) [auto where marked]
- [auto] Every target column in the DDL has exactly one row in `1_Target_Mapping`; no extra rows.
- [auto] Every NOT NULL target column is not `NOT MAPPED`.
- [auto] Mapping type, Confidence and Status use only the allowed values.
- [auto] Row IDs are unique and match `STM-AAA-nnnn`.
- [auto] Every `Q-nnn` and `TC-...` cited exists in sheets 5 and 6.
- [auto] Confidence `Low` is never Status `Confirmed`.
- Manual: for every DIRECT row compare source length with target length (target must be >= source) and datatype family (text to text, number to number, date to date).
- Manual: every rule uses only the functions in `rule-language.md`.
- Manual: every row with a Null handling entry follows `reject-and-default-policy.md`.
- Manual: grain of source and target stated in `0_Header`; check for row multiplication in every join.
- Manual: date format and timezone stated for every date/timestamp column.
- Manual: PII columns have a masking rule.
- Manual: Medium and Low rows end their evidence text with `(score NN)`.

## 3. Source coverage [auto]
- Every row of the inventory appears once in `2_Source_Inventory`.
- Every disposition is `Mapped: ...`, `Not mapped: ...`, `Staged raw only: ...` or `Unknown: ...`.
- Every STM ID inside a `Mapped:` disposition exists in sheet 1.
- Manual: unknown fields have a business impact stated; legacy, filler and `USR_FLD` columns are profiled or listed as unknown.

## 4. Review gates (who approves what)
| Gate | Reviewer | Pass criteria | Evidence of passing |
|---|---|---|---|
| Meaning review | Data steward / SME | Inferred meanings confirmed or corrected; open questions answered or accepted as risk | Answers recorded in sheet 5; scores updated |
| Model fit review | Data modeler / architect | Grain, keys, SCD, missing attributes resolved | Questions with owner `Modeler` closed |
| Buildability review | ETL lead | Rules unambiguous, parameterised, testable; pushdown and performance raised | Sign-off note in `0_Header` |
| Data quality review | DQ engineer | DQ rules and thresholds defined for the target | Thresholds in sheet 6 |
| Compliance review | Privacy / security | PII handled and masked per policy | Masking column complete |

## 5. Default sensitivity classification (when no policy is supplied)
| Class | Examples (by name or content) |
|---|---|
| Sensitive | national ids (`PAN`, `SSN`, `NID`), passwords, health data, card numbers |
| PII | person name, date of birth, phone, email, postal address, IP address, free-text notes, message subjects |
| Confidential | account numbers, balances, limits, KYC status, message ids, employee ids |
| Internal | codes, flags, counts, timestamps with no person link |
| Public | published reference data |
When in doubt, choose the higher class and add a question.

## 6. Handoff (before you tell the user the STM is ready)
- All three output files exist with the exact names.
- `scripts/check_stm.py` prints `RESULT: PASS` (warnings are allowed but must be listed in your summary).
- Counts in `0_Header` `Status` match the sheets.
- Blocker questions are listed first in the summary.

## 7. Post-build (the ETL team does this; include it in the handoff notes)
- Reconciliation: row counts, sums, distinct keys, null rates against the thresholds in sheet 6.
- All field-level test cases passed.
- Reject volumes within the thresholds in `reject-and-default-policy.md`.
- Confirmed meanings and lineage published to the catalogue; open questions closed or carried as logged risks.
