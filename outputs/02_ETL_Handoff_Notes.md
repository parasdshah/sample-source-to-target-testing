# ETL Handoff Notes: CRM01 CUST_MST / ACCT_MST -> DW (STM v0.1 DRAFT)

Companion to `01_STM_CRM01_CUST_ACCT.xlsx` (the contract; row IDs below refer to its sheet 1).
Written for: ETL developers (Informatica / Talend / Apache Hop). Component names are from general knowledge, `[VERIFY]` against your installed version.

## 1. What you can build now vs not

| Target | Build status |
|---|---|
| DIM_ACCOUNT | Buildable. Inferred fields (INT_RT, OD_LMT, CLOSE_DT) need steward sign-off before production, not before development. |
| FCT_ACCOUNT_BALANCE_DAILY | Buildable. CUR_BAL/AVL_BAL meaning and sign convention need sign-off before production (Q-010). |
| DIM_CUSTOMER | Buildable **except** `CUSTOMER_SEGMENT_CD` (no source, Q-001: **blocker**, cannot go live) and `RELATIONSHIP_MGR_ID` (Low, loads NULL, Q-005). Build KYC (Q-003) but gate production on steward answer. |

Do **not** build business rules for: `RM_ID`, `PRC_GRP_CD`, `USR_FLD_1`. Land them raw in staging only.

## 2. Load design

- Order: STG -> DIM_CUSTOMER -> DIM_ACCOUNT -> FCT_ACCOUNT_BALANCE_DAILY. One batch id spans all three.
- Parameters: `:BATCH_ID`, `:RUN_TS`, `:BUSINESS_DT` (snapshot date, **not** derived from data), `:LAST_WM` (per table, stored in a control table).
- Incremental: `WHERE UPD_TS >= :LAST_WM` (use `>=` and rely on hash comparison for idempotency). Update `:LAST_WM` only after commit.
- Delete detection: DEL_FLG is a soft flag. Physical deletes will not show up in an UPD_TS pull. Schedule a periodic full key compare (Q-007).
- Fact: **full** ACCT_MST snapshot daily, not UPD_TS-filtered, because dormant/closed accounts have old UPD_TS but still need a row. Restart/rerun: `DELETE FROM FCT WHERE BALANCE_DT = :BUSINESS_DT` then insert. Source has no history, so a missed day cannot be recovered from ACCT_MST.
- Volumes: ~48k customers, ~91.5k accounts/day. Small enough that lookups can be fully cached.

## 3. Rules that are easy to get wrong

1. **Strict date parsing.** `DOB_STR='19990229'` must fail, not roll to 1 March. Informatica: guard with `IS_DATE(str,'YYYYMMDD')` before `TO_DATE`; Talend: `TalendDate.isDate(str,"yyyyMMdd")` (non-lenient) or `setLenient(false)`; Hop: Select Values with date conversion and lenient = false `[VERIFY]`.
2. **Sentinels.** `00000000` / `99999999` (DOB) -> NULL silently. `99991231` (CLS_DT) -> NULL silently. Any other unparseable date -> NULL plus a DQ log row (R03) for nullable targets; reject the row for NOT NULL targets.
3. **Keep leading zeros.** CUST_ID, ACCT_NO, BR_CD, ACCT_TYP_CD are strings. Never cast to number.
4. **Percent, not fraction.** `INT_RT` loads as-is into `INTEREST_RATE_PCT`; NULL stays NULL, never 0.
5. **Signs.** `CUR_BAL`/`AVL_BAL` pass through with sign and scale (18,2). No rounding.
6. **Country default is `'ZZ'`**, not `'UNK'` (CHAR(2)). Needs modeler OK (Q-019).
7. **SCD2 no-op suppression.** UPD_TS changes on every update, including untracked fields. Compute `ROW_HASH` over the transformed business columns and only version on hash change. Use the same rule on DIM_ACCOUNT merge to avoid pointless updates.
8. **Account -> customer FK.** Look up `CURRENT_FLG='Y'`. Unmatched (~9 rows) go to suspense (R06), reprocessed next run. Re-resolve CUSTOMER_SK for all staged accounts each run (Q-017).
9. **Mobile.** Prefix dial code only for 10-digit numbers without `+`, using the customer's country; otherwise NULL + R02.

