# Checklists

## 1. Intake checklist
- [ ] Source field list with datatypes, lengths, nullability, keys
- [ ] Documented descriptions identified (and counted)
- [ ] Naming conventions and abbreviation lists received
- [ ] Target model with keys, constraints, SCD approach, grain
- [ ] Reference/code tables available
- [ ] Sample data or profiling access granted
- [ ] Existing SQL/reports/copybooks for usage evidence
- [ ] Load pattern and ETL tool(s) confirmed
- [ ] Sensitive-data classification rules available

## 2. Mapping quality checklist (per target table)
- [ ] Every target column has a mapping row (mapped, constant, system, or explicit not-mapped reason)
- [ ] Every mandatory target column has a source, default, or derivation
- [ ] Primary and foreign keys: source keys identified, FK order of load defined
- [ ] Grain of source and target stated; row-multiplication risks checked
- [ ] Datatype, precision, length, and nullability compatibility checked
- [ ] Date formats, timezones, numeric scale and rounding stated
- [ ] Null, blank, default, and reject behaviour defined for each field
- [ ] Lookups reference named, versioned tables; no-match behaviour defined
- [ ] Rules are executable expressions, not prose
- [ ] Incremental logic and delete handling defined
- [ ] Sensitive fields flagged with masking/exclusion rule
- [ ] Every inferred field has evidence, confidence, and status
- [ ] No Low-confidence field flagged as ready to build

## 3. Source coverage checklist
- [ ] Every source field has a disposition: mapped, staged raw, not mapped (reason), unknown
- [ ] Unknown fields listed with business impact
- [ ] Legacy / filler / reserved columns profiled

## 4. Review gates
| Gate | Reviewer | Pass criteria |
|---|---|---|
| Meaning review | Data steward / SME | Inferred meanings confirmed or corrected; open questions answered or accepted as risk |
| Model fit review | Data modeler / architect | Grain, keys, SCD, missing attributes resolved |
| Buildability review | ETL lead | Rules unambiguous, parameterised, testable, pushdown and performance concerns raised |
| Data quality review | DQ engineer | DQ rules and thresholds defined for target |
| Compliance review | Privacy/security | PII handled and masked per policy |

## 5. Handoff checklist
- [ ] STM version frozen and signed off
- [ ] Test cases and expected values attached
- [ ] Reject codes, audit columns, naming standards attached
- [ ] Tool-specific notes attached (Informatica / Talend / Hop)
- [ ] Reconciliation queries and thresholds attached
- [ ] Change-request process agreed (who approves STM changes, how they are versioned)

## 6. Post-build checklist
- [ ] Reconciliation: row counts, sums/hashes, distinct keys, null rates match thresholds
- [ ] Field-level test cases passed
- [ ] Reject volumes within expected range, reasons reviewed
- [ ] Confirmed meanings and lineage published to the catalogue
- [ ] Open questions closed or carried as logged risks
