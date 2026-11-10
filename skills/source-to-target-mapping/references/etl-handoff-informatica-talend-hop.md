# ETL Developer Handoff: Informatica, Talend, Apache Hop

The STM rule is tool-neutral (`rule-language.md`). This file gives the recipes and per-tool snippets to put in `02_ETL_Handoff_Notes.md` (template in `output-formats.md` section 5). Snippets come from general product knowledge: prove each one with its `TC-*` test case from sheet 6 before relying on it.

## 1. What every developer receives
1. The STM workbook (all sheets), version-stamped.
2. Test cases with exact input and expected output (sheet 6).
3. Reject, null and default policy (`reject-and-default-policy.md`) and the reject table DDL.
4. Load pattern: watermark column, delete handling, restart behaviour, parameters.
5. Naming standards (section 2) and the reference tables to create.
6. Reconciliation queries and thresholds.
7. The list of Inferred and Low fields. Developers do not build Low fields.

## 2. Naming standards (use these unless the project has its own)
| Object | Informatica | Talend | Hop |
|---|---|---|---|
| One unit per target table | `m_<target>` mapping, `wf_<source>_daily` workflow | `j_<target>` job, `j_<source>_main` parent | `<target>.hpl` pipeline, `<source>_daily.hwf` workflow |
| Parameters | `$$BATCH_ID`, `$$RUN_TS`, `$$LAST_WM_<TABLE>` | context `BATCH_ID`, `RUN_TS`, `LAST_WM_<TABLE>` | `${BATCH_ID}`, `${RUN_TS}`, `${LAST_WM_<TABLE>}` |
| Connections | named per environment, no passwords in code | repository metadata per environment | environment files / variables |

## 3. Recipes (identical logic in every tool)

### 3.1 Parameters and control table
Control table `DW.ETL_CONTROL(SOURCE, TARGET_TABLE, LAST_WM, LAST_RUN_TS, STATUS)`. Each run:
1. Read `LAST_WM` for the table. If no row, use `1900-01-01 00:00:00` for the initial load.
2. Read source rows with `WHERE UPD_TS >= :LAST_WM` (use `>=`, not `>`).
3. Process, load, commit.
4. Only after commit: `UPDATE ETL_CONTROL SET LAST_WM = MAX(UPD_TS read this run)`.
Why `>=`: rows with the same timestamp as the watermark arrive in the next run too; the upsert makes this safe.

### 3.2 Idempotent load (upsert on business key)
Two accepted forms, pick one per table and say which in the notes:
- Merge: `MERGE INTO target USING staged ON business_key WHEN MATCHED AND hash differs THEN UPDATE WHEN NOT MATCHED THEN INSERT`.
- Lookup + route: lookup target by business key; not found = insert; found and `ROW_HASH` differs = update; found and hash equal = ignore.
Rerunning the same batch must change nothing (test `TC-*08`-style: "Rerun idempotency").

### 3.3 Change detection hash
`ROW_HASH = HASH_ROW(<tracked columns in fixed order>)` computed on the TRANSFORMED values (what will be written), not the raw source. NULL = `'~NULL~'`. Store the hash in staging (and in the target only if the DDL has a hash column).

### 3.4 SCD Type 1 (overwrite)
Upsert on the business key (3.2). Update only when the hash differs. Never touch the surrogate key of an existing row.

### 3.5 SCD Type 2 (history)
Per business key, in order of source change time (`UPD_TS`) when several changes arrive in one batch:
1. Compute `ROW_HASH` over the tracked columns.
2. Lookup the current row: `business key = x AND CURRENT_FLG = 'Y'`.
3. Not found: insert a new row: new surrogate key, `EFF_FROM_TS` = the effective timestamp (the STM states which: default `:RUN_TS`), `EFF_TO_TS = TIMESTAMP '9999-12-31 00:00:00'`, `CURRENT_FLG = 'Y'`.
4. Found and hash equal: ignore (no new version for untracked-column changes).
5. Found and hash differs: (a) update the old row: `EFF_TO_TS` = new `EFF_FROM_TS`, `CURRENT_FLG = 'N'`; (b) insert the new version as in step 3.
The validity window is half-open `[EFF_FROM_TS, EFF_TO_TS)`: no gaps and no overlaps between versions. Facts and child dimensions look up the row with `CURRENT_FLG = 'Y'` at load time (state this).

