# ETL Handoff Notes: MAIL02 MSG_HDR / MSG_RCPT / MBX_MST -> DW (STM v0.1 DRAFT)

Companion to `01_STM_MAIL02_EMAIL.xlsx` (the contract; row IDs below refer to its sheet 1). Open questions: `03_Steward_Questions.md`.
Written for: ETL developers (Informatica / Talend / Apache Hop). Component names are from general knowledge, `[VERIFY]` against your installed version.

## 1. What you can build now vs not

| Target | Build status |
|---|---|
| DIM_MAILBOX | Buildable. `MAILBOX_TYPE_CD` values D and G are Low (Q-014): gate production on the answer. |
| FACT_EMAIL_MESSAGE | Buildable. Gate production on Q-003 (timezone), Q-005 (`X` direction), Q-020 (SK -1 member, DIRECTION_CD domain). |
| BRIDGE_EMAIL_RECIPIENT | Buildable. Gate production on Q-008 (delivery status codes) and Q-009 (read flag). |
| DIM_EMAIL_ADDRESS | Buildable **except** `INTERNAL_FLG` (no source list, Q-001: **blocker**, cannot go live). Do not ship with an empty `REF_INTERNAL_DOMAIN`. |

Do **not** build business rules for `USR_FLD_1`. Land it raw in staging only. `UPD_TS` is a watermark, not a target column.

## 2. Load design

- Order: STG -> DIM_EMAIL_ADDRESS -> DIM_MAILBOX -> FACT_EMAIL_MESSAGE -> BRIDGE_EMAIL_RECIPIENT. One batch id spans all four.
- Parameters: `:BATCH_ID`, `:RUN_TS`, `:LAST_WM` (per table, stored in a control table, advanced only after commit).
- `DIM_EMAIL_ADDRESS`: stage the distinct lower-cased addresses from all three sources, **including the addresses of messages and recipients in this batch**, before the fact and bridge load. Upsert on `EMAIL_ADDRESS` (SCD1).
- `DIM_MAILBOX`: full read of `MBX_MST` each run (3,100 rows, no timestamp). Upsert on `MAILBOX_ID`.
- `FACT_EMAIL_MESSAGE`: `WHERE UPD_TS >= :LAST_WM` (use `>=`; the upsert makes it idempotent). Upsert on `MESSAGE_ID`. Within the batch keep the latest `UPD_TS` per `MSG_ID`.
- `BRIDGE_EMAIL_RECIPIENT`: `MSG_RCPT` has no timestamp (Q-012). Until answered, select recipients of messages loaded this batch **plus** messages sent in the last N days (parameter, start with 30) to catch read receipts and delivery updates. Upsert on `(MESSAGE_SK, RECIPIENT_SEQ)`.
- Delete detection: `DEL_FLG` is soft. Physical purges are invisible to an `UPD_TS` pull, so schedule a periodic key compare (Q-013).
- Volumes: about 912k messages, 3.1k mailboxes, 26.4k distinct recipient addresses. Initial load of the bridge will be several million rows: use bulk load, commit in batches `[VERIFY]`.

## 3. Rules that are easy to get wrong

1. **Lower-case and trim every address** before lookup. The same person appears as `Asha.Rao@Example.com` (sender), `asha.rao@example.com` (mailbox) and so on. Without it the dimension duplicates. Make the lookup case-insensitive-safe even if the database collation is case-insensitive.
2. **Split at the LAST `@`.** Local part max 64, domain max 190. An address with no `@`, an empty side, or an oversized side is invalid: use SK -1 and log R02 with the raw value. Do not drop the recipient row (Q-002).
3. **Timezone.** `SENT_TS_UTC = SNT_TS - 5h30m` and `READ_TS_UTC = RD_TS - 5h30m`. The date can roll back (`2026-11-01 02:11` IST = `2026-10-31 20:41` UTC). Do not convert `RECEIVED_DT` (date only, Q-004).
4. **Strict date parse.** `RCV_DT_STR='20260230'` must fail, not roll to March. Sentinels `00000000` and `99999999` -> NULL silently; any other unparseable value -> NULL plus R03 (FIELD). Informatica: guard with `IS_DATE(str,'YYYYMMDD')`; Talend: `TalendDate.isDate(str,"yyyyMMdd")` with non-lenient parsing; Hop: Select Values with lenient off `[VERIFY]`.
5. **NULL is not a default.** `PRIO_CD` NULL -> `UNKNOWN` (not `NORMAL`). `SPM_SCR` NULL stays NULL (not 0). `RD_FLG` NULL -> `U` (not `N`). `DLV_STS` NULL -> `UNKNOWN`.
6. **`READ_FLG`**: `Y`/`N` pass through; NULL with `RD_TS` present -> `Y`; otherwise `U`. `N` with `RD_TS` present stays `N` and logs R07 (FIELD).
7. **Do not derive `SPAM_FLG` from `SPAM_SCORE`** (or the reverse). The source flag is `Y` on 7% of rows but only 2% score above 80 (Q-007).
8. **Display name**: strip only the wrapping double quotes (sample value is literally `"Asha Rao"`); blank -> NULL; do not change case.
9. **Keep leading zeros** in `MSG_ID`, `THRD_ID`: strings, never numbers.
10. **Subject**: no trim, no `RE:`/`FW:` stripping, 500 characters, same as source.
11. **Deleted rows are loaded** with `DELETED_FLG='Y'`; do not filter on `DEL_FLG`.
12. **Lookup failures**: unmatched `MBX_ID` or `MSG_ID` -> suspense (R06), reprocessed next run. Re-resolve suspense rows every run.
13. **Unknown code values**: `DIR_CD` and `RCPT_TYP` -> reject row (R02; no UNKNOWN in the target domain). `PRIO_CD`, `DLV_STS`, `MBX_TYP_CD` -> `UNKNOWN` + R02 (FIELD).

