# ETL Handoff Notes: HRA01 + HRB02 HRMS -> HR_DW (STM v0.1 DRAFT)

Companion to `01_STM_HRA01_HRB02_HRMS.xlsx`. Written for: ETL developers.
Two source systems feed one target. HRA01 is the acquirer's global HRMS. HRB02 is the acquired company's HRMS, partitioned by management region (APAC, EMEA, AMER). The same person can appear several times, so the hard part is person matching, not column mapping.

## 1. What you can build now vs not

| Target table | Build status |
|---|---|
| `DIM_ENTITY` | Build. Keys carry a source prefix ('A-', 'B-') until a group crosswalk exists (Q-020). |
| `DIM_DEPARTMENT` | Build, including `STG_ORG_MAP`. The level roll-up is pending Q-010 and Q-011; keep it in one place so it can change. |
| `DIM_REGION` | Build, including `STG_LOC_MAP` and the alias lookup. Level 4 (`REGION_L4_NM`) is a placeholder (Low, Draft) and `ACTIVE_FLG` for HRB02 sites is assumed (Q-012). |
| `XREF_PERSON_SOURCE`, `DIM_PERSON` | Build the pipeline, but the match rules are NOT approved (BLOCKER Q-002). Run only in a development environment. Do not load production. |
| `FACT_EMPLOYMENT` | Build. `PERSON_SK` depends on the XREF and therefore on Q-002. |
| `FACT_ASSIGNMENT` | Build. Grade crosswalk (Q-014) and manager resolution (Q-025) are open. |

BLOCKERS (cannot go live): **Q-001** retention period and expired records (decides which records may be loaded; `RETENTION_END_DT` is Low/Draft), **Q-002** person-matching rules and who works the review queue.

Do NOT build or load: `EMP_JOB_HST.BASE_SAL_AMT` (compensation, out of scope), `ORG_UNIT.LEG_ENT_CD`, `HR_SITE.REGION_CD`, `HR_ASSIGN.SEQ_NO` (used only to order rows in staging), office names `LOC_NM` and `SITE_NM`, `EMP_JOB_HST.JOB_CD`. Stage them raw if you need them later.

## 2. Load design

Parameters: `:SRC_SYSTEM_CD` ('HRA01' or 'HRB02', one run of each flow), `:BATCH_ID`, `:RUN_TS`, `:BUSINESS_DT`, `:LAST_WM_HRA01`, `:LAST_WM_HRB02_APAC`, `:LAST_WM_HRB02_EMEA`, `:LAST_WM_HRB02_AMER`, `:PII_SALT` (secret store, never in a parameter file).

Order of loads (each step waits for the previous one):
1. Reference tables (`REF_*` from `04_reference_codes.csv`) and staging (`STG_PERSON_ALL`, `STG_ORG_MAP`, `STG_LOC_MAP`).
2. `DIM_ENTITY`, `DIM_DEPARTMENT`, `DIM_REGION` (full read each run: 14 + 6 entities, 1,240 + 187 organisation units and departments, 96 + 54 locations and sites, per the profile).
3. Person matching, then `DIM_PERSON` (core columns) and `XREF_PERSON_SOURCE`.
4. `FACT_EMPLOYMENT`, first pass (all columns except `PREVIOUS_EMPLOYMENT_SK`, `DUPLICATE_REASON_CD`, `SERVICE_START_DT`), then second pass for those three in ascending `HIRE_DT` order per person.
5. `FACT_ASSIGNMENT`.
6. `DIM_PERSON` update pass: `FIRST_HIRE_DT`, `ACTIVE_EMPLOYMENT_FLG`, `SOURCE_RECORD_CNT`, `MERGE_RULE_CD`, `RETENTION_END_DT`. Set `FIRST_HIRE_DT` at insert from the staging minimum (the column is NOT NULL) and verify it in this pass (Q-026).

Incremental rules:
- HRA01: `EMP_MST.UPD_TS > :LAST_WM_HRA01`. HRB02: `LAST_UPDATED` converted to UTC (`TS_TO_UTC`, zone by `REGION_CD`) greater than the watermark of that region. Keep one watermark per region. Advance a watermark only after the whole run succeeds.
- `EMP_JOB_HST` and `HR_ASSIGN` have no timestamp: for every employee whose employment row changed, re-read ALL assignment rows and upsert them. Never rely on a date filter on these two tables.
- Initial load: full history of both systems (about 41,800 HRA01 and 9,650 HRB02 person records). Run the match stage on the full population once, then incrementally.
- Deletes: nothing is physically deleted (15-year retention). A source key that disappears is reported in the reconciliation, not removed.
- Restart: every step is an upsert on its business key, so a rerun gives the same result (test `TC-X06`). Suspense rows are retried at the start of each run; after 7 failures they move to `ETL_REJECT` as R06.

