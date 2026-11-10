# STM Template

One row per **target attribute** (primary view). Keep a second sheet listing every **source field** and its disposition so nothing is lost.

## Header block
| Item | Value |
|---|---|
| STM ID / version | |
| Source system, version, extract date | |
| Target model, version | |
| Subject area / target table(s) | |
| Load pattern | Full / Incremental (watermark column) / CDC / Stream |
| Target grain, source grain | |
| SCD approach | Type 1 / 2 / append-only |
| Owners | Analyst, Steward, ETL lead, Modeler |
| Assumptions | |
| Status | Draft / Inferred / Confirmed / Built / Tested |

## Sheet 1: Target-centric mapping (columns)
| # | Column | Notes |
|---|---|---|
| 1 | STM Row ID | `STM-<subject>-<nnnn>` |
| 2 | Target table | |
| 3 | Target column | |
| 4 | Target business name / description | |
| 5 | Target datatype, length, precision | |
| 6 | Target nullable, PK/FK, unique | |
| 7 | Source system / table / column(s) | Multiple allowed |
| 8 | Source datatype, length | |
| 9 | Mapping type | DIRECT, TRANSFORM, LOOKUP, DERIVE, CONSTANT, SYSTEM, SPLIT/MERGE, NOT MAPPED |
| 10 | Transformation rule | Neutral SQL-style expression |
| 11 | Join / filter / dedupe logic | |
| 12 | Null handling | Reject / default value / pass through |
| 13 | Default value | |
| 14 | Reject code and handling | |
| 15 | Lookup / reference table | Name and version |
| 16 | Data classification | Public / Internal / Confidential / PII / Sensitive |
| 17 | Masking / exclusion rule | |
| 18 | Evidence for meaning | Documented / Profiled / Usage / Naming / Analogy, with reference |
| 19 | Confidence | High / Medium / Low |
| 20 | Open question ID | Link to steward log |
| 21 | Test case ID | |
| 22 | Status | |
| 23 | Comments | |

## Sheet 2: Source-centric inventory
Source field ID, table, column, decoded English name, description, datatype, nullability, profile summary (distinct count, null %, min/max, top values, pattern), confidence, disposition (Mapped to <target ids> / Not mapped: reason / Staged raw only / Unknown).

## Sheet 3: Token glossary
Token, expansion, rule source (given convention / inferred), confidence, examples.

## Sheet 4: Lookups and code translations
Source code set, source value, source meaning, target value, effective dates, owner.

## Sheet 5: Open questions (steward log)
ID, field(s), question, evidence, proposed answer, owner, due date, answer, date closed.

## Sheet 6: Reconciliation and tests
Table-level: row counts, sum/hash on measures, distinct counts on keys, null-rate by column, domain checks, referential integrity. Field-level: input value → expected output, including edge cases (nulls, blanks, max length, invalid dates, unknown codes).

## Example rows
| Target | Source | Type | Rule | Null | Reject |
|---|---|---|---|---|---|
| CUSTOMER.BIRTH_DT | CUST_MST.DOB_STR (CHAR 8) | TRANSFORM | `TO_DATE(DOB_STR,'YYYYMMDD')`; treat `'00000000'` and `'99999999'` as null | allow null | invalid format → R03 |
| CUSTOMER.COUNTRY_CD | CUST_MST.CTRY_CD | LOOKUP | `LKP(REF_COUNTRY_ISO, CTRY_CD)` | default `'UNK'` | unmatched → log in DQ exceptions |
| CUSTOMER.SRC_SYSTEM_CD | n/a | CONSTANT | `'CRM01'` | not null | n/a |
