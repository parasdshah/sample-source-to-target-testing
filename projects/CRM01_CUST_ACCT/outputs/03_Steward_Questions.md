# Open Questions: CRM01 CUST_MST / ACCT_MST -> DW (STM v0.2 DRAFT)

Written for: data steward, source DBA, data modeler, finance and compliance reviewers, who need to answer them.
Same list as sheet `5_Open_Questions` in `01_STM_CRM01_CUST_ACCT.xlsx`. Reply by Q-number; the STM is updated when answers arrive.

## Blocker (cannot go live without an answer)

**Q-001: DIM_CUSTOMER.CUSTOMER_SEGMENT_CD** (owner: Steward + Modeler; severity: BLOCKER: mandatory target column has no source)
- Observed: No CRM01 field carries it. CUST_TYP_CD only separates Individual/Corporate/Unknown.
- Question: Which source or rule provides segment (MASS/AFFL/PRIV/SME/CORP)?
- Proposed: Add 'UNK' to the domain or make nullable until a rule exists; steward supplies derivation.

## High impact

**Q-010: CUR_BAL / AVL_BAL** (owner: Steward + Finance; severity: High: financial amount (sign and meaning))
- Observed: Neither documented. 4% negative; sample loan -850000; AVL <= CUR + OD in 100%.
- Question: Is CUR_BAL the ledger/book balance? Sign convention for loans/cards (negative = owed)? Is AVL_BAL after holds and overdraft?
- Proposed: CUR_BAL=ledger, AVL_BAL=available, pass sign as-is

**Q-011: OD_LMT** (owner: Steward; severity: High: financial amount)
- Observed: AVL_BAL = CUR_BAL + OD_LMT pattern.
- Question: Confirm OD_LMT = overdraft limit (permitted overdraft), unsigned.
- Proposed: Confirmed as proposed

**Q-012: INT_RT** (owner: Steward; severity: High: financial rate)
- Observed: Range 0-18.5; null for closed/loan sample 103.
- Question: Confirm percent scale (6.25 = 6.25%) and that NULL means 'no rate' (31%) distinct from 0.0000.
- Proposed: Percent; NULL passes through

**Q-017: DIM_ACCOUNT.CUSTOMER_SK** (owner: Modeler; severity: High: model design issue (stale surrogate key))
- Observed: Model design.
- Question: DIM_ACCOUNT is SCD1 but references an SCD2 SK 'current at load'. After a customer is re-versioned the account points at a closed version. Re-point all accounts each run, or reference the business key?
- Proposed: Re-resolve all each run

## Gates production (build can start)

**Q-003: KYC_STS** (owner: Steward + Compliance; severity: Gates production)
- Observed: {A 92%, P 6%, R 2%}; no vendor description. Regulatory field.
- Question: Confirm A=Verified, P=Pending, R=Rejected. Is there any other state (expired, refresh due)?
- Proposed: As in reference file

## Medium

**Q-002: CUST_TYP_CD** (owner: Steward; severity: Medium)
- Observed: {1 88%, 2 11%, 9 1%}; reference file marks 9 as 'confirm with steward'.
- Question: Confirm 1=Individual, 2=Corporate. What is 9: unclassified, or a specific type?
- Proposed: 9 = unknown -> UNK

**Q-004: DOB_STR** (owner: Steward; severity: Medium)
- Observed: 5.9% / 0.3% markers; convention rule 6 says 'not confirmed per column'. Sample 105 has 19990229.
- Question: Confirm 00000000 and 99999999 both mean 'not available'. How should invalid dates (e.g. 19990229) be handled?
- Proposed: NULL both; invalid -> NULL + DQ log

**Q-005: RM_ID** (owner: Steward; severity: Medium: staff id; target held NULL until answered)
- Observed: Pattern RM9{5}, 22% null, no match in any supplied table.
- Question: What does RM_ID identify (Relationship Manager?) and which master holds it?
- Proposed: Relationship manager id; release STM-CUS-0012

