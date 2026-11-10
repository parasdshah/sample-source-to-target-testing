# Open Questions: HRA01 + HRB02 HRMS -> HR_DW (STM v0.1 DRAFT)

Written for: HR data steward, HR policy and compliance owners, Legal, data protection officer, HRA01 and HRB02 DBAs, and the data modeler, who need to answer them. Same list as sheet `5_Open_Questions` in `01_STM_HRA01_HRB02_HRMS.xlsx`. Reply by Q-number; the STM is updated when answers arrive.

## Blocker (cannot go live without an answer)

**Q-001: Retention period and expired records** (owner: Legal + HR compliance)
- Fields: DIM_PERSON.RETENTION_END_DT; all history tables
- Observed: Sample EMP_ID 10000045 left on 2009-09-30; 15 years later is 2024-09-30, which is before the run date. HRA01 TERM_DT goes back to 1999-01-31 (profile min).
- Question: What is the legal retention period for each country of employment (the brief says more than 15 years)? Which date starts it: the last termination date or the end of that calendar year? Must records that are already past retention be loaded into the warehouse, or only into a restricted archive?
- Why it matters: legal retention decides which records may be loaded and for how long
- Proposed: 15 years after the last termination as the group minimum; stricter country periods override it; past-retention records go to a restricted archive schema, not the reporting layer.

**Q-002: Match rules and review ownership** (owner: HR data steward + data protection officer)
- Fields: XREF_PERSON_SOURCE; DIM_PERSON (all merge rules)
- Observed: Samples: Rahul Mehta 10000231 and 10004510 (rules 1 and 2); Neha Kapoor HRA01 10001877 and HRB02 APAC 0045512 (rule 1); Priya Nair three records, identifier written 'QQ123456C' and 'QQ 12 34 56 C' (rule 1); Anita D'Souza HRA01 10003388 and HRB02 EMEA 0100777 (rule 3 only); Wei Zhang HRA01 10005120 and HRB02 APAC 0009012 (rule 4).
- Question: Do you approve these person-matching rules? (1) Same normalised national identifier AND same birth date: merge automatically. (2) Explicit previous-record link (PREV_EMP_ID or XFER_FROM) AND same birth date: merge automatically. (3) Same first name, last name and birth date but no usable identifier: do NOT merge, send to a review queue. (4) Same identifier type and country but different identifier numbers: never merge. Who works the review queue, and is the national identifier allowed as a matching key in every country?
- Why it matters: the merge rules decide who is one person; nothing may go live without approval
- Proposed: Rules as listed. A false merge joins two people's histories, so the cost is higher than a missed merge: when in doubt, review.

## High impact

**Q-003: National identifier quality** (owner: HR data steward)
- Fields: EMP_MST.NATL_ID_TYP, NATL_ID_NO; HR_PERSON.GOVT_ID_TYPE, GOVT_ID_NO
- Observed: NATL_ID_NO is null in 7.1% (HRA01) and GOVT_ID_NO in 11.4% (HRB02); spaces or dashes occur in 6% (HRA01) and 14% (HRB02). HRA01 type PPT is marked 'confirm with steward'.
- Question: The same identifier value sits on 2 or more EMP_ID in 112 HRA01 rows: are these department-change duplicates, or data errors? Which identifier types may be compared with each other (NIN, SSN, PAN, PPT in HRA01; NATID, TAXID, PASSPORT in HRB02)? Is 'S 9047123 D' the same number as 'S9047123D'?
- Why it matters: identifier quality decides the automatic merge
- Proposed: Compare the normalised number (remove spaces, dashes, dots; upper case) only when both records map to the same target type; a different type goes to review.

