# ETL Developer Handoff: Informatica, Talend, Apache Hop

The STM rule is tool-neutral. This file shows how each rule type translates, what to hand each developer, and what to check. Names of components are from general knowledge; mark `[VERIFY]` against the installed version.

## What every developer receives
1. STM workbook (all sheets), version-stamped.
2. Rule-by-rule test cases with expected results.
3. Reject/default policy (codes, target error table layout).
4. Load pattern spec: watermark column, CDC rules, restart behaviour, batch/run date parameters.
5. Naming standards for mappings/jobs/pipelines, parameters, and connections.
6. Reconciliation queries and thresholds.
7. Open-question list and the fields marked Inferred/Low (do not build Low).

## Rule-type translation table
| STM type | Informatica (PowerCenter / IICS CDI) | Talend | Apache Hop |
|---|---|---|---|
| DIRECT | Expression or port link | `tMap` direct column link | Select Values / direct field pass-through |
| TRANSFORM (string/date/numeric) | Expression transformation (`TO_DATE`, `LTRIM/RTRIM`, `IIF`, `DECODE`) | `tMap` expression, or `tConvertType`, `StringHandling`, `TalendDate` routines | Calculator, String operations, Formula, or JavaScript/Java expression transform |
| LOOKUP | Lookup transformation (connected/unconnected; cached) | `tMap` lookup flow (join model, match mode) or `tDBInput` as lookup | Stream Lookup, Database Lookup, or Merge Join with sorted inputs |
| DERIVE / conditional | Expression with `IIF`/`DECODE`; Router for branching | `tMap` expression filters and multiple outputs; `tReplicate` | Filter Rows, Switch/Case, Formula |
| CONSTANT / SYSTEM | Expression with parameter/variable (`$$RUN_DT`, `SYSTIMESTAMP`); Sequence Generator | Context variables, `tMap` constants, `tJava` for key generation | Add Constants, Get System Info, Add Sequence; pipeline parameters/variables |
| Aggregate | Aggregator | `tAggregateRow` | Group By / Memory Group By |
| Dedupe / survivorship | Sorter + Aggregator/Rank, or Rank/Router logic; MDM if matching needed | `tUniqRow`, `tMap`, Talend DQ match components | Unique Rows, Sort Rows, Merge Rows (diff) |
| Join | Joiner (sorted input recommended) | `tMap` or `tJoin` | Merge Join, Stream Lookup |
| SCD Type 2 | Lookup + Update Strategy, or IICS SCD template `[VERIFY]` | `tMap` pattern, or SCD components `[VERIFY edition]` | Dimension Lookup/Update transform |
| Reject handling | Router to reject target; session error log | `tMap` reject output, `tLogCatcher`/`tDie` | Error handling hop on transform; Write to Log |
| Pushdown / set-based | Pushdown optimisation `[VERIFY connector support]` | ELT components (`tELT*`) or SQL in `tDBRow` | Execute SQL scripts / Table Input with SQL |

## Informatica notes
- Provide each mapping with: source qualifier SQL (filters and joins), port list with datatypes, expression logic per target port, lookup definitions (condition, return port, no-match default), router groups and update strategy flags.
- Parameterise: source/target connections, run date, watermark values (parameter files or IICS in-out parameters).
- Datatype alignment: check precision/scale on decimal ports; date format strings.
- Ask for session or taskflow design: commit interval, error threshold, restart/recovery approach. See `informatica-powercenter`, `informatica-iics`.

## Talend notes
- Provide a job design: parent job calling child jobs (`tRunJob`), with context variables per environment (never hard-coded connections).
- Specify `tMap` details: lookup join keys, "match model" (unique/first/all), "inner join" reject, expression for each output column, null handling (`Relational.ISNULL`) `[VERIFY]`.
- Schema discipline: define metadata schemas once and reuse (repository metadata) to avoid per-component drift.
- Logging/error: standard `tLogCatcher`, `tStatCatcher` pattern; reject files or tables with the STM reject code. See `talend-data-integration`.
- Open Studio status and edition availability of components `[VERIFY]`.

## Apache Hop notes
- Hop splits **pipelines** (data flow, `.hpl`) and **workflows** (orchestration, `.hwf`); give the developer a pipeline per target table plus one workflow per subject area.
- Use **projects and environments** with variables (`${PROJECT_HOME}`, connection variables) for environment config; keep metadata in version control.
- Provide: transform sequence per rule, field names/types at each hop, and lookup source details. Hop is stream-based; note sort requirements for Merge Join and memory sizing for Stream Lookup.
- Execution options (local, Spark/Flink/Dataflow via Beam, Hop Server) depend on volume; state expected volumes in the handoff. `[VERIFY version-specific features]`
- Test with Hop unit test / dataset metadata `[VERIFY]` or use the STM test cases as input/golden datasets.

## Cross-tool conventions (set once, apply everywhere)
- Standard audit columns: `SRC_SYSTEM_CD`, `LOAD_TS`, `BATCH_ID`, `ROW_HASH`, `DELETE_FLG`.
- Standard reject table: `BATCH_ID, SRC_TABLE, SRC_KEY, FIELD, REJECT_CODE, REJECT_MESSAGE, RAW_VALUE, LOAD_TS`.
- Standard reject codes (example): R01 mandatory null, R02 invalid code, R03 invalid date, R04 type/length overflow, R05 duplicate key, R06 referential failure.
- Idempotency: every load rerunnable for the same batch without duplicates (delete-insert by batch or merge on business key).
- Date and timezone convention: store UTC unless the STM says otherwise; state the source timezone per field.

## Metadata-driven option
If the mapping count is large (hundreds of tables), consider generating mappings from STM metadata (tables of source/target/rule) instead of hand-building. Recommend only after the first manual wave proves the rule patterns; decision belongs to `data-integration-architect`.
