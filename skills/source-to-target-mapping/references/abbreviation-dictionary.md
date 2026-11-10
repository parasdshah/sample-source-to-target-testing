# Abbreviation Dictionary (starting list; always confirm against the given conventions and the data)

How to use: look up each token. `Ambiguous = Y` means there are several plausible meanings; pick one ONLY with a tie-breaker (table name, data profile, documented sibling) and record the other candidates in the question list. Given conventions (Part A of `02_naming_conventions.md`) override this file. A token found here but not in the given conventions is `Inferred` with confidence Medium (High only if a documented column confirms it).

## 1. Class words (usually the LAST token)
| Token | Expansion | Ambiguous | Expected datatype / note |
|---|---|---|---|
| ID | Identifier | N | string or integer, unique within entity |
| KEY | Key | N | surrogate or business key |
| SK | Surrogate key | N | integer, system generated |
| NO, NUM, NBR | Number (business number) | N | string; keep leading zeros |
| CD | Code | N | short string, small domain; look for a reference table |
| NM, NAME | Name | N | string |
| DESC, DSC | Description | N | string |
| TXT | Free text | N | long string; may hold PII |
| DT, DATE | Date | N | DATE, or CHAR(8) `YYYYMMDD` (check the given convention) |
| TS, TMS, DTTM, DTM | Timestamp / date-time | N | TIMESTAMP |
| TM, TIME | Time of day | N | TIME or CHAR(6) `HHMMSS` |
| FLG, FLAG, IND, YN | Flag / indicator | N | `Y/N`, `1/0`; check the domain for a third value |
| AMT | Amount | N | DECIMAL; money |
| BAL | Balance | N | DECIMAL; signed |
| LMT | Limit | N | DECIMAL |
| VAL | Value | Y (amount vs code) | use the datatype to decide |
| QTY | Quantity | N | integer or decimal |
| CNT | Count | N | integer |
| PCT | Percent | N | DECIMAL 0-100 |
| RT, RATE | Rate (interest rate, exchange rate) | Y (rate vs route) | DECIMAL; check magnitude |
| SCR, SCORE | Score | N | DECIMAL |
| SEQ | Sequence number | N | integer |
| STS, STAT | Status | N | code |
| TYP, TP | Type | N | code |
| CAT, CATG | Category | N | code |
| GRP | Group | N | code or text |
| LVL | Level | N | integer or code |
| STR | String-typed value (a non-text value stored as text) | N | check the real type (date, number) |
| BYT, BYTES | Bytes | N | integer |
| URL, URI | Web address | N | string |
| ADR, ADDR | Address | Y (postal vs email) | decide by table context and data: contains `@` = email |
| FMT | Format | N | code |
| LANG | Language | N | ISO code |

## 2. Audit and system tokens
| Token | Expansion | Ambiguous | Note |
|---|---|---|---|
| CRT, CRE | Created | N | with `_DT`/`_TS`/`_BY`; never updated after insert if truly created |
| UPD, MOD, CHG | Updated / modified / changed | N | usually changes on every update |
| DEL | Deleted | N | `DEL_FLG` = soft delete |
| BY, USR, USER | User | N | `CRT_BY` = created by |
| FRM, FROM | Valid from | N | with `TO` forms a validity period |
| TO | Valid to | N | open-ended often `9999-12-31` or `99991231` |
| EFF | Effective | N | `EFF_DT` |
| EXP | Expiry | Y (expense, export) | decide by context |
| STRT, START | Start | N | |
| END | End | N | |
| OPN | Opening / opened | N | |
| CLS, CLSD | Closing / closed | Y (class, close) | `CLS_DT` = closing date; `CLS_CD` may be class |
| BATCH, BTCH | Batch | N | |
| SRC | Source | N | `SRC_SYSTEM_CD` |
| TGT | Target | N | |
| SYS | System | N | |
| LD, LOAD | Load | N | `LOAD_TS` |
| VER, VRSN | Version | N | |
| REV | Review / revision / reverse | Y | decide by context |
| ARCH | Archive | N | |
| TMP, TEMP | Temporary | N | |
| FLD | Field | N | `USR_FLD_n` = free-use user field, no defined meaning |
| FILLER, RSVD, RESV, SPARE | Reserved / unused | N | treat as unknown until profiled |
| CUR | Current (flag) or currency | Y | `CUR_FLG` = current; `CUR_CD` = currency; `CUR_BAL` = current balance |
| PREV, PRV | Previous | N | |
| LST, LAST | Last | N | |
| FST, FIRST | First | N | |
| MAX, MIN, AVG, TOT, TTL, SUM | Maximum, minimum, average, total, sum | N | |

## 3. Customer, party and CRM
| Token | Expansion | Ambiguous | Note |
|---|---|---|---|
| CUST, CST, CLT | Customer / client | N | |
| PRTY, PTY | Party | N | |
| IND, INDV | Individual | Y (indicator) | `_IND` as the last token = indicator; `INDV` = individual |
| CORP, CRP | Corporate | N | |
| ORG | Organisation | N | |
| EMP | Employee | N | |
| MGR | Manager | N | |
| RM | Relationship manager | Y | confirm; ID patterns like `RM00412` support it |
| SEG, SGMT | Segment | N | |
| DOB | Date of birth | N | |
| GNDR, GEN, SEX | Gender | N | |
| MRTL, MAR | Marital | N | |
| NATL, NAT | Nationality | N | |
| CTRY, CNTRY | Country | N | |
| ST, STE | State (or street, status) | Y | decide by context and values |
| CITY, CTY | City | N | |
| PIN, ZIP, PSTL | Postal code | N | |
| PH, PHN, TEL | Phone | N | |
| MOB, MBL | Mobile | N | |
| EML, EMAIL | Email | N | |
| FNM, FST_NM | First name | N | |
| LNM, LST_NM | Last name | N | |
| SAL | Salutation (or salary) | Y | |
| KYC | Know Your Customer | N | regulatory |
| AML | Anti-money laundering | N | regulatory |
| DOC | Document (identification document) | N | PII |
| PAN, SSN, NID, TIN | National / tax identifier | N | Sensitive PII; mask |
| LOY | Loyalty | N | |
| REL | Relationship | N | |
| PREF | Preference | N | |
| CNSNT, CNST | Consent | N | privacy |
| OPT | Opt (in/out) | N | |