**Q-004: Department-change duplicates (HRA01)** (owner: HR data steward + HRA01 DBA)
- Fields: EMP_MST.PREV_EMP_ID, TERM_RSN_CD; FACT_EMPLOYMENT.DUPLICATE_REASON_CD
- Observed: PREV_EMP_ID is populated in 8.1% of records and every value exists in EMP_ID. The previous record has DTR in 55% of the links; DTR itself is 4.5% of records.
- Question: Reason 1, department change in HRA01: is a record closed with TERM_RSN_CD = DTR always followed by a new record, and does the new record always carry PREV_EMP_ID? What do the other links mean, where the previous record has a different reason?
- Why it matters: this is the first of the three duplicate causes
- Proposed: A link whose previous record has DTR is a DEPT_CHANGE. A link with another reason is a REHIRE. A DTR record with no later record stays a single employment and is listed in the reconciliation.

**Q-005: Acquisition rejoin and service continuity** (owner: HR policy owner + Legal)
- Fields: FACT_EMPLOYMENT.SERVICE_START_DT, DUPLICATE_REASON_CD = ACQ_REJOIN
- Observed: Sample: Neha Kapoor left HRA01 on 2014-09-30 and joined HRB02 APAC on 2016-02-01 (gap of about 16 months). Same person by identifier and birth date.
- Question: Reason 2, a former employee of the group who joined the acquired company: does service count as continuous (benefits, notice period, seniority)? Should the two employments be shown as one in reports? Does a rehire inside HRA01 follow the same rule?
- Why it matters: changes SERVICE_START_DT for every rejoin
- Proposed: Two employments, one person; service is NOT continuous for an acquisition rejoin or a rehire. Department and region changes are continuous.

**Q-006: Region-change duplicates (HRB02)** (owner: HR data steward + HRB02 DBA)
- Fields: HR_PERSON.XFER_FROM, LEAVE_REASON_CD
- Observed: XFER_FROM is populated in 3.1% of records; LEAVE_REASON_CD = XFER is 3.4%. Samples: Li Wei APAC 0007781 to EMEA 0100234 (JOIN_DATE = day after the old leave date); Priya Nair EMEA 0100456 to AMER 0200981.
- Question: Reason 3, region change in HRB02: does a move between regions always create a new PERSON_NO and close the old record with reason XFER? Is the new JOIN_DATE the transfer date or the original joining date? Why is XFER_FROM filled less often than the reason XFER?
- Why it matters: second of the three duplicate causes
- Proposed: Link by XFER_FROM when present, otherwise by the person match plus the XFER reason on the earlier record; SERVICE_START_DT carries over.

**Q-007: HRB02 person key** (owner: HRB02 DBA)
- Fields: HR_PERSON.PERSON_NO, REGION_CD; HR_ASSIGN; XREF_PERSON_SOURCE
- Observed: HR_PERSON has 9,650 rows but only 9,210 distinct PERSON_NO values, so numbers are reused across regions. Sample: APAC 0007781 is Wei Li, EMEA 0007781 is Maria Lopez.
- Question: Is the HRB02 key (REGION_CD, PERSON_NO)? Does any other table or column (for example MANAGER_NO) hold a PERSON_NO without a region? Can a PERSON_NO be reused after someone leaves?
- Why it matters: a wrong key merges two people or breaks every join
- Proposed: Key is (REGION_CD, PERSON_NO); MANAGER_NO is read inside the employee's own region.

**Q-008: HRB02 server time zones** (owner: HRB02 DBA)
- Fields: HR_PERSON.LAST_UPDATED; REF_REGION_TZ
- Observed: Convention A2 rule 8 says regional server local time and gives no zone. The reference file proposes APAC = Asia/Singapore, EMEA = Europe/London, AMER = America/New_York.
- Question: In which time zone does each regional server store LAST_UPDATED, and has that ever changed? The APAC partition holds several countries.
- Why it matters: wrong zones pick the wrong surviving record
- Proposed: As in the reference file. The value only orders survivors and drives the watermark, never a business date.