## 4. Standard objects

Reject table:
```sql
CREATE TABLE DW.ETL_REJECT (
  BATCH_ID BIGINT NOT NULL, SRC_TABLE VARCHAR(30) NOT NULL, SRC_KEY VARCHAR(40) NOT NULL,
  FIELD VARCHAR(40), REJECT_CODE CHAR(3) NOT NULL, SEVERITY VARCHAR(5) NOT NULL, -- ROW | FIELD
  REJECT_MESSAGE VARCHAR(200), RAW_VALUE VARCHAR(200), LOAD_TS TIMESTAMP NOT NULL);
```
`RAW_VALUE` for PII fields (DOB, mobile, email, name) must be masked or access-restricted (privacy review).

Codes: R01 mandatory null, R02 invalid/unmatched code or format, R03 invalid date, R04 overflow, R05 duplicate key, R06 referential failure. SEVERITY=FIELD means the field was nulled/defaulted and the row loaded.

## 5. Tool notes

**Informatica (PowerCenter / IICS CDI)**
- One mapping per target table. Source qualifier SQL with the UPD_TS filter; Expression transformations per STM row; connected cached Lookups for REF_* (return `target_value`, no-match default per rule); DIM_CUSTOMER SCD2 via Lookup on current row + Router (insert / close-and-insert / ignore) + Update Strategy, or IICS SCD template `[VERIFY]`.
- Router groups: GOOD, FIELD_WARN (also writes to ETL_REJECT), ROW_REJECT.
- Parameterise connections, `$$BATCH_ID`, `$$BUSINESS_DT`, `$$LAST_WM` in the parameter file. Check decimal precision on balance ports (18,2).

**Talend**
- Parent job `j_crm01_main` calls `j_dim_customer`, `j_dim_account`, `j_fct_balance` via `tRunJob`; context variables per environment; no hard-coded connections.
- `tMap` per target: lookup flows for REF_* and for DIM_CUSTOMER (match model: unique match, inner join reject -> R06 suspense). Reject outputs feed a shared `tDBOutput` to ETL_REJECT. Use `tLogCatcher` for component errors.
- Define repository metadata schemas once (CUST_MST, ACCT_MST, targets). SCD2 via `tMap` pattern or SCD components if your edition has them `[VERIFY]`.

**Apache Hop**
- Pipelines: `dim_customer.hpl`, `dim_account.hpl`, `fct_balance.hpl`; workflow `crm01_daily.hwf` enforcing the order and writing the watermark after success.
- Transforms: Table Input (UPD_TS filter) -> Formula/Calculator/JavaScript for rules -> Database Lookup or Stream Lookup for REF_* -> Filter Rows/Switch-Case for routing -> Dimension Lookup/Update for DIM_CUSTOMER (type 2) `[VERIFY]`. Error-handling hops to ETL_REJECT.
- Use `${PROJECT_HOME}` and environment variables for connections. Use STM sheet 6 test cases as golden datasets.

## 6. Test and reconciliation

Field-level test cases (50) and table-level reconciliation checks are in sheet `6_Tests_Recon`. First-load acceptance: row counts match after accounting for rejects, sums by currency exact to 0.00, no PK duplicates, no SCD window gaps/overlaps, code distributions within 0.1 pt of source profile.

## 7. Sensitive data

PII: CUSTOMER_NAME, BIRTH_DT, MOBILE_NO, EMAIL_ADDR, RELATIONSHIP_MGR_ID (staff id). Confidential: CUSTOMER_ID, ACCOUNT_NO, balances, overdraft limit, KYC status. `USR_FLD_1` is excluded (free text, may hold PII). Mask all of these in non-production per the masking column in sheet 1; confirm with privacy/security before the first non-prod load.
