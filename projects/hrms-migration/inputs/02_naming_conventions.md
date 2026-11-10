# HRMS Migration Naming Conventions

Two source systems feed one target. Source codes used everywhere: `HRA01` = acquirer HRMS, `HRB02` = acquired company HRMS.

## Part A: Source system conventions (as supplied by the source teams)

### A1. HRA01 (acquirer, one global database, multi-entity)
1. Tables: `<ENTITY>_<CLASS>`; class `MST` = master, `HST` = history, `UNIT` = organisation unit. `LEG_ENT` is the legal-entity table.
2. Columns: UPPER_CASE words separated by `_`; abbreviations are 2-5 letters.
3. Class words (last token): `_CD` code, `_NM` name, `_ID` identifier, `_NO` number, `_ADR` address, `_DT` date, `_TS` timestamp, `_FLG` flag Y/N, `_TYP` type, `_STS` status, `_RSN` reason, `_PCT` percentage, `_AMT` amount.
4. `_DT` is `CHAR(8)` `YYYYMMDD` in `EMP_MST` (`DOB_DT`, `TERM_DT`) but a true `DATE` in `EMP_JOB_HST` (`EFF_DT`, `END_DT`) and for `EMP_MST.HIRE_DT`.
5. Known abbreviations: EMP = Employee, LEG = Legal, ENT = Entity, ORG = Organisation, PAR = Parent, LVL = Level, SHRT = Short, LOC = Location, CTRY = Country, ST = State, CTY = City, FST = First, LST = Last, DOB = Date of birth, GNDR = Gender, NATL = National, TERM = Termination, PREV = Previous, JOB = Job, TTL = Title, GRD = Grade, MGR = Manager, FTE = Full-time equivalent, EFF = Effective, SAL = Salary, UPD = Updated, ACT = Active (in `ACT_FLG`).
6. `ORG_LVL` runs 1 (division) to 4; the hierarchy is parent-child through `PAR_ORG_ID`.
7. `TERM_DT = '99991231'` and `END_DT = 9999-12-31` mean "still open / still employed". `00000000` is a legacy "not available" marker (not confirmed per column).
8. All HRA01 timestamps are stored in UTC (per the DBA wiki; not verified).
9. `EMP_ID` is unique across the whole HRA01 database. A department change in the old process closed the employee record and created a new one (the new record carries `PREV_EMP_ID`).

### A2. HRB02 (acquired company, managed region-wise after the acquisition)
1. Tables: `HR_<ENTITY>`. Data is partitioned by `REGION_CD` (`APAC`, `EMEA`, `AMER`) = the management region that owns the record. It is NOT a geography level.
2. Columns: UPPER_CASE words separated by `_`; words are mostly spelled out (PERSON, ASSIGN, COMPANY).
3. Class words: `_CD` code, `_NM` name, `_NO` number, `_DATE` date, `_FLAG` flag stored as `1` (yes) / `0` (no), `_RATIO` fraction 0 to 1, `_REASON` reason code. `LAST_UPDATED` is a timestamp.
4. `BIRTH_DATE` is a `VARCHAR(10)` in `DD/MM/YYYY`; every other `_DATE` is a true `DATE`.
5. Known abbreviations: GOVT = Government, XFER = Transfer, XREG = Cross-region transfer, DEPT = Department, DIV = Division, ASSIGN = Assignment, THRU = Through (end of period, inclusive), ISO3 = ISO 3166 alpha-3 country code.
6. `PERSON_NO` is unique only within a `REGION_CD`. The same number can exist in two regions for two different people.
7. `THRU_DATE = 9999-12-31` means open. `1900-01-01` is a legacy "unknown date" value (not confirmed).
8. `LAST_UPDATED` is the local time of the regional server (not UTC). Server zones are not documented.
9. A region change creates a new `PERSON_NO` in the new region; `XFER_FROM` (`<REGION>:<PERSON_NO>`) is filled for some of these moves.

## Part B: Target model conventions (supplied by the HR data modeling team)
1. Schema `HR_DW`. Tables: `DIM_` dimension, `FACT_` fact with history, `XREF_` crosswalk.
2. Column class words: `_SK` surrogate key (`BIGINT`), `_KEY` text business key, `_CD` code, `_NM` name, `_DT` date, `_TS` timestamp, `_FLG` `CHAR(1)` `Y`/`N`, `_CNT` count, `_ID` identifier. A timestamp stored in UTC carries `_UTC` before `_TS` or at the end of the name.
3. Hierarchy levels are numbered `L1`..`Ln` from the top (`DEPT_L1_*` is the top). Departments have 3 levels, regions have 5 levels (L1 country, L2 state or province, L3 district or county, L4 metro area or sub-region, L5 city), entities have 1 level.
4. A missing intermediate level is filled down from the nearest higher level (rule proposed by the modeler; see Q-010 and Q-012). `NULL` is not used for hierarchy levels.
5. Code domains are `UPPER_SNAKE_CASE` words (`ON_LEAVE`, `CONTRACT_END`). Every domain that can be unknown has an `UNKNOWN` value.
6. Audit columns on every table: `SRC_SYSTEM_CD`, `BATCH_ID`, `LOAD_TS` (UTC).
7. History: dimensions are Type 1. `FACT_ASSIGNMENT` keeps one row per effective-dated period, closed with `EFFECTIVE_TO_DT` (`9999-12-31` = open) and marked with `CURRENT_FLG`. Nothing is physically deleted: records must be kept for at least 15 years after the last termination (see `RETENTION_END_DT`).
8. The unknown member of every dimension has SK `-1`.