### 3.6 Delete handling
- Soft delete flag in the source: load the flag as data; do not filter rows by it unless the STM says so.
- Physical deletes: invisible to a watermark pull. Schedule a periodic full compare of business keys (source vs target) and mark missing keys deleted per the STM. Default frequency: weekly.

### 3.7 Full snapshot facts (daily balances and similar)
Read the FULL source each day, not a watermark filter. Rerun = `DELETE FROM fact WHERE snapshot_dt = :BUSINESS_DT` then insert. `:BUSINESS_DT` is a parameter, never derived from the data.

### 3.8 Late-arriving parents
A child row whose parent is not found goes to suspense (R06), not to a default parent. Re-resolve suspense rows at the start of every run.

### 3.9 Restart and recovery
- Every table load is one transaction per batch where volume allows; otherwise commit every 10,000-50,000 rows and make the load idempotent (3.2) so a restart repeats safely.
- The watermark moves only after commit (3.1).
- Rejects and suspense rows carry `BATCH_ID`.

### 3.10 Volumes and lookups
- Reference tables below about 1 million rows: cache fully. Above that, use a database join or sorted merge.
- Initial loads of tens of millions of rows: use bulk load, disable non-essential indexes, rebuild after.

## 4. Per-rule snippets
`A` and `B` are source columns. Use the tool's own naming for the port or field.

### Informatica (PowerCenter / IICS CDI)
| Need | Expression |
|---|---|
| Trim | `LTRIM(RTRIM(A))` |
| Blank to NULL | `IIF(LTRIM(RTRIM(A)) = '', NULL, LTRIM(RTRIM(A)))` |
| Lower-case address | `LOWER(LTRIM(RTRIM(A)))` |
| Strict date, sentinels to NULL | `IIF(A='00000000' OR A='99999999', NULL, IIF(IS_DATE(A,'YYYYMMDD'), TO_DATE(A,'YYYYMMDD'), NULL))` |
| Reject flag for a bad date | output port `o_bad_date = IIF(NOT(A='00000000' OR A='99999999') AND NOT IS_DATE(A,'YYYYMMDD'), 1, 0)`; Router group `FIELD_WARN` on `o_bad_date = 1` |
| Lookup with default | after an unconnected/connected Lookup returning `lkp_out`: `IIF(ISNULL(lkp_out), 'UNKNOWN', lkp_out)` |
| Shift minutes (IST to UTC) | `ADD_TO_DATE(A, 'MI', -330)` |
| Last position of `@` | `INSTR(A, '@', -1, 1)` |
| Row hash | `MD5(IIF(ISNULL(A),'~NULL~',TO_CHAR(A)) || '\|' || IIF(ISNULL(B),'~NULL~',TO_CHAR(B)))` (write `'|'` in the tool) |
| Insert / update / ignore | Router groups `NEW`, `CHANGED`, `UNCHANGED`; Update Strategy `DD_INSERT` / `DD_UPDATE`; `UNCHANGED` goes nowhere |
Structure: one mapping per target table. Source qualifier SQL carries the watermark filter. Router groups: `GOOD`, `FIELD_WARN` (load and write reject), `ROW_REJECT`, `SUSPENSE`. Check decimal precision on balance ports.

