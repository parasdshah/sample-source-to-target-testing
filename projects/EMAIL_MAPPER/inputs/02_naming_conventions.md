# MAIL02 Naming Conventions

## Part A: Source system conventions (as supplied by the source team)

1. Tables: `<ENTITY>_<CLASS>`; class `HDR` = header, `RCPT` = recipient detail, `MST` = master, `REF` = reference.
2. Columns: UPPER_CASE words separated by `_`; abbreviations are 2-4 letters.
3. Class words (last token): `_CD` code, `_NM` name, `_ID` identifier, `_ADR` address, `_TXT` free text, `_DT` date stored as CHAR(8) `YYYYMMDD`, `_STR` string-typed value, `_TS` timestamp, `_FLG` flag Y/N, `_CNT` count, `_SCR` score, `_BYT` bytes, `_SEQ` sequence number, `_STS` status, `_TYP` type.
4. Known abbreviations: MSG = Message, THRD = Thread, SNDR = Sender, RCPT = Recipient, SUBJ = Subject, SNT = Sent, RCV = Received, ATT = Attachment, SPM = Spam, MBX = Mailbox, DLV = Delivery, DIR = Direction, PRIO = Priority, DSP = Display, DEPT = Department, ACT = Active.
5. `USR_FLD_n` columns are free-use fields for administrators and have no defined meaning.
6. Source dates of `00000000` or `99999999` are legacy "not available" markers (not confirmed per column).
7. Source timestamps are in IST (UTC+05:30); the DW stores UTC.
8. Source system code for all records: `MAIL02`.

## Part B: Target model conventions
Not supplied. The target DDL (`03_target_model.sql`) is self-describing, so conventions are inferred from it: `_SK` surrogate key, `_CD` code, `_FLG` CHAR(1) Y/N, `_DT` DATE, `_TS` TIMESTAMP, `_CNT` count, audit columns `SRC_SYSTEM_CD`, `BATCH_ID`, `LOAD_TS`. Replace this part with the target team's rules if the target names are cryptic.
