# Inferring Undocumented Fields and Scoring Confidence

## 0. Anti-invention rules (read first)
1. Use only facts that are in the supplied files (inventory, samples, reference codes, conventions, DDL, any SQL or reports given). If a fact is not supplied, write `not supplied`.
2. Never invent a percentage, count, minimum, maximum or sample value. Never "estimate" a statistic. You may do arithmetic on supplied numbers (for example 48% + 23% + 29% = 100%) and must show the numbers used.
3. You cannot query the database. Where a check would need a query, write the query as a steward or analyst question instead of claiming the result.
4. Naming alone never gives High confidence.
5. If two interpretations fit, record both and ask. Do not pick the one you like.

## 1. Evidence ladder (strongest first)
| Rank | Evidence | Example |
|---|---|---|
| 1 | Documented definition | Vendor description in the inventory; reference-code entry with status `Documented` |
| 2 | Confirmed by steward or SME | Logged answer to a question |
| 3 | Profiled data | Distinct values `{Y,N}`; strings that all parse as dates; 99% key overlap with another table |
| 4 | Usage evidence | Existing SQL, reports, views; reference-code entry with status `Inferred (profile + report usage)` |
| 5 | Naming convention | Token expansion from the dictionary or the given conventions |
| 6 | Analogy | A documented sibling column with the same pattern |