## 4. Banking, finance, insurance
| Token | Expansion | Ambiguous | Note |
|---|---|---|---|
| ACCT, AC, ACC | Account | Y (ACC = access, accrual) | decide by table context |
| BR, BRN | Branch | N | |
| BNK | Bank | N | |
| CCY | Currency | N | ISO 4217 code |
| FX | Foreign exchange | N | |
| TXN, TRN, TRX | Transaction | N | |
| PMT, PYMT | Payment | N | |
| DR, DEB | Debit | N | |
| CR, CRD | Credit (CR) / card (CRD) | Y | `CR_` + amount = credit; `CRD_NO` = card number |
| INT | Interest (or integer, internal) | Y | `INT_RT` = interest rate |
| PRIN, PRN | Principal | N | |
| OD | Overdraft | N | `OD_LMT` = overdraft limit |
| LN | Loan | N | |
| MTG | Mortgage | N | |
| DEP | Deposit | N | |
| WDL, WTH | Withdrawal | N | |
| SAV | Savings | N | |
| CHK, CHQ | Cheque / check | N | |
| TDP, FD | Term / fixed deposit | N | |
| LMT | Limit | N | |
| COL, COLL | Collateral | N | |
| GL | General ledger | N | |
| LDGR | Ledger | N | |
| AVL | Available | N | `AVL_BAL` |
| CLR | Clearing (or clear, colour) | Y | |
| SETL, STL | Settlement | N | |
| MAT | Maturity | N | |
| TNR | Tenor | N | |
| PRD, PROD | Product | Y (period) | `PRD_CD` = product code; check values |
| PLCY, POL | Policy (insurance) | N | |
| PREM | Premium | N | |
| CLM | Claim | N | |
| BEN | Beneficiary | N | |
| NOM | Nominee | N | |
| COMM | Commission | Y (communication) | |
| TAX, TX | Tax | N | |
| FEE, CHG | Fee / charge | N | |
| DISC | Discount | N | |
| INV | Invoice | N | |
| ORD | Order | N | |
| PO | Purchase order | N | |
| SKU | Stock keeping unit | N | |
| WH | Warehouse | N | |
| SUP, VND, VNDR | Supplier / vendor | N | |

## 5. Messaging and email
| Token | Expansion | Ambiguous | Note |
|---|---|---|---|
| MSG | Message | N | |
| THRD | Thread | N | |
| SNDR | Sender | N | |
| RCPT, RCP | Recipient | N | |
| SUBJ | Subject | N | |
| SNT | Sent | N | |
| RCV | Received | N | |
| RD | Read (not received) | Y | check for a matching timestamp that is populated when read |
| ATT, ATTCH | Attachment | N | |
| SPM, SPAM | Spam | N | |
| MBX | Mailbox | N | |
| DLV | Delivery | N | |
| DIR | Direction | N | |
| PRIO, PRI | Priority | N | |
| DSP | Display | N | |
| DEPT | Department | N | |
| FWD | Forward | N | |
| RPLY, RE | Reply | N | |
| CC, BCC | Carbon copy, blind carbon copy | N | |
| SZ | Size | N | not in most given lists: confirm with the profile |
| BNC | Bounce | N | |
| QUE, Q | Queue | N | |

## 6. General
| Token | Expansion | Ambiguous | Note |
|---|---|---|---|
| ACT, ACTV | Active | Y (action, actual) | `ACT_FLG` = active flag |
| INACT | Inactive | N | |
| APPR, APR | Approved | N | |
| REJ | Rejected | N | |
| PEND, PND | Pending | N | |
| CNCL, CAN | Cancelled | N | |
| CMPL, CMP | Completed | Y (company, compare) | |
| DFLT, DEF | Default | N | |
| ORIG | Original | N | |
| REF | Reference | Y (referral) | |
| RFRL | Referral | N | |
| REM, RMK, CMT, NOTE | Remark / comment | N | free text; may hold PII |
| LOC | Location | N | |
| REG | Region | Y (registration) | |
| ZN | Zone | N | |
| SEC | Security / section / second | Y | |
| AUTH | Authorisation / authentication | Y | |
| PWD | Password | N | Sensitive; exclude |
| LGN, LOGIN | Login | N | |
| SESS | Session | N | |
| ENT | Entity | N | |
| REC | Record | Y (receipt, receive) | |
| ITM | Item | N | |
| PGM | Program | N | |
| PRC | Price / process | Y | `PRC_GRP_CD` = price group |
| NO_OF | Number of | N | |
| IS_, HAS_ | Boolean prefix | N | |

## 7. Table class words (suffix of table names)
| Token | Meaning |
|---|---|
| MST, MAST | Master |
| DTL, DET | Detail / transaction line |
| TXN | Transaction |
| HDR | Header |
| REF, LKP, CD | Reference / lookup / code table |
| HST, HIST | History |
| AUD | Audit |
| STG | Staging |
| BRG, XREF | Bridge / cross-reference |
| DIM, FCT, FACT | Dimension, fact (targets) |
| TMP, WRK | Temporary / work |
| LOG | Log |
