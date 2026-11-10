# Reject, Null and Default Policy (normative defaults)

Use these rules for every field unless the STM row states a different rule and says why. They exist so that every developer handles bad data the same way.

## 1. Reject codes

| Code | Name | Typical trigger | Default severity |
|---|---|---|---|
| R01 | Mandatory value missing | Source NULL or blank and the target is NOT NULL with no allowed default | ROW |
| R02 | Invalid or unmatched code or format | Code not in the reference table, value outside the allowed list, bad format | FIELD if the target domain has an `UNKNOWN` (or equivalent) value; otherwise ROW |
| R03 | Invalid date or timestamp | Not a real calendar date, wrong format | FIELD if the target is nullable; otherwise ROW |
| R04 | Overflow | Value longer or larger than the target datatype | ROW (never truncate silently) |
| R05 | Duplicate key | Same business key twice in one batch | ROW (keep the row with the latest watermark, reject the rest) |
| R06 | Referential failure | Parent row (dimension, message, mailbox) not found | ROW, sent to the suspense table and retried next run |
| R07 | Inconsistent values | Two columns contradict each other (for example flag `N` but timestamp present) | FIELD |

Severity meaning:
- `ROW`: the row is NOT loaded to the target. It is written to the reject table (R06 rows also to suspense).
- `FIELD`: the row IS loaded. The field is set to NULL or the default, and one line is written to the reject table.

If a project needs a new code, number it R08, R09 and so on, and list it in sheet `0_Header` under `Assumptions` and in the STM rows that use it.

## 2. Reject table (create once per warehouse)
```sql
CREATE TABLE DW.ETL_REJECT (
  BATCH_ID       BIGINT        NOT NULL,
  SRC_TABLE      VARCHAR(30)   NOT NULL,
  SRC_KEY        VARCHAR(40)   NOT NULL,   -- business key of the source row (concatenate with '|')
  FIELD          VARCHAR(40),              -- source column; NULL for whole-row rejects
  REJECT_CODE    CHAR(3)       NOT NULL,
  SEVERITY       VARCHAR(5)    NOT NULL,   -- ROW | FIELD
  REJECT_MESSAGE VARCHAR(200),
  RAW_VALUE      VARCHAR(200),             -- the offending value; mask or restrict if PII
  LOAD_TS        TIMESTAMP     NOT NULL);
```
Suspense table: same columns as the staged source row plus `BATCH_ID`, `RETRY_COUNT`. Reprocess all suspense rows at the start of each run; after 7 failed retries (default, confirm) move to reject as R06 ROW.

## 3. Decision procedure per field (apply top to bottom, stop at the first match)
1. Source value is NULL or blank (after `TRIM`):
   a. Target is nullable: load NULL. No reject line.
   b. Target is NOT NULL and the STM gives a default: load the default, write R01 (FIELD).
   c. Target is NOT NULL and there is no default: R01 (ROW).
2. Source value is a known sentinel (listed in the naming conventions, for example `00000000` or `99999999` for dates):
   a. Treat as NULL and follow step 1. No reject line for a confirmed sentinel. For an UNCONFIRMED sentinel still treat as NULL but list it as a question.
3. Value fails the format test (not a date, not numeric, bad length):
   a. Date or timestamp: R03. Other formats: R02.
   b. Apply the severity from the table in section 1.
4. Value is a code and has no match in the reference table:
   a. Target domain has `UNKNOWN`: load `UNKNOWN`, R02 (FIELD).
   b. Otherwise R02 (ROW).
5. Value is longer or larger than the target: R04 (ROW). Exception: descriptive free text may be truncated ONLY if the STM row says `truncate to N` and logs R04 (FIELD).
6. Otherwise load the value.

## 4. Default values by datatype (when a default is allowed)
| Target column kind | Default | Never use |
|---|---|---|
| Code with an unknown value in its domain | `UNKNOWN` (or the domain's equivalent such as `UNK`, `ZZ`) | A real code such as `NORMAL` |
| Flag `Y/N` | `U` only if the target allows it; otherwise reject | `N` (it hides missing data) |
| Amount, balance, rate | NULL if nullable; otherwise reject | `0` |
| Date | NULL if nullable; otherwise reject | `1900-01-01`, `9999-12-31` (except SCD end dates) |
| Free text | NULL | `'N/A'`, `'.'` |
| Surrogate key unknown member | `-1` (the dimension must contain that member; ask the modeler) | `0` |
A default must be a value the target's domain permits. If the DDL does not list the domain, ask (question), propose the default, and mark the row Draft.

## 5. Thresholds (defaults, confirm with the ETL lead)
- Warn when ROW rejects exceed 1% of rows read for a table in one batch.
- Stop the batch when ROW rejects exceed 5% of rows read for a table.
- Warn when any single FIELD reject code exceeds 5% of rows for a column.
- Never silently drop rows: rows read = rows loaded + ROW rejects + suspense, and this must reconcile exactly.

## 6. Audit columns
Use the audit columns that exist in the target DDL. The usual set is `SRC_SYSTEM_CD` (CONSTANT), `BATCH_ID` (`:BATCH_ID`), `LOAD_TS` (`:RUN_TS`). Do not add `ROW_HASH`, `DELETE_FLG` or others to the STM unless the target has them. A row hash may exist in staging for change detection; document it in the handoff notes, not as a target column.

## 7. Privacy
`RAW_VALUE` can contain PII (names, emails, dates of birth, subjects). Rule: store the raw value only if the reject table is access-restricted; otherwise store a masked value (for example the first 2 characters plus `***`) or leave it NULL. State which in the handoff notes.