## 2. Profiling checks for each undocumented field (use only the supplied profile; ask for the rest)
Check each item and record the result as a fact or `not supplied`.
1. Datatype and length fit the proposed meaning.
2. Null %: above 90% = rarely used; above 0 on a key = suspicious.
3. Blank % (if `blank_pct` is supplied).
4. Distinct count against row count: `distinct <= 3` = flag or small code set; `distinct <= 50` = code set; `distinct / rows >= 0.99` = near-unique (key or free text).
5. Top values: a single value above 20% on a column with more than 20 distinct values is a default-value spike (examples: `0`, `N/A`, `1900-01-01`).
6. Min and max: do they match a known limit (25 MB, 100, today's date)? Does min < max for `FROM`/`TO` pairs?
7. Pattern: all digits, fixed length, date-like, contains `@`, prefix + digits.
8. Key and overlap: for a suspected foreign key, overlap with the parent key >= 95% = FK likely; 50-95% = partial, ask; < 50% = not an FK.
9. Cross-column agreement: do two columns tell the same story (flag `Y` % equals timestamp populated %)? This is strong evidence.
10. Change behaviour: changes on every update (audit) or never (created-date)? Only if supplied.
11. Sample rows: do the values look as the name suggests?

## 3. Confidence score (0-100): the algorithm
Score each field's MEANING. Follow these steps in order.

Step 1. If the meaning is documented (rank 1): score = 90. If confirmed by a steward (rank 2): score = 100. Stop.

Step 2. Otherwise start at 0 and add each factor that applies. Each factor counts at most once.
| Factor | Points | Rule |
|---|---|---|
| A. Profile consistent with the meaning | +25 | At least two checks from section 2 agree with the meaning and none disagree |
| B. Usage evidence | +25 | Existing SQL/report supplied, or the reference-code entry says `Inferred (profile + report usage)` |
| C. Naming | +15 | Every token of the name is High confidence in the glossary |
| C. Naming (partial) | +10 | The class word (last token) is High and the other tokens are Medium or better |
| C. Naming (weak) | +0 | Any token Low or unresolved |
| D. Documented sibling | +10 | A documented column of the same table or another table has the same pattern and meaning |
| E. Corroboration | +15 | The data agrees with an independent fact: a documented limit, or two columns agree (section 2 item 9), or sample rows plainly match the description |

Step 3. Subtract each penalty that applies (once each):
| Penalty | Points |
|---|---|
| Profile contradicts the name or meaning | -30 |
| A token is ambiguous and nothing breaks the tie | -20 |
| Unexplained values (a code set with values nobody can explain, a flag with more than 2 values) | -20 |

Step 4. Clamp to 0..100. Write the number as `(score NN)` at the end of the `Evidence for meaning` text.

Step 5. Band: `High` >= 75, `Medium` 40-74, `Low` < 40. (A clear name plus a consistent profile = 25 + 15 = 40 = Medium. Naming alone = 15 or profile alone = 25 = Low.)

Step 6. Overrides, applied after banding:
- Force `Low` for financial amounts, regulatory fields, identifiers and keys, PII classification, and anything feeding a join, UNLESS the evidence is rank 1-3.
- A code VALUE marked `confirm with steward` in the reference file is `Low` for that value, even when the field is Medium.
- The maximum score without documentation, usage or reference-file evidence is 25+15+10+15 = 65 (Medium). Reaching High without usage or documentation is impossible by design.

### Worked scoring examples
| Field | Facts | Calculation | Result |
|---|---|---|---|
| `MSG_HDR.SZ_BYT` | Profile: integer, max 26,214,400 = documented 25 MB gateway limit, sample 1,048,576. Tokens: `BYT` given, `SZ` inferred (Medium). | A +25 (types fit and values plausible), C partial +10 (class word `BYT` High, `SZ` Medium), E +15 (max equals the 25 MB limit) | 50 = Medium |
| `MSG_HDR.DIR_CD` | Values `I,O,X`. Reference file marks `I`,`O` `Inferred (profile + report usage)`, `X` `confirm with steward`. | A +25, B +25, C +15 (`DIR`, `CD` High) | 65 = Medium. Value `X` = Low. |
| `MSG_RCPT.RD_FLG` | `RD` not in the given list. Flag `Y` 48% = `RD_TS` populated 48%; `RD_TS` null 52% = `N` 23% + null 29%. | A +25, C partial +10 (`FLG` High, `RD` Medium), E +15 (two columns agree) | 50 = Medium |
| `MSG_RCPT.DLV_STS` | Reference file `Inferred (profile + report usage)` for 4 codes; profile shows 6 distinct values, 2 not in the reference file. Tokens `DLV`,`STS` given. | A +25, B +25, C +15, unexplained values -20 | 45 = Medium, with a question because of the -20 |
| `MBX_MST.ACT_FLG` | Values `Y` 91%, `N` 9%. `ACT` and `FLG` given. | A +25, C +15 | 40 = Medium (lowest Medium) |
| `MSG_HDR.USR_FLD_1` | Convention rule: free-use field, no defined meaning; values `X1`, `TMP`, `0`, `.`. | Rank-1 statement that there is no meaning. | Do not score a business meaning. Disposition: `Staged raw only`. |

## 4. What to do with each band
- High: map and build. Status `Confirmed`, notify the steward.
- Medium: map as `Inferred`. Building is allowed for reversible or pass-through fields; production release needs steward review. Add a question when any of checks 2-9 in section 2 raised a doubt.
- Low: do not write business rules. Either stage the column raw (disposition `Staged raw only`) or map it with Status `Draft`, and ask a question. Never promote a Low field to Confirmed because a developer needs it.

## 5. Writing the evidence text
Format: `<Rank name>: <fact with numbers>; <rank name>: <fact> (score NN)`.
Example: `Profiled: max 26,214,400 = 25 MB gateway limit; Naming: BYT=bytes (given), SZ=size (inferred) (score 50)`.

## 6. Steward questions
### Severity (use exactly these words at the start of the `Severity / impact` text)
- `BLOCKER`: a mandatory target column has no source or rule, or the load cannot be designed without the answer.
- `High`: a wrong answer changes totals, keys, joins, timestamps or regulatory fields.
- `Gates production`: the build can start, but release must wait for the answer (typically a Medium-confidence meaning on a regulatory, reporting or code-set column).
- `Medium`: a wrong answer changes a descriptive column or a code set.
- `Low`: cosmetic, informational or optional.

### Wording rules
1. One question per line, answerable with a fact or a yes/no/choice.
2. Open with the observed numbers from the profile, then the question, then your proposed default.
3. Name the target column affected.
4. Name an owner role (steward, DBA, modeler, privacy, security, business owner).
5. Number questions `Q-001`, `Q-002` ... in the order you create them. IDs never change.

### Format
```
Q-017  Field: MSG_RCPT.DLV_STS  ->  BRIDGE_EMAIL_RECIPIENT.DELIVERY_STATUS_CD
Observed: 6 distinct values; SN 84%, DF 5%, BN 3%, DL 2%, null 8%; only SN, DL, DF, BN are in the reference file.
Naming suggests: Delivery Status (High for the tokens).
Question: What are the two other codes? Why is SN ("Sent") 84% while DL ("Delivered") is 2%?
Proposed: Unlisted codes and NULL map to UNKNOWN; if SN is the normal final state, map SN to DELIVERED.
Impact: DELIVERY_STATUS_CD is mandatory in the target.
Owner: steward.  Severity: Medium.
```

## 7. Handling answers
Update the sheet 5 row, the glossary and the STM row; re-score dependent fields; change Status when the new score crosses a band.
