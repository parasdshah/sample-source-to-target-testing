# Worked Example (copy this style)

Complete reference outputs exist in the repository. Open them before you start and imitate their structure, wording and level of detail:
- `projects/EMAIL_MAPPER/` : mail system, 3 source tables, 4 target tables, 47 target columns. Passes `scripts/check_stm.py`. **Use this as the gold standard.**
- `projects/CRM01_CUST_ACCT/` : older example; layout differs in places from the current standard (see the note at the end).

Below, one source field is followed through every step so you can see what each step must produce.

## Field: `MSG_RCPT.RD_FLG` -> `BRIDGE_EMAIL_RECIPIENT.READ_FLG`

### 1. Inputs seen
Inventory row: `MSG_RCPT,RD_FLG,CHAR,1,Y,,,2,29.0,N,Y,"Y (48%); N (23%); null (29%)"` (no vendor description).
Inventory row: `MSG_RCPT,RD_TS,TIMESTAMP,,Y,,,402000,52.0,...,"null when not read"`.
Sample rows: `000000000103,1,asha.rao@example.com,T,BN,,,Y` (RD_FLG empty), `000000000101,1,priya.n@example.com,T,DL,Y,2026-10-30 09:20:11,N`.
Target DDL: `READ_FLG CHAR(1) NOT NULL, -- Y/N/U (unknown)`.

### 2. Decode (decoder, Step 4-5)
- `FLG` = Flag (given). `RD`: not in the given list; dictionary says Read (ambiguous with Received, but Received is `RCV`). Tie-breaker: profile.
- Cross-column fact: `RD_FLG = 'Y'` is 48% and `RD_TS` is populated in 100% - 52% = 48%; `RD_TS` null 52% = `N` 23% + null 29%. The two columns agree.
- Decoded name: `Read Flag`.

### 3. Score (inference-and-confidence section 3)
A +25 (profile consistent), C partial +10 (`FLG` High, `RD` Medium), E +15 (two columns agree) = **50 = Medium**. Evidence text ends `(score 50)`.

### 4. Question raised
`Q-009` (see `projects/EMAIL_MAPPER/outputs/03_Steward_Questions.md`): "Confirm RD = Read. Does NULL RD_FLG (29%) mean 'not tracked'? Can RD_FLG be 'N' while RD_TS has a value?" Proposed: NULL flag -> `U`.

### 5. STM row (sheet 1; shown as field: value)
| Field | Value |
|---|---|
| STM Row ID | `STM-RCP-0006` |
| Target table / column | `DW.BRIDGE_EMAIL_RECIPIENT` / `READ_FLG` |
| Target datatype / key | `CHAR(1)` / `NOT NULL` |
| Source | `MSG_RCPT.RD_FLG; MSG_RCPT.RD_TS` (CHAR(1); TIMESTAMP) |
| Mapping type | `DERIVE` |
| Rule | `READ_FLG = CASE WHEN RD_FLG IN ('Y','N') THEN RD_FLG WHEN RD_TS IS NOT NULL THEN 'Y' ELSE 'U' END` |
| Null handling | NULL RD_FLG (29%) -> `U` unless RD_TS present |
| Default | `U` |
| Reject / warn | `RD_FLG='N'` with `RD_TS` not null -> keep `N` + R07 (FIELD) |
| Evidence | `'RD' not in the abbreviation list. Profile: RD_FLG='Y' 48% = RD_TS populated 48%; RD_TS null 52% = N 23% + null 29%. Strong consistency, so RD = Read (score 50)` |
| Confidence / Status / Question / Test | `Medium` / `Inferred` / `Q-009` / `TC-R05, TC-R07` |

### 6. Tests (sheet 6)
| ID | Check | Input | Expected |
|---|---|---|---|
| TC-R05 | READ_FLG | `Y` (msg 101 seq 1); `N` (101 seq 2); NULL with RD_TS NULL (103 seq 1, 104 seq 1) | `Y`; `N`; `U` |
| TC-R07 | READ_FLG consistency | RD_FLG NULL with RD_TS present; RD_FLG `N` with RD_TS present | `Y`; `N` + R07 FIELD |

### 7. Source-inventory row (sheet 2)
`SRC-MAIL02-MSG_RCPT-RD_FLG | MSG_RCPT | RD_FLG | Read Flag | Y/N whether the recipient read the message; null = not tracked (inferred) | Undocumented | CHAR(1) | Y | | distinct 2; null 29.0%; min N; max Y; Y (48%); N (23%); null (29%) | Medium | Mapped: STM-RCP-0006`

## Other patterns to find in `projects/EMAIL_MAPPER/outputs/01_STM_MAIL02_EMAIL.xlsx`
| Pattern | Row |
|---|---|
| Strict date with sentinels | `STM-MSG-0009` (`RECEIVED_DT`) |
| Timezone to UTC with date roll-back test | `STM-MSG-0008` (`SENT_TS_UTC`), tests `TC-F04`, `TC-F05` |
| Code lookup with a default | `STM-MSG-0012` (`PRIORITY_CD`) |
| Many sources deduplicated into one dimension | `STM-ADR-0002` (`EMAIL_ADDRESS`) |
| Blocker: mandatory target with no source | `STM-ADR-0005` (`INTERNAL_FLG`), `Q-001` |
| Do NOT derive one column from another | `STM-MSG-0015` (`SPAM_FLG`), `Q-007` |
| Surrogate key, constants, audit | `STM-ADR-0001`, `STM-ADR-0006..0008` |
| Column deliberately not loaded | source `USR_FLD_1` in sheet 2 (`Staged raw only`) |

## Second example: CRM01_CUST_ACCT
`projects/CRM01_CUST_ACCT/` also passes `scripts/check_stm.py`. It is a customer and account mapping with an SCD2 dimension, an SCD1 dimension and a daily snapshot fact. Good rows to study: `STM-CUS-0005` (mandatory column with no source: `NOT MAPPED`, status `Draft`, BLOCKER question `Q-001`), `STM-CUS-0015` to `STM-CUS-0019` (SCD2 columns, hash and validity window), `STM-CUS-0012` (identifier forced to Low, staged raw), `STM-ACC-0003` (key lookup against an SCD2 dimension and the model issue it raises in `Q-017`), and `STM-BAL-0002` (snapshot date from a parameter).