**Q-006: CRT_DT** (owner: Steward; severity: Medium)
- Observed: Frozen after insert; sample equals first account open date.
- Question: Is CRT_DT the customer relationship start date, or only the CRM record creation date (migration back-loads)?
- Proposed: Treat as customer open date

**Q-007: DEL_FLG** (owner: Steward + Architect; severity: Medium)
- Observed: 2.5% 'Y'; sample 104 is Y with KYC R.
- Question: Is DEL_FLG='Y' a soft delete? Should such customers appear as ACTIVE_FLG='N' or be excluded from the warehouse? Do physical deletes occur?
- Proposed: Load with ACTIVE_FLG='N'

**Q-013: ACCT_CLS_DT vs ACCT_STS** (owner: Steward; severity: Medium)
- Observed: 84% = 99991231.
- Question: Why do 16% of accounts have a real close date but only 14% status 'C'? Are D/S accounts, or future-dated closures, included? Is 99991231 the open marker?
- Proposed: Keep both fields as-is; report mismatches in DQ

**Q-015: Orphan accounts** (owner: Architect + Steward; severity: Medium)
- Observed: 99.99% FK overlap.
- Question: What to do with the ~0.01% (~9) accounts whose CUST_ID is not in CUST_MST: suspense/retry, or load against an 'Unknown customer' member (SK -1)?
- Proposed: Suspense (R06)

**Q-016: DIM_CUSTOMER SCD2** (owner: Modeler; severity: Medium)
- Observed: UPD_TS changes on any update.
- Question: Which attributes trigger a new version (all vs only type/country/KYC/branch/active)? What is EFF_FROM_TS for the first load (CRT_DT proposed)? Business or load time for later versions (UPD_TS proposed)?
- Proposed: All attributes; CRT_DT then UPD_TS

**Q-018: Fact grain and timing** (owner: Architect; severity: Medium)
- Observed: Source is current-state only; sample UPD_TS ~22:00.
- Question: Which accounts get a daily row (all, or only open)? What is the extract cut-off time and source timezone of UPD_TS? Can a prior day be restated?
- Proposed: All accounts; :BUSINESS_DT parameter; delete-insert by date

**Q-019: CTRY_CD** (owner: Modeler; severity: Medium)
- Observed: 41 distinct values.
- Question: Supply ISO list. Agree an unknown value that fits CHAR(2) ('ZZ'). For corporates is it residence or incorporation country?
- Proposed: ZZ

**Q-020: MOB_NO** (owner: Steward; severity: Medium)
- Observed: Mixed formats; sample 103 US 10-digit.
- Question: Supply dial-code table. Is it valid to prefix the customer country's dial code to 10-digit numbers without '+'?
- Proposed: Prefix by country, else NULL

**Q-021: OTH -> DEP** (owner: Steward + Modeler; severity: Medium)
- Observed: Reference file: 'Assumption - confirm'; 2% of accounts.
- Question: Confirm account type 06 'Other' maps to category DEP.
- Proposed: DEP

## Low

**Q-008: ACCT_MST.PRC_GRP_CD** (owner: Steward; severity: Low)
- Observed: 6 values, 64% null, 93% A1 of non-null, no reference table. No target column identified.
- Question: What do A1/A2/B1/B2/C1/Z9 mean? Is Z9 a default? Is it linked to a product/price table?
- Proposed: Stage raw, no mapping

**Q-009: CUST_MST.USR_FLD_1** (owner: Steward; severity: Low)
- Observed: 96% null; X1/X2/TMP/OLD/0/./BLK.
- Question: Confirm no downstream reliance and that it can be excluded.
- Proposed: Exclude

**Q-014: CUST_NM** (owner: Steward; severity: Low)
- Observed: Mixed case across rows.
- Question: Any standardisation wanted for 3% upper-case-only names, or titles/legal suffixes?
- Proposed: None (pass-through)