## 4. Standard objects

Reject table (same as CRM01; reuse the one object across projects if the DW is shared):
```sql
CREATE TABLE DW.ETL_REJECT (
  BATCH_ID BIGINT NOT NULL, SRC_TABLE VARCHAR(30) NOT NULL, SRC_KEY VARCHAR(40) NOT NULL,
  FIELD VARCHAR(40), REJECT_CODE CHAR(3) NOT NULL, SEVERITY VARCHAR(5) NOT NULL, -- ROW | FIELD
  REJECT_MESSAGE VARCHAR(200), RAW_VALUE VARCHAR(200), LOAD_TS TIMESTAMP NOT NULL);
```
`RAW_VALUE` for addresses, display names and subjects is PII: mask it or restrict access (Q-019).

Codes: R01 mandatory null, R02 invalid/unmatched code or format, R03 invalid date, R04 overflow, R05 duplicate key, R06 referential failure, R07 inconsistent values. `SEVERITY=FIELD` means the field was nulled/defaulted and the row loaded.

Reference tables (version-controlled): `REF_DIRECTION`, `REF_PRIORITY`, `REF_RECIPIENT_TYPE`, `REF_DELIVERY_STATUS`, `REF_MAILBOX_TYPE` (from `04_reference_codes.csv`), plus `REF_INTERNAL_DOMAIN` (to be supplied, Q-001).

## 5. Tool notes

**Informatica (PowerCenter / IICS CDI)**
- One mapping per target table. Source qualifier SQL carries the `UPD_TS` filter; Expression transformations per STM row; cached Lookups for the five `REF_*` tables.
- Address dimension: Union of the three source address streams -> Expression (lower/trim, split at last `@`, validity flag) -> Aggregator or Sorter+distinct -> Lookup on target -> Router (new insert / existing ignore).
- FACT and BRIDGE: connected Lookups on `DIM_EMAIL_ADDRESS`, `DIM_MAILBOX`, and the fact (for the bridge). Router groups: GOOD, FIELD_WARN (also writes to `ETL_REJECT`), ROW_REJECT, SUSPENSE.
- Parameter file: `$$BATCH_ID`, `$$LAST_WM`, `$$LOOKBACK_DAYS`.

**Talend**
- Parent job `j_mail02_main` runs `j_dim_email_address`, `j_dim_mailbox`, `j_fct_email_message`, `j_brg_email_recipient` via `tRunJob`; context variables per environment.
- `tMap` per target with lookup flows for `REF_*` and the dimensions (unique match; inner-join reject -> suspense). Date rule via `TalendDate.isDate` non-lenient. Shared `tDBOutput` to `ETL_REJECT`; `tLogCatcher` for component errors.
- Address dimension: `tUniqRow` on the lower-cased address across a `tUnite` of the three sources `[VERIFY]`.

**Apache Hop**
- Pipelines: `dim_email_address.hpl`, `dim_mailbox.hpl`, `fct_email_message.hpl`, `brg_email_recipient.hpl`; workflow `mail02_daily.hwf` enforcing the order and updating the watermark only after success.
- Transforms: Table Input -> Formula/Calculator/JavaScript for rules -> Database Lookup or Stream Lookup for `REF_*` and dimensions -> Filter Rows / Switch-Case for routing -> Insert/Update for the upserts. Merge Rows (Diff) is an option for the address union `[VERIFY]`. Error-handling hops to `ETL_REJECT`.
- Use `${PROJECT_HOME}` and environment variables for connections. Use sheet 6 test cases as golden datasets.

## 6. Test and reconciliation

Field-level test cases (`TC-*`) and table-level reconciliation checks (`RC-*`) are in sheet `6_Tests_Recon`; the sample files in `inputs/05_sample_*.csv` already contain cases for dedupe, sentinels, NULL handling, the UTC date roll-back and quoted names. First-load acceptance: counts match after rejects and suspense, `SUM(SZ_BYT)` and `SUM(ATT_CNT)` exact, no duplicates on any business key, no orphan SKs, code distributions within 0.1 pt of the source profile.

## 7. Sensitive data

PII: all email addresses (`EMAIL_ADDRESS`, `EMAIL_LOCAL_PART`), `SENDER_DISPLAY_NAME`. Confidential: `SUBJECT_TXT` (free text, may contain anything), message and thread ids, BCC recipients (reveal hidden recipients). Mask or exclude all of these in non-production per the masking column in sheet 1; get privacy/security sign-off (Q-019) before the first non-prod load. `USR_FLD_1` is excluded (free text).
