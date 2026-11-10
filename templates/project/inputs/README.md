# Inputs to supply

| File | What it is |
|---|---|
| `01_source_field_inventory.csv` | One row per source column: `table,column,datatype,length,nullable,key,vendor_description,distinct_count,null_pct,min,max,top_values_or_pattern` (optional `blank_pct`). To generate it from SQL Server or Oracle see `skills/source-to-target-mapping/references/generate-source-field-inventory.md`. |
| `02_naming_conventions.md` | Part A = source conventions, Part B = target conventions (copy the template in this folder). |
| `03_target_model.sql` | `CREATE TABLE` statements of the target, with comments listing allowed values. |
| `04_reference_codes.csv` | `code_set,source_value,source_meaning,target_value,meaning_status` |
| `05_sample_<TABLE>.csv` | A few sample rows per source table (header = column names). |

Outputs are written to `../outputs/`. Exact formats: `skills/source-to-target-mapping/references/output-formats.md`.
