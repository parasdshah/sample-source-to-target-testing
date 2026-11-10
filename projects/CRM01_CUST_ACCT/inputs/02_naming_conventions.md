# CRM01 Naming Conventions

## Part A: Source system conventions (as supplied by the source team)

1. Tables: `<ENTITY>_<CLASS>`; class `MST` = master, `DTL` = detail/transaction, `REF` = reference, `HST` = history.
2. Columns: UPPER_CASE words separated by `_`; abbreviations are 2-4 letters.
3. Class words (last token): `_CD` code, `_NM` name, `_NO` number, `_DT` date stored as CHAR(8) `YYYYMMDD`, `_TS` timestamp, `_FLG` flag Y/N, `_AMT` / `_BAL` / `_LMT` amount, `_RT` rate, `_STS` status, `_TYP` type, `_STR` string-typed value.
4. Known abbreviations: CUST = Customer, ACCT = Account, BR = Branch, CTRY = Country, CCY = Currency, OPN = Opening, CLS = Closing, CRT = Created, UPD = Updated, DEL = Deleted, ADR = Address, EML = Email, MOB = Mobile, NM = Name, DOB = Date of birth, KYC = Know Your Customer, TYP = Type, STS = Status.
5. `USR_FLD_n` columns are free-use fields for branch staff and have no defined meaning.
6. Source dates of `00000000` or `99999999` are legacy "not available / open-ended" markers (not confirmed per column).
7. Source system code for all records: `CRM01`.

## Part B: Target model conventions
Not supplied. The target DDL (`03_target_model.sql`) is self-describing, so conventions are inferred from it: `_SK` surrogate key, `_CD` code, `_FLG` CHAR(1) Y/N, `_DT` DATE, `_TS` TIMESTAMP, `_CNT` count, audit columns `SRC_SYSTEM_CD`, `BATCH_ID`, `LOAD_TS`. Replace this part with the target team's rules if the target names are cryptic.