**Q-012: Region hierarchy, aliases and unused level 4** (owner: HR data steward + modeler)
- Fields: DIM_REGION; HR_SITE; LOC_MST; REF_CITY_ALIAS
- Observed: HR_SITE.PROVINCE_NM is null in 11.1% (city states); LOC_MST.ST_NM null in 12.5%; 3 HRA01 cities appear under two spellings. Samples: Bangalore / Bengaluru, Gurgaon / Gurugram, 'New York City' / 'New York'.
- Question: Confirm the five levels (1 country, 2 state or province, 3 district or county, 4 metro area or sub-region, 5 city). Neither system has level 4 and HRA01 has no level 3: is fill-down acceptable, or is there a geography master to load? Who owns the city alias list? Is it acceptable that every HRB02 site is active, since HR_SITE has no flag?
- Why it matters: the region hierarchy is a stated requirement
- Proposed: Fill down; the alias list in the reference file; sites active. Region key = country + state + city.

**Q-016: Overlapping and gapped assignment periods** (owner: HR data steward)
- Fields: EMP_JOB_HST; HR_ASSIGN; FACT_ASSIGNMENT
- Observed: Overlap and gap rates are not supplied. Sample: HRB02 AMER 0200100 seq 1 ends 2019-04-05 and seq 2 starts 2019-04-01.
- Question: How often do assignment periods overlap or leave gaps, and which row is right when they overlap? Does a gap mean leave of absence?
- Why it matters: affects the history of every affected person
- Proposed: The later row wins: trim the earlier period to the day before the later start and log R07. Gaps load as they are.

**Q-020: Entity crosswalk** (owner: Finance + HR data steward)
- Fields: DIM_ENTITY; FACT_EMPLOYMENT.ENTITY_SK; FACT_ASSIGNMENT.ENTITY_SK
- Observed: HRA01 has 14 legal entities and HRB02 has 6 companies; names differ (Orbis Financial and Harbor Credit in the samples).
- Question: Were any HRB02 companies merged into existing HRA01 legal entities after the acquisition? Is there a group entity crosswalk? Is a currency table available?
- Why it matters: entity is a stated requirement and a reporting dimension
- Proposed: Every source entity is its own row with a prefix 'A-' or 'B-' until a crosswalk is supplied.

**Q-023: Privacy and cross-border use of personal data** (owner: Data protection officer + security)
- Fields: DIM_PERSON PII columns; ETL_REJECT.RAW_VALUE
- Observed: Personal data from several countries is merged into one warehouse. HRA01 and HRB02 cover India, Singapore, the UK, the US and Germany in the samples.
- Question: May the salted identifier hash, names, birth dates and email addresses be loaded in all three regions, and how are they masked in non-production? Who holds the salt? May personal data cross borders to the warehouse location?
- Why it matters: before the first non-production load
- Proposed: Hash only (no raw identifier); mask names, birth date and email in non-production; salt in the secret store; ETL_REJECT.RAW_VALUE left NULL for personal fields.

**Q-026: Target model changes** (owner: Modeler)
- Fields: Target model
- Observed: Target DDL: SK columns NOT NULL. FACT_ASSIGNMENT has no uniqueness rule for CURRENT_FLG.
- Question: Please (1) add an unknown member (SK -1) to DIM_ENTITY, DIM_DEPARTMENT and DIM_REGION, (2) confirm that persons with a REVIEW link are loaded as separate persons, (3) confirm FACT_ASSIGNMENT allows one open row per employment only, (4) confirm DIM_PERSON.FIRST_HIRE_DT is set at insert from staging and checked in the update pass.
- Why it matters: unknown members are needed before the first load
- Proposed: Yes to all four.

## Gates production (build can start)

**Q-010: Department hierarchy: 4 levels into 3** (owner: HR data steward + modeler)
- Fields: ORG_UNIT; DIM_DEPARTMENT
- Observed: Profile: level 4 = 23.1% of units, level 3 = 45%, level 2 = 24%, level 1 = 7.9%. Samples: O11110 'Home Loans Underwriting' (level 4) with employee 10000231; O40000 'Treasury' (level 1) with employees.
- Question: HRA01 has 4 levels, the target has 3. Confirm that level 1 = division, level 2 = department, level 3 = team, and that a level-4 unit rolls up into its level-3 ancestor (its own name is lost). For units at level 1 or 2 that have employees, confirm fill-down (the unit repeats at the lower levels).
- Why it matters: department roll-up changes every department report
- Proposed: As stated. Keep STG_ORG_MAP so the level-4 detail can be added later without reloading history.

