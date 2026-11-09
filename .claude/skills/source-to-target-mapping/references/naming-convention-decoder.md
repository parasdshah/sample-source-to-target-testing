# Naming-Convention Decoder

Goal: turn cryptic table and column names into readable English business names, consistently.

## Method
1. **Collect the rules you were given** (prefix/suffix lists, module codes, separator style). These are authoritative. Record them in the token glossary with source "given".
2. **Tokenise** each name: split on `_`, camelCase, digits, and known fixed-width segments. Example: `CUST_ACCT_OPN_DT` → `CUST | ACCT | OPN | DT`.
3. **Build a token frequency table** across the whole source. Tokens that appear 20+ times are cheap to resolve and give the best return.
4. **Expand tokens** using, in order:
   a. Given convention and documented fields (~50% have explanations: mine them for token → meaning pairs, e.g. if `ACCT_OPN_DT` is documented as "Account Opening Date", you now know `OPN` and `DT`).
   b. Domain dictionary (see below).
   c. Co-occurrence: tokens always appearing with a known token (`_CD` next to a `_DESC` column suggests a code/description pair).
   d. Profile of the data (a `_DT` column holding 8-digit strings confirms date, with format `YYYYMMDD`).
5. **Assemble the English name** in Title Case, qualifier-first order, e.g. `Customer Account Opening Date`. Keep a technical-to-business name mapping.
6. **Resolve ambiguity** by recording alternatives and routing to the steward: `TYP` could be Type; `STS` Status; `BAL` Balance; `REF` Reference; `SEQ` Sequence; `NO`/`NUM`/`NBR` Number; `IND`/`FLG` Indicator/Flag; `CD` Code; `DESC` Description; `AMT` Amount; `QTY` Quantity; `DT` Date; `TS`/`TMS` Timestamp.
7. **Decode tables** the same way, then add the entity type: master, transaction, reference/code, history/audit, staging, bridge.

## Typical suffix / class words (starting dictionary; confirm each)
| Token | Likely meaning | Expected datatype pattern |
|---|---|---|
| `_ID`, `_KEY`, `_SK` | Identifier / surrogate key | integer or string, unique |
| `_NO`, `_NUM`, `_NBR` | Business number | string (leading zeros possible) |
| `_CD` | Code | short string, small domain |
| `_DESC`, `_NM`, `_NAME` | Description / name | string |
| `_DT`, `_DATE` | Date | date or 8-char string |
| `_TS`, `_TMS`, `_DTTM` | Timestamp | timestamp |
| `_FLG`, `_IND`, `_YN` | Flag / indicator | Y/N, 0/1, T/F |
| `_AMT`, `_VAL` | Amount / value | decimal |
| `_QTY`, `_CNT` | Quantity / count | integer / decimal |
| `_PCT`, `_RT` | Percentage / rate | decimal |
| `_CCY`, `_CUR` | Currency | 3-char code |
| `_STS`, `_STAT` | Status | code |
| `_TYP`, `_TP` | Type | code |
| `_SEQ` | Sequence | integer |
| `_FROM`, `_TO`, `_EFF`, `_EXP`, `_END`, `_STRT` | Validity period | date |
| `CRT_`, `CRE_`, `UPD_`, `MOD_`, `DEL_` | Created / updated / deleted audit | user or timestamp |

## Warnings
- The same token can differ by module (`REF` = reference vs referral; `ACC` = account vs access vs accrual). Resolve using the table context and sample data.
- Legacy systems reuse columns (`FILLER`, `RESERVED`, `USR_FLD_1`). Profile them. Treat them as unknown until proven.
- Keep a **negative list**: tokens deliberately not expanded and why.
- Language: if source names come from another language (transliteration), record the original token as well.

## Output: token glossary format
| Token | Expansion | Rule source | Confidence | Example fields |
|---|---|---|---|---|
| OPN | Opening | Derived from documented `ACCT_OPN_DT` | High | `ACCT_OPN_DT`, `LOAN_OPN_DT` |
| BR | Branch | Given convention | High | `BR_CD` |
| CLR | Clearing or Colour? | Ambiguous | Low: ask steward | `CLR_FLG` |