## 3. Rules that are easy to get wrong

1. **A source row is not a person.** `EMP_MST` is one row per employee record and `HR_PERSON` one row per person record inside a region. Never use `EMP_ID` or `PERSON_NO` as a person key.
2. **HRB02 `PERSON_NO` is unique only inside its region.** Always use `(REGION_CD, PERSON_NO)`. Sample: APAC 0007781 is Wei Li, EMEA 0007781 is Maria Lopez (`TC-P18`). The same applies to `MANAGER_NO` (look it up in the employee's own region, `TC-A12`) and to `DEPT_CD` (D100 is three different departments, `TC-D06`).
3. **Normalise the identifier before comparing.** `ID_NORM = UPPER(REPLACE(REPLACE(REPLACE(TRIM(id),' ',''),'-',''),'.',''))`. Sample: 'S 9047123 D' and 'S9047123D' are the same number (`TC-P07`). Hash with `SHA256_SALTED(ID_NORM, :PII_SALT)`; the raw number is read only in restricted staging and is never written to a target table, a log or `ETL_REJECT.RAW_VALUE`.
4. **Match rules (proposed, pending Q-002).** Work in this order on `STG_PERSON_ALL`:
   - M1 (AUTO): same `ID_NORM` and same parsed birth date, both not NULL.
   - M2 (AUTO): explicit previous-record link (`EMP_MST.PREV_EMP_ID`, or `HR_PERSON.XFER_FROM` written `<REGION>:<PERSON_NO>`) and the same birth date.
   - M3 (REVIEW, score 75): same `NAME_KEY` (UPPER of first name plus last name with spaces, apostrophes and hyphens removed) and same birth date, and no usable identifier on at least one side. Sample: D'Souza and DSouza (`TC-P05`). Do not merge.
   - M4 (REVIEW, score 60): same `ID_NORM` but different birth dates. Do not merge.
   - M5 (never merge): both records have the same target identifier type and the same country, and the numbers differ. Sample: the two Wei Zhang records (`TC-P06`).
   - Candidate search: block on `ID_NORM`, on `BIRTH_DT` plus `NAME_KEY`, and on the explicit link keys. Do not compare every pair.
   - Group the AUTO links into connected components (union-find). One component = one `DIM_PERSON`. The chain Priya Nair (HRA01 10002950, HRB02 EMEA 0100456, AMER 0200981) is three records and one person (`TC-P04`).
   - A record with `BIRTH_DT` NULL is never matched automatically (`TC-P08`).
5. **Person identity must survive reruns.** An existing XREF row keeps its person. A new component gets `GLOBAL_PERSON_ID = 'P' || LPAD(NEXT_SEQUENCE(...),10,'0')`. When a steward merges two existing persons, the older id wins, the other person is retired as an alias, and the keys in `FACT_EMPLOYMENT`, `FACT_ASSIGNMENT.MANAGER_PERSON_SK` and `XREF_PERSON_SOURCE` are repointed (`TC-X07`). Store steward decisions in `STEWARD_MATCH_DECISION` (source key pair, decision MERGE or SEPARATE, decided by, date). A SEPARATE decision must stop the pair from ever being proposed again.
6. **The three duplicate causes are different things.** Department change in HRA01 (previous record closed with `TERM_RSN_CD = DTR`, new record has `PREV_EMP_ID`): `DEPT_CHANGE`, service continuous (`TC-M07`). Region change in HRB02 (old record `LEAVE_REASON_CD = XFER`, new record `XFER_FROM`): `REGION_CHANGE`, service continuous (`TC-M08`). Acquisition: earlier employment in HRA01 and later employment in HRB02 with no explicit key: `ACQ_REJOIN`, found by `PRIOR_EMPLOYMENT_OF_PERSON`, service NOT continuous (`TC-M09`, Q-005). Employment rows are never deleted or merged; the person is.
7. **`SERVICE_START_DT` follows the chain.** Process each person's employments in ascending `HIRE_DT`. Sample: 10004510 gets 2011-05-16 from 10000231; EMEA 0100234 gets 2015-01-05; APAC 0045512 stays 2016-02-01 (`TC-M11`).
8. **Dates.** HRA01 `DOB_DT` and `TERM_DT` are `CHAR(8)`: `00000000` and `99999999` are not available, `99991231` means still employed; use `IS_DATE` before `TO_DATE` (`TC-M03`, `TC-P08`). HRB02 `BIRTH_DATE` is text `DD/MM/YYYY` and must be parsed with that format (`TC-P09`); `LEAVE_DATE = 1900-01-01` means unknown (`TC-M04`). HRA01 `END_DT` and HRB02 `THRU_DATE` are inclusive and `9999-12-31` means open.
9. **Time zones.** HRA01 `UPD_TS` is UTC. HRB02 `LAST_UPDATED` is regional server time: convert with `TS_TO_UTC` and the IANA zone of the region (a fixed offset is wrong because of daylight saving, `TC-M12`). A local time that does not exist (spring forward) is rejected R03; a time that occurs twice (autumn) takes the first occurrence and logs a warning (`TC-M13`). The value only orders survivors and drives watermarks.
10. **Survivorship.** `SURVIVE(x)` takes the value from the record with the latest `SRC_LAST_UPD_TS_UTC` where x is not NULL. A newer NULL never overwrites an older value (`TC-P10`). Tie: HRA01 first, then the higher source key (`TC-P11`).
11. **Department hierarchy.** HRA01 has 4 levels, the target 3. Load units with `ORG_LVL <= 3` as rows; every `ORG_ID` (including level 4) goes into `STG_ORG_MAP` pointing at the level-3 ancestor, or at itself when its level is lower (`TC-D02`, `TC-A13`). Fill missing lower levels down from the nearest higher level (`TC-D03`, `TC-D04`). HRB02 has 2 levels; level 3 repeats level 2 (`TC-D05`).
12. **Region hierarchy.** Build one staged row per `LOC_ID` and per `SITE_CD`, apply `REF_CITY_ALIAS` to the city, fill down, build `REGION_KEY = UPPER(country code|L2|L5)`, then keep one row per key. The district (L3) comes from the row that really has one, so Bangalore (HRA01) and Bengaluru (HRB02) end as ONE row with district 'Bengaluru Urban' (`TC-G01`). `REGION_L4_NM` is only a fill-down placeholder (Low). Do not use the HRB02 `REGION_CD` (APAC, EMEA, AMER) as a geography level (Q-013).
13. **Overlapping assignment periods.** Order by `EFFECTIVE_FROM_DT` inside an employment. If the next period starts on or before the end of this one, set this end to the day before the next start (`TS_SHIFT_MINUTES(next, -1440)`) and log R07. Sample: AMER 0200100 (`TC-A03`). An open period (`9999-12-31`) of a terminated employment is closed at the termination date.
14. **FTE scale.** HRA01 `FTE_PCT` is 0 to 100, HRB02 `WORK_RATIO` is 0 to 1. Cast to `DECIMAL` before dividing by 100 (`TC-A04`, `TC-A05`). Values outside 0 to 1 reject the row (`TC-A07`).
15. **Do not default a flag or an amount to a real value.** Unknown gender is `UNKNOWN` (not `MALE`); unknown grade is `UNKNOWN`; a missing manager is NULL plus R08, not the first manager found.
16. **Status and date can disagree.** Keep both as supplied and log R07; never invent a termination date (Emily Carter, `TC-M05`).
17. **Grade crosswalk and every code marked "confirm with steward"** are Low or Medium confidence. Build the lookups from `REF_*` tables so a corrected mapping needs no code change.

## 4. Standard objects

Reject table (reuse the warehouse-wide object if one exists):
```sql
CREATE TABLE HR_DW.ETL_REJECT (
  BATCH_ID BIGINT NOT NULL, SRC_TABLE VARCHAR(30) NOT NULL, SRC_KEY VARCHAR(40) NOT NULL,
  FIELD VARCHAR(40), REJECT_CODE CHAR(3) NOT NULL, SEVERITY VARCHAR(5) NOT NULL, -- ROW | FIELD
  REJECT_MESSAGE VARCHAR(200), RAW_VALUE VARCHAR(200), LOAD_TS TIMESTAMP NOT NULL);
```
`SRC_KEY` for HRB02 is `REGION_CD|PERSON_NO` (never `PERSON_NO` alone). `RAW_VALUE` is left NULL for names, birth dates, identifiers and email addresses (Q-023).

Codes: R01 mandatory null, R02 invalid or unmatched code or format, R03 invalid date or timestamp, R04 overflow, R05 duplicate key, R06 referential failure (suspense), R07 inconsistent values, **R08** optional reference not found (FIELD; manager), **R09** possible duplicate person pending review (FIELD). Thresholds: warn above 1% ROW rejects per table, stop above 5%.

Other objects to create: `STG_PERSON_ALL`, `STG_ORG_MAP`, `STG_LOC_MAP`, `STEWARD_MATCH_DECISION`, suspense tables per fact, and the sequences `SEQ_DIM_ENTITY`, `SEQ_DIM_DEPARTMENT`, `SEQ_DIM_REGION`, `SEQ_DIM_PERSON`, `SEQ_GLOBAL_PERSON_ID`, `SEQ_FACT_EMPLOYMENT`, `SEQ_FACT_ASSIGNMENT`, `SEQ_XREF_PERSON_SOURCE`. Unknown members (SK -1) in the three dimensions after Q-026.

Reference tables (version-controlled, from `04_reference_codes.csv`): `REF_GENDER_HRA01`, `REF_GENDER_HRB02`, `REF_NATID_TYPE_HRA01`, `REF_NATID_TYPE_HRB02`, `REF_TERM_REASON_HRA01`, `REF_TERM_REASON_HRB02`, `REF_STATUS_HRA01`, `REF_STATUS_HRB02`, `REF_GRADE_HRA01`, `REF_GRADE_HRB02`, `REF_ASSIGN_REASON_HRA01`, `REF_ASSIGN_REASON_HRB02`, `REF_COUNTRY_ISO2`, `REF_COUNTRY_ISO3`, `REF_CITY_ALIAS`, `REF_REGION_TZ`, `REF_RETENTION_YEARS`.

## 5. Tool notes

**Informatica (PowerCenter / IICS CDI)**
- One mapping per target table and per source flow (A and B), driven by the parameter `$$SRC_SYSTEM_CD`. Source qualifier SQL carries the watermark filter. Expression transformations per STM row; cached Lookups for the `REF_*` tables.
- Matching: do the candidate search and union-find in the database (set-based SQL or a stored procedure called from a Command or SQL transformation); Informatica handles staging and the loads. Do not try to do transitive closure inside a mapping.
- `FACT_EMPLOYMENT` second pass: a separate mapping that reads the loaded rows ordered by `PERSON_SK, HIRE_DT` and updates with an Update Strategy.
- Router groups on every fact: GOOD, FIELD_WARN (also writes to `ETL_REJECT`), ROW_REJECT, SUSPENSE.
- Time zones: Informatica has no native daylight-saving conversion. Use a database function or a lookup of offset rules by date and zone; prove it with `TC-M12` and `TC-M13`.

**Talend**
- Parent job `j_hrms_main` with child jobs per table, run through `tRunJob`; context variables for `SRC_SYSTEM_CD`, watermarks and batch ids. Child jobs for the match stage call SQL (`tDBRow`) for blocking and components, then read the result with `tDBInput`.
- `tMap` per target with lookup flows for `REF_*` and dimensions (unique match; inner-join reject goes to suspense). Date rules use non-lenient `TalendDate.isDate`. Time zones through a routine using `java.time.ZonedDateTime`.
- Shared `tDBOutput` to `ETL_REJECT`; `tLogCatcher` for component errors. Do not use `Numeric.sequence` for surrogate keys; use database sequences.

**Apache Hop**
- Pipelines per table (`dim_entity.hpl`, `dim_department.hpl`, `dim_region.hpl`, `person_match.hpl`, `fct_employment.hpl`, `fct_assignment.hpl`) and a workflow `hrms_daily.hwf` that enforces the order and updates watermarks only after success.
- Transforms: Table Input, Formula or Modified JavaScript for rules, Database Lookup or Stream Lookup for `REF_*` and dimensions, Switch-Case for routing, Insert/Update for upserts. Keep the union-find in SQL. Error-handling hops to `ETL_REJECT`.
- Use environment variables for connections and use sheet 6 test cases as golden datasets.

## 6. Test and reconciliation

Field-level tests (`TC-*`) and table-level reconciliation (`RC-*`) are in sheet `6_Tests_Recon`. The sample files `inputs/05_sample_*.csv` already contain the three duplicate causes (Rahul Mehta, Neha Kapoor, Li Wei, Priya Nair), a review case (Anita D'Souza), a false-positive twin (Wei Zhang), a reused person number, a hierarchy with a level-4 unit, alias cities, sentinels, an overlap and an orphan manager.

First-load acceptance: counts reconcile after rejects and suspense (`RC-01` to `RC-04`); the duplicate report equals the staging counts (`RC-05`); no person holds two different identifier hashes (`RC-06`); the review queue is under 1% of records or explained (`RC-07`); no orphan keys (`RC-14`); no raw national identifier anywhere (`RC-16`); ROW rejects stay below 1% per table.

## 7. Sensitive data

PII and Sensitive: `FIRST_NM`, `LAST_NM`, `FULL_NM`, `BIRTH_DT`, `GENDER_CD`, `NATIONAL_ID_TYPE_CD`, `NATIONAL_ID_HASH`, `WORK_EMAIL`. Compensation (`BASE_SAL_AMT`) is excluded. Mask names, birth date (show year only) and email in non-production; the salt lives in the secret store; staging that holds the raw identifier is access-restricted and purged after the match stage. Personal data from several countries is combined in one warehouse: get data-protection sign-off on cross-border use (Q-023) before the first non-production load. Records past their retention date (Q-001) must not be available to ordinary reporting users.