**Q-014: Grade crosswalk** (owner: HR compensation owner)
- Fields: EMP_JOB_HST.GRD_CD; HR_ASSIGN.LEVEL_CD; REF_GRADE_*
- Observed: Both have 6 values. Samples: 'Senior Underwriter' G4 (HRA01) and 'Senior Relationship Officer' L04 (HRB02). The reference file marks every pair 'confirm with steward'.
- Question: Do HRA01 grades G1 to G6 and HRB02 levels L01 to L06 correspond one to one (rank for rank)? Who owns the global grade structure?
- Why it matters: grade drives reporting and pay bands
- Proposed: G1 = L01 = GR1 and so on until HR confirms.

## Medium

**Q-009: HRA01 timestamp zone** (owner: HRA01 DBA)
- Fields: EMP_MST.UPD_TS
- Observed: Part A rule 8 says UTC, 'per the DBA wiki; not verified'.
- Question: Is HRA01 UPD_TS really stored in UTC? Has the server zone changed since 2009?
- Why it matters: Medium
- Proposed: UTC, no conversion.

**Q-011: HRB02 departments: 2 levels and reused codes** (owner: HR data steward)
- Fields: HR_DEPT; DIM_DEPARTMENT
- Observed: 22 HRB02 DEPT_CD values are used in more than one region with different names. Sample D100 = Retail Lending (APAC), Collections (EMEA), Cards (AMER).
- Question: HRB02 has 2 levels (division, department): confirm level 3 repeats level 2. The same DEPT_CD means different departments in different regions. Should departments with the same name in different regions or systems (for example 'Credit Risk' in HRA01 and in HRB02 EMEA) become one row?
- Why it matters: Medium
- Proposed: No merging across regions or systems now; every source unit is its own row. A department crosswalk table can be added later.

**Q-013: Management region and office names** (owner: Modeler + HR reporting)
- Fields: HR_SITE.REGION_CD; LOC_MST.LOC_NM; HR_SITE.SITE_NM
- Observed: REGION_CD takes 3 values; the target model has no column for it or for site names.
- Question: HRB02 REGION_CD (APAC, EMEA, AMER) is a management partition, not a geography level. Should it be kept for HR reporting (a reporting region)? Is the office or site name needed in the target?
- Why it matters: Medium
- Proposed: Not loaded; names stay in staging. The modeler adds a reporting region later if wanted.

**Q-015: Zero FTE** (owner: HR data steward)
- Fields: EMP_JOB_HST.FTE_PCT; HR_ASSIGN.WORK_RATIO
- Observed: FTE_PCT = 0.00 in 0.3% of rows; WORK_RATIO min is 0.000. Scales: 0 to 100 and 0 to 1.
- Question: What does 0 FTE mean (unpaid leave)? Should such a row be loaded?
- Why it matters: Medium
- Proposed: Load 0.000 as it is; reject only values below 0 or above 1.

**Q-017: Unknown-date markers and status versus date** (owner: HR data steward)
- Fields: EMP_MST.TERM_DT; HR_PERSON.LEAVE_DATE, STATUS_CD
- Observed: LEAVE_DATE = 1900-01-01 in 0.6% of HRB02 records. Samples: Hans Weber EMEA 0100900 (1900-01-01, status active); Emily Carter AMER 0200100 (status terminated, no leave date).
- Question: Is 1900-01-01 in LEAVE_DATE and 00000000 in TERM_DT a confirmed 'unknown' marker? When status and date disagree, which one is right?
- Why it matters: Medium
- Proposed: Sentinel = NULL. Keep both values as supplied and log R07; do not infer a date.