### Talend (expressions in `tMap`)
| Need | Expression |
|---|---|
| Trim | `StringHandling.TRIM(row1.A)` |
| Blank to NULL | `(row1.A == null \|\| StringHandling.TRIM(row1.A).equals("")) ? null : StringHandling.TRIM(row1.A)` |
| Lower-case | `StringHandling.DOWNCASE(StringHandling.TRIM(row1.A))` |
| Strict date, sentinels to NULL | `("00000000".equals(row1.A) \|\| "99999999".equals(row1.A)) ? null : (TalendDate.isDate(row1.A,"yyyyMMdd") ? TalendDate.parseDate("yyyyMMdd", row1.A) : null)` (confirm that `20260230` is rejected: use test `TC-F09`) |
| Lookup with default | tMap lookup flow, match model "Unique match"; output `row2.target_value == null ? "UNKNOWN" : row2.target_value` |
| Shift minutes | `TalendDate.addDate(row1.A, -330, "mm")` |
| Last position of `@` | `row1.A.lastIndexOf('@') + 1` |
| Row hash | `org.apache.commons.codec.digest.DigestUtils.md5Hex((row1.A==null?"~NULL~":row1.A) + "\|" + (row1.B==null?"~NULL~":row1.B))` (write `"|"` in the tool) |
Structure: parent job `j_<source>_main` runs child jobs with `tRunJob` in load order; context variables per environment. One `tMap` per target with: lookup flows, an inner-join reject output (suspense), and a rule-reject output feeding a shared `tDBOutput` to `ETL_REJECT`. Define metadata schemas once (repository) and reuse. Use `tLogCatcher` for component errors.

### Apache Hop
| Need | Transform |
|---|---|
| Trim, case | String operations (trim both, lower) |
| Blank to NULL | If Null / Value Mapper, or Modified JavaScript `if (a == null \|\| a.trim() == '') a = null;` |
| Strict date | Select values: metadata change String to Date, format `yyyyMMdd`, lenient conversion OFF; failures take the error-handling hop to `ETL_REJECT` (R03). Sentinels first: Filter Rows or Value Mapper to NULL |
| Lookup with default | Database Lookup (cached) or Stream Lookup; default value field set to `UNKNOWN` |
| Shift minutes | Calculator "Add days" does not do minutes: use Modified JavaScript or Formula with fractional days |
| Last position of `@` | Modified JavaScript: `var pos = a.lastIndexOf('@') + 1;` |
| Row hash | Add a checksum (MD5) transform over the fields in fixed order (replace NULL with `~NULL~` first) |
| Insert / update / ignore | Filter Rows or Switch/Case on hash comparison; Insert/Update or Dimension Lookup/Update (type 2) |
Structure: one pipeline (`.hpl`) per target table and one workflow (`.hwf`) per source, enforcing load order and writing the watermark after success. Use project and environment variables for connections. Hop is stream-based: sort inputs before Merge Join; size memory for Stream Lookup.

## 5. Reconciliation queries to hand over (adapt names)
```sql
-- Row reconciliation per table (must equal 0)
SELECT (SELECT COUNT(*) FROM <staged source rows in scope>)
     - (SELECT COUNT(*) FROM <target> WHERE BATCH_ID = :BATCH_ID)
     - (SELECT COUNT(*) FROM DW.ETL_REJECT WHERE BATCH_ID = :BATCH_ID AND SRC_TABLE = '<T>' AND SEVERITY = 'ROW')
     - (SELECT COUNT(*) FROM <suspense> WHERE BATCH_ID = :BATCH_ID) AS difference;
-- Sum check on a measure
SELECT SUM(<source measure>) FROM <source in scope>;  -- compare with
SELECT SUM(<target measure>) FROM <target> WHERE BATCH_ID = :BATCH_ID;
-- Duplicate business keys (must return no rows)
SELECT <key>, COUNT(*) FROM <target> GROUP BY <key> HAVING COUNT(*) > 1;
```
Note: with upserts, a rerun updates rows rather than inserting them, so count rows by `BATCH_ID` only for the first load; for reruns compare against the watermark window.

## 6. Metadata-driven option
If the mapping count is in the hundreds, generate mappings from STM tables instead of building each by hand. Recommend it only after the first manual wave has proven the rule patterns. The decision belongs to the integration architect.
