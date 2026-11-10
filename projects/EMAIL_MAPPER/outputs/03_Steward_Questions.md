# Open Questions: MAIL02 Email -> DW (STM v0.1 DRAFT)

Written for: data steward, source DBA, data modeler and privacy/security reviewers, who need to answer them.
Same list as sheet `5_Open_Questions` in `01_STM_MAIL02_EMAIL.xlsx`. Reply by Q-number; the STM is updated when answers arrive.

## Blocker (cannot go live without an answer)

**Q-001: Company-owned email domains** (owner: steward + IT messaging)
- Field: `DIM_EMAIL_ADDRESS.INTERNAL_FLG` (mandatory in target, no source field).
- Question: Which domains are company-owned, including subdomains and acquired brands? Who owns the list?
- Why it matters: with no list every address loads as `N`, and internal/external reporting is wrong without any error.
- Proposed: steward supplies `REF_INTERNAL_DOMAIN`; parent-domain match is allowed.

## High impact

**Q-002: Addresses without an '@'** (steward + modeler)
- Observed: about 0.1% of recipient addresses contain no `@` (`RCPT_ADR` 99.9%, `SNDR_ADR` 100%). The bridge key column is NOT NULL.
- Question: Load them to a default "unknown address" member (SK -1), reject the row, or keep the raw text elsewhere?
- Proposed: SK -1 plus an R02 log with the raw value. Never drop the recipient row.

**Q-003: Timezone of source timestamps** (source DBA)
- Fields: `SNT_TS`, `RD_TS`, `UPD_TS`. Convention rule 7 says IST, but only `SNT_TS` says "server local time (IST)".
- Question: Are all three fixed IST (UTC+05:30, no daylight saving)? Has the server zone ever changed?
- Proposed: yes, fixed IST for all three; subtract 5h30m.

**Q-011: Duplicate copies of one email** (modeler + steward)
- Observed: `MSG_HDR` has one row per copy captured from a mailbox; `MSG_ID` is unique (912,400) and there is no global message id.
- Question: If the same email is captured from two mailboxes, should the target keep both as separate messages or dedupe?
- Proposed: keep one row per `MSG_ID`; copies stay separate.

**Q-012: Incremental load design** (source DBA)
- Observed: only `MSG_HDR.UPD_TS` exists. `MSG_RCPT` (read and delivery state) and `MBX_MST` have no update timestamp.
- Question: Does `MSG_HDR.UPD_TS` change when a recipient row changes (read receipts, delivery updates)?
- Proposed if not: reload recipients of messages sent in the last N days each run, plus a weekly full compare. `MBX_MST` (3,100 rows) is reloaded in full daily.

**Q-019: Privacy of subjects, names and addresses** (privacy / security, before the first non-prod load)
- Question: What classification and masking apply to `SUBJ_TXT`, `SNDR_DSP_NM` and addresses? May subjects be loaded at all?
- Proposed: Confidential/PII; mask or exclude in non-prod.

**Q-020: Target model changes** (modeler)
- Please: (1) add an `UNKNOWN` member (SK -1) to `DIM_EMAIL_ADDRESS`; (2) decide whether `DIRECTION_CD` needs an `UNKNOWN` value (currently only INBOUND/OUTBOUND/INTERNAL); (3) confirm `DIM_EMAIL_ADDRESS` is SCD1 only; (4) confirm upsert (not append) for the fact and bridge, since messages change (soft delete, spam, read state).
- Proposed: yes to 1, 3, 4; keep 2 as "reject".

## Gates production (build can start)

**Q-005: `DIR_CD`** (steward). Confirm I=Inbound, O=Outbound, X=Internal (X is 5% of rows, Low confidence). How is direction decided? Proposed: as in the reference file; reject unknown values.

**Q-008: `DLV_STS`** (steward). Profile shows 6 distinct codes but only SN/DL/DF/BN are listed. Why is SN ("Sent") 84% and DL ("Delivered") only 2%? What does NULL (8%) mean, and does it apply to inbound mail? Proposed: unlisted codes and NULL map to UNKNOWN; if SN is the normal final state, remap SN to DELIVERED.

**Q-014: `MBX_TYP_CD`** (steward). Confirm D = Distribution list and G = Group (11% of mailboxes). Should a distribution list appear as a recipient or as a mailbox?

## Medium

**Q-004: `RCV_DT_STR`** (steward). Is the date IST or UTC? Do `00000000` (5.7%) and `99999999` (0.3%) both mean "not available"? Why does outbound sample row 104 carry `99999999`? Proposed: both are NULL; date is IST.

**Q-006: `PRIO_CD`** (steward). Profile max is 9 but only 1, 3, 5 are listed. What are the other codes? Does NULL (31%) mean "not set" rather than Normal? Proposed: others and NULL map to UNKNOWN.

**Q-007: `SPM_SCR` / `SPM_FLG`** (steward + messaging admin). What is the score scale and the flag threshold? The flag is `Y` on 7% of rows but only 2% have a score above 80; is it set by something other than the score? What does a NULL score (9.5%) mean? Proposed: pass both through unchanged.

**Q-009: `RD_FLG` / `RD_TS`** (steward). Confirm RD = Read. Does NULL `RD_FLG` (29%) mean "not tracked" (for example external recipients)? Can the flag be `N` while `RD_TS` has a value? Proposed: NULL flag becomes `U`; if `RD_TS` is present set `Y`.

**Q-013: `DEL_FLG`** (steward + compliance). User soft-delete, retention purge, or both? Load deleted rows with `Y` or exclude? Are rows ever physically purged? Proposed: load with `Y`; add a periodic key compare for physical deletes.

**Q-015: `MSG_HDR.MBX_ID` overlap** (analyst, profiling). FK overlap with `MBX_MST` was not in the profile. Run the overlap query. Unmatched rows go to suspense (R06).

**Q-017: Address normalisation** (modeler + steward). Is lower-casing the whole address the intended identity rule (local parts are technically case-sensitive)? Collapse `+tag` or dots? Strip angle brackets or `mailto:`? Proposed: lower-case and trim only.

## Low

**Q-010: `THRD_ID` NULL (4.1%)** (steward + modeler). Does NULL mean standalone message? Proposed: load NULL as NULL.

**Q-016: `DEPT_CD`** (steward). Is there a department reference table for the `DP9{4}` codes? Is NULL (12%) expected?

**Q-018: Versions** (modeler). Source version, extract date and target model version were not given. Proposed: assume v0.1 draft for both.

**Q-021: Target naming conventions** (modeler). Part B of `02_naming_conventions.md` was not supplied. Please confirm the inferred rules (`_SK`, `_CD`, `_FLG` CHAR(1), `_UTC`, audit columns).
