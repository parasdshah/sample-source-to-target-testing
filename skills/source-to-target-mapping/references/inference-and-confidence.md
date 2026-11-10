# Inferring the Undocumented Fields and Scoring Confidence

## Evidence ladder (strongest first)
| Rank | Evidence | Example |
|---|---|---|
| 1 | Documented definition | Source data dictionary entry |
| 2 | Confirmed by steward / SME | Email or ticket response, logged |
| 3 | Profiled data | Distinct values `{Y,N}`; 8-digit strings that parse as dates; FK overlap of 99% with another table's key |
| 4 | Usage evidence | Appears in existing SQL, views, reports, stored procedures, UI labels, copybooks, API schemas |
| 5 | Naming convention | Token expansion from the decoder |
| 6 | Analogy | Sibling table or field with the same pattern |

## Profiling checks per undocumented field
- Datatype fit, length distribution, pattern (regex classes), null and blank %, default-value spike (e.g. `'0'`, `'N/A'`, `'1900-01-01'`).
- Cardinality and top 20 values with counts; check whether the domain looks like codes.
- Min/max and distribution for numerics and dates; negative values; scale.
- Key tests: uniqueness, candidate key, FK overlap against other tables' keys (inclusion dependency).
- Relationship with other columns: functional dependency (`A → B`), mutually exclusive populated columns (suggests type-dependent fields), `_FROM`/`_TO` ordering.
- Change behaviour: is it updated often or frozen after insert? (Audit vs business attribute.)
- Join to code or reference tables to discover meaning of codes.

## Confidence scoring
Score each decoded meaning 0-100, then band it.
| Factor | Points |
|---|---|
| Documented or steward-confirmed | +60 to +100 (set directly) |
| Profile consistent with meaning | +25 |
| Usage evidence found | +25 |
| Naming token expansions all high-confidence | +15 |
| Analogous documented sibling field | +10 |
| Profile contradicts name | −30 |
| Ambiguous token with no tie-breaker | −20 |
| Mixed or unexplained values (e.g. a flag with 5 distinct values) | −20 |

Bands (team defaults: calibrate):
- **High (≥75):** safe to map and build; steward notified.
- **Medium (50-74):** map as Inferred; build allowed only for non-critical, reversible fields; steward review within the sprint.
- **Low (<50):** do not build business rules. Stage raw, ask steward.

Always override to Low for: financial amounts, regulatory fields, identifiers, PII classification, and anything feeding a key or join, unless evidence rank is 1-3.

## Steward question format
```
Q-017  Field: ORD_HDR.PRC_GRP_CD
Observed: 6 distinct values {A1,A2,B1,B2,C1,Z9}; 97% = A1; joins to no reference table.
Naming suggests: Price Group Code (Medium).
Question: What does each value mean, and is Z9 a default/unknown?
Impact: Maps to PRODUCT_PRICE.PRICE_TIER_CD (mandatory in target).
Needed by: <date>
```

## Handling results
- Update the status column and glossary when answers arrive; re-score dependent fields.
- Fields that stay Low are listed in the gap report with business impact and a recommended fallback (stage raw, default value, exclude).
- Never promote a Low field to Confirmed because a developer "needs it for the build".
