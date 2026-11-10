# Naming-Convention Decoder

Goal: turn cryptic table and column names into readable English business names, the same way every time, for BOTH the source and the target model.

Inputs: `02_naming_conventions.md` (Part A = source, Part B = target), the inventory, the DDL, `abbreviation-dictionary.md`.
Outputs: sheet `3_Token_Glossary` and the `Decoded English name` column of sheet `2_Source_Inventory`.

## Method (follow in order)

### Step 1. Load the rules you were given
Read Part A (and Part B for the target). Copy every token-to-meaning pair into your working glossary with Rule source = `Given`, Confidence = High. Given rules are authoritative, EXCEPT for datatype and format claims: if the data contradicts a given rule (for example `_DT` is said to be CHAR(8) but a `_DT` column is a real DATE), keep the rule for naming but record the conflict as a question, and use the data for the datatype.

### Step 2. Tokenise every name
Rules:
1. Split on `_`. `CUST_ACCT_OPN_DT` -> `CUST | ACCT | OPN | DT`.
2. Split camelCase and PascalCase at lower-to-upper changes: `custAcctNo` -> `cust | Acct | No`.
3. A trailing number is its own token and stays a number: `USR_FLD_1` -> `USR | FLD | 1` (decoded as "User Field 1").
4. If there are no separators (`CUSTNM`, `ACCTNO`), try to split into known tokens from the dictionary, longest match first; if two splits work, record both and ask.
5. Table names: same method; the last token is usually the table class word.

### Step 3. Count tokens
Make a list of tokens and how many columns use each. Resolve the most frequent tokens first.

### Step 4. Expand each token (stop at the first source that gives an answer)
a. Given conventions (Step 1).
b. Documented columns: if `ACCT_OPN_DT` has the description "Account Opening Date", then `OPN` = Opening and `DT` = Date (Rule source: `Derived from documented ACCT_OPN_DT`, High).
c. `abbreviation-dictionary.md` (Rule source: `Inferred (dictionary)`, Medium; High if a documented column agrees).
d. Techniques for unknown tokens, in this order:
   1. Vowel dropping: remove vowels from candidate words and compare (`MNGR` -> manager, `CRDT` -> credit, `TXN` -> transaction).
   2. Truncation: first 3-4 letters (`DESC` -> description, `ADR` -> address).
   3. Initials: `DOB` -> date of birth, `KYC` -> know your customer.
   4. Co-occurrence: a token always next to a known token (`_CD` next to `_DESC` = code and description pair).
   5. Profile: 8 digits that parse as dates confirm a date; two values `{Y,N}` confirm a flag.
e. If none works: Expansion = `Unknown`, Confidence = Low, add a question.

### Step 5. Resolve ambiguity
A token is ambiguous only when the dictionary lists several meanings (column `Ambiguous = Y`) or two techniques give different answers. Resolve with a tie-breaker in this order: (1) given convention, (2) documented sibling column, (3) the table context, (4) the profile (values, patterns), (5) the target column it is likely to feed. If no tie-breaker works, keep the most likely meaning, set Confidence = Low, record the alternatives in the glossary row and raise a question.

### Step 6. Build the English name for each column
Formula: `[Entity words] + [Attribute words] + [Class word expansion]`, Title Case.
1. Add the entity words only when the column name alone would be ambiguous in the model (generic names such as `STS_CD`, `TYP_CD`, `NM`): `CUST_MST.STS_CD` -> `Customer Status Code`.
2. Do not repeat the entity: `ACCT_MST.ACCT_NO` -> `Account Number`, not `Account Account Number`.
3. Names that already stand alone keep their own words: `MSG_HDR.SUBJ_TXT` -> `Subject Text`, `MSG_RCPT.RCPT_ADR` -> `Recipient Address`.
4. Class word expansions are fixed: `_CD` Code, `_NM` Name, `_NO` Number, `_ID` ID, `_DT` Date, `_TS` Timestamp, `_FLG` Flag, `_AMT` Amount, `_BAL` Balance, `_LMT` Limit, `_RT` Rate, `_STS` Status, `_TYP` Type, `_CNT` Count, `_SEQ` Sequence, `_SCR` Score, `_TXT` Text, `_STR` (see below), `_ADR` Address.
5. A `_STR` column holds a value stored as text: name it for the real value plus "(string)": `RCV_DT_STR` -> `Received Date (string)`.
6. Tables: `[Entity words] + [table class expansion]`: `MSG_HDR` -> `Message Header`, `MBX_MST` -> `Mailbox Master`. Add the entity type: master, transaction/detail, reference, history, audit, staging, bridge.

### Step 7. Decode the target model the same way
Use Part B if supplied. If Part B says `Not supplied`, infer from the DDL and its comments (`_SK` surrogate key, `_FLG` CHAR(1), `_CD` code, `_DT` DATE, `_TS` TIMESTAMP, `_UTC` stored in UTC). Mark those glossary rows `Inferred from target DDL`, Medium, and add one question asking the modeler to confirm.

### Step 8. Negative list
Keep a list of tokens you deliberately did not expand and why (for example `X1` is a value, not a token). Put it in the `Comments` of the glossary's last row or in `0_Header` assumptions.

## Worked example (source = mail system)

Input columns: `MSG_HDR.SZ_BYT`, `MSG_RCPT.RD_FLG`, `MSG_HDR.USR_FLD_1`, `MSG_HDR.RCV_DT_STR`.
Given Part A has: BYT (class word bytes), FLG (flag Y/N), USR, FLD, RCV = Received, DT, STR, MSG, HDR, RCPT.

| Column | Tokens | Expansion steps | Decoded name | Confidence |
|---|---|---|---|---|
| `SZ_BYT` | SZ, BYT | BYT = given. SZ not given; dictionary: Size (Medium); profile: integer max 26,214,400 = 25 MB limit corroborates | Size in Bytes | Medium (score 50) |
| `RD_FLG` | RD, FLG | FLG = given. RD not given; dictionary: Read (ambiguous with Received, which is `RCV`); tie-breaker = profile: `Y` 48% equals `RD_TS` populated 48% | Read Flag | Medium (score 50) |
| `USR_FLD_1` | USR, FLD, 1 | USR, FLD given; number kept; convention says free-use field with no defined meaning | User Field 1 | Low: staged raw only |
| `RCV_DT_STR` | RCV, DT, STR | all given | Received Date (string) | Medium (score from the field, not the tokens) |

Glossary rows produced: `SZ | Size | Inferred (dictionary + profile) | Medium | SZ_BYT`, `RD | Read | Inferred (profile: RD_FLG Y% = RD_TS populated %) | Medium | RD_FLG, RD_TS`.

## Quality checks before you finish
1. Every token of every source and target column appears in the glossary (or in the negative list).
2. No token has two different expansions.
3. Every `Low` glossary row has a question ID in the question list.
4. Decoded names contain no abbreviations except well-known acronyms (ID, KYC, UTC).

## Output: token glossary format (sheet 3)
| Token | Expansion | Rule source | Confidence | Example fields |
|---|---|---|---|---|
| OPN | Opening | Derived from documented `ACCT_OPN_DT` | High | `ACCT_OPN_DT`, `LOAN_OPN_DT` |
| BR | Branch | Given | High | `BR_CD` |
| CLR | Clearing (alternative: Colour) | Ambiguous, no tie-breaker | Low (Q-nnn) | `CLR_FLG` |