**Q-018: HRB02 status 4** (owner: HRB02 DBA)
- Fields: HR_PERSON.STATUS_CD
- Observed: STATUS_CD 4 is 0.2% of records; 1, 2 and 3 are explained.
- Question: What does status 4 mean?
- Why it matters: Medium
- Proposed: SUSPENDED (as in HRA01 'S').

**Q-019: Unexplained reason codes** (owner: HRA01 DBA)
- Fields: EMP_MST.TERM_RSN_CD; EMP_JOB_HST.ACT_RSN_CD
- Observed: TERM_RSN_CD has 7 distinct values and 6 are listed; ACT_RSN_CD 'other' = 1%. ACT_FLG uses ACT for 'active'.
- Question: What is the 7th termination reason code and the 'other' action reason code? Please confirm that DTR means a department transfer and that ACT in ACT_RSN_CD means 'action'.
- Why it matters: Medium
- Proposed: Unlisted codes load as UNKNOWN with R02 (FIELD).

**Q-021: Survivorship rules** (owner: HR data steward)
- Fields: DIM_PERSON survivorship; XREF_PERSON_SOURCE.SURVIVOR_FLG
- Observed: Samples: 'D'Souza' (HRA01) and 'DSouza' (HRB02); priya.nair@orbis.example and priya.nair@harborcredit.example.
- Question: Which record supplies the surviving name, birth date, gender, email and identifier? Which system is the system of record for people after the acquisition?
- Why it matters: Medium
- Proposed: Newest update (in UTC) wins field by field when not NULL; a tie goes to HRA01.

**Q-025: Manager resolution** (owner: HR data steward)
- Fields: EMP_JOB_HST.MGR_EMP_ID; HR_ASSIGN.MANAGER_NO; FACT_ASSIGNMENT.MANAGER_PERSON_SK
- Observed: 1.2% of HRA01 MGR_EMP_ID values are not found in EMP_MST. Samples: 10000500 (HRA01) and 0003344 (HRB02 APAC) are not in the sample files.
- Question: Should the manager be recorded as a person (all that person's employments) rather than one employment? What should happen when the manager key does not exist?
- Why it matters: Medium
- Proposed: Resolve to the person; NULL plus R08 (FIELD) when not found.

**Q-027: Gender codes X and 9** (owner: HR data steward)
- Fields: EMP_MST.GNDR_CD; HR_PERSON.SEX_CD
- Observed: X = 0.6% (HRA01); 9 = 1.5% (HRB02).
- Question: Is HRA01 'X' the same as HRB02 '9', or does X mean a non-binary value and 9 'not known'?
- Why it matters: Medium
- Proposed: X = OTHER; 9 = UNKNOWN.

**Q-028: Birth date markers and formats** (owner: HR data steward)
- Fields: EMP_MST.DOB_DT; HR_PERSON.BIRTH_DATE
- Observed: 00000000 = 0.2% (HRA01); 0.2% of HRB02 values do not parse as DD/MM/YYYY.
- Question: Is DOB_DT = 00000000 a confirmed 'not available' marker? Which other formats appear in HRB02 BIRTH_DATE?
- Why it matters: Medium
- Proposed: 00000000 = NULL; unparsable = NULL + R03 (FIELD). A person with no birth date is never merged automatically.

## Low

**Q-022: Job codes** (owner: Modeler)
- Fields: EMP_JOB_HST.JOB_CD
- Observed: 612 distinct JOB_CD values; no target column.
- Question: Is a job-code dimension planned? HRB02 has no job code.
- Why it matters: Low
- Proposed: Stage the value only.

**Q-024: Versions and extract dates** (owner: Modeler)
- Fields: All
- Observed: No version information in the inputs.
- Question: Source and target versions and extract dates are not stated. Is the target model final?
- Why it matters: Low
- Proposed: Assume v0.1 draft for both systems and a current extract.
