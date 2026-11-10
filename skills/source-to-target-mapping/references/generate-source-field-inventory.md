# Generating `01_source_field_inventory.csv` from SQL Server or Oracle

Use this when the user asks how to create the source field inventory (field list, column profile), or has a SQL Server or Oracle source and no inventory yet. Present the steps below, adapted to their schema and tables. Other databases (PostgreSQL, MySQL, Snowflake...) are not covered: tell the user, and offer to adapt the catalog queries (`information_schema.columns` exists on most).

Target file: `projects/<NAME>/inputs/01_source_field_inventory.csv`.
Columns in order: `table,column,datatype,length,nullable,key,vendor_description,distinct_count,null_pct,min,max,top_values_or_pattern` plus an optional last column `blank_pct`.

Status of the queries: written from product knowledge and reviewed, but they must be run once on a small table and compared with the data before trusting them on a large one.

## Overview (4 steps)
1. Run the STRUCTURE query -> save as `structure.csv`.
2. Run the PROFILE GENERATOR, then run the SQL it prints -> save as `profile.csv`.
3. Run the TOP-VALUES GENERATOR for the low-cardinality columns, run its SQL -> save as `top.csv`.
4. Merge the three with `scripts/assemble_inventory.py` -> `01_source_field_inventory.csv`.

Replace the placeholders: `<SCHEMA>` (Oracle owner or SQL Server schema) and the table list `('TABLE_A','TABLE_B')`.

## Step 1. Structure (instant; catalog views only)
Output columns must be named exactly: `table_name, column_name, datatype, length, nullable, key, vendor_description`.

### SQL Server
```sql
SELECT t.name AS table_name, c.name AS column_name, ty.name AS datatype,
       CASE WHEN ty.name IN ('decimal','numeric') THEN CONCAT(c.precision, ',', c.scale)
            WHEN ty.name IN ('char','varchar','binary','varbinary')
                 THEN CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS varchar(10)) END
            WHEN ty.name IN ('nchar','nvarchar')
                 THEN CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS varchar(10)) END
       END AS length,                                   -- characters for (n)char/(n)varchar; blank for dates, ints
       CASE c.is_nullable WHEN 1 THEN 'Y' ELSE 'N' END AS nullable,
       CASE WHEN pk.column_id IS NOT NULL THEN 'PK' END AS [key],
       CAST(ep.value AS nvarchar(500)) AS vendor_description
FROM sys.tables t
JOIN sys.schemas sc ON sc.schema_id = t.schema_id AND sc.name = '<SCHEMA>'
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types ty   ON ty.user_type_id = c.system_type_id          -- base type, also for alias types
LEFT JOIN (SELECT ic.object_id, ic.column_id
           FROM sys.index_columns ic
           JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
           WHERE i.is_primary_key = 1) pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
                                    AND ep.class = 1 AND ep.name = 'MS_Description'
WHERE t.name IN ('TABLE_A','TABLE_B')
ORDER BY t.name, c.column_id;
```
Notes: each column of a composite primary key gets `PK`. Foreign keys are not detected here: add `FK` by hand from `sys.foreign_key_columns` if needed.

### Oracle
```sql
SELECT c.table_name, c.column_name, c.data_type AS datatype,
       CASE WHEN c.data_type IN ('NUMBER','FLOAT') THEN
              CASE WHEN c.data_precision IS NULL THEN NULL
                   ELSE TO_CHAR(c.data_precision) ||
                        CASE WHEN c.data_scale IS NOT NULL AND c.data_scale <> 0 THEN ',' || c.data_scale END
              END
            WHEN c.data_type LIKE '%CHAR%' THEN TO_CHAR(c.char_length)
            WHEN c.data_type = 'RAW' THEN TO_CHAR(c.data_length)
       END AS length,                                   -- blank for DATE, TIMESTAMP, unconstrained NUMBER, LOBs
       c.nullable AS nullable,                          -- already Y or N
       CASE WHEN pk.column_name IS NOT NULL THEN 'PK' END AS key,
       cc.comments AS vendor_description
FROM all_tab_columns c
LEFT JOIN all_col_comments cc
       ON cc.owner = c.owner AND cc.table_name = c.table_name AND cc.column_name = c.column_name
LEFT JOIN (SELECT cols.owner, cols.table_name, cols.column_name
           FROM all_constraints con
           JOIN all_cons_columns cols ON cols.owner = con.owner AND cols.constraint_name = con.constraint_name
           WHERE con.constraint_type = 'P') pk
       ON pk.owner = c.owner AND pk.table_name = c.table_name AND pk.column_name = c.column_name
WHERE c.owner = '<SCHEMA>' AND c.table_name IN ('TABLE_A','TABLE_B')
ORDER BY c.table_name, c.column_id;
```
`vendor_description` is filled only where column comments exist. Blank = undocumented. That gap is what the mapping fills by inference.

## Step 2. Profile (generator query, then run what it prints)
The generator prints one `SELECT` per column. Run the printed SQL as one statement; it returns `table_name, column_name, distinct_count, null_pct, blank_pct, min_value, max_value`.

- `null_pct` = percent of rows that are NULL.
- `blank_pct` = percent of rows that are empty or spaces only (text columns only; 0 for others). SQL Server stores `''` and `NULL` differently; Oracle stores `''` as NULL, so on Oracle `blank_pct` counts only space-only values. Report both: sentinel and blank values distort reconciliation.
- Excluded types (they cannot be aggregated this way): SQL Server `text, ntext, image, xml, bit, geography, geometry, hierarchyid, sql_variant, timestamp`; Oracle `CLOB, NCLOB, BLOB, BFILE, LONG, LONG RAW, XMLTYPE`. Profile those by hand if needed.

### SQL Server generator (SQL Server 2017+ for `STRING_AGG`)
```sql
SELECT STRING_AGG(CAST(
  'SELECT ''' + t.name + ''' AS table_name, ''' + c.name + ''' AS column_name, '
  + 'COUNT(DISTINCT ' + x.q + ') AS distinct_count, '
  + 'CAST(100.0 * SUM(CASE WHEN ' + x.q + ' IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(5,1)) AS null_pct, '
  + CASE WHEN ty.name IN ('char','varchar','nchar','nvarchar')
         THEN 'CAST(100.0 * SUM(CASE WHEN LTRIM(RTRIM(' + x.q + ')) = '''' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(5,1))'
         ELSE 'CAST(0 AS decimal(5,1))' END + ' AS blank_pct, '
  + 'CAST(MIN(' + x.q + ') AS varchar(100)) AS min_value, CAST(MAX(' + x.q + ') AS varchar(100)) AS max_value '
  + 'FROM ' + QUOTENAME(sc.name) + '.' + QUOTENAME(t.name)
  AS nvarchar(max)), CHAR(10) + 'UNION ALL' + CHAR(10)) WITHIN GROUP (ORDER BY t.name, c.column_id)
FROM sys.tables t
JOIN sys.schemas sc ON sc.schema_id = t.schema_id AND sc.name = '<SCHEMA>'
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types ty   ON ty.user_type_id = c.system_type_id
CROSS APPLY (SELECT QUOTENAME(c.name) AS q) x
WHERE t.name IN ('TABLE_A','TABLE_B')
  AND ty.name NOT IN ('text','ntext','image','xml','bit','geography','geometry','hierarchyid','sql_variant','timestamp');
```
In SSMS the result may be cut at 65,535 characters: set Tools > Options > Query Results > Results to Grid > Maximum Characters Retrieved to 2,000,000 (or use Results to File).

### Oracle generator (one row per statement, so no 4,000-character `LISTAGG` limit)
```sql
SELECT 'SELECT ''' || c.table_name || ''' AS table_name, ''' || c.column_name || ''' AS column_name, '
    || 'COUNT(DISTINCT "' || c.column_name || '") AS distinct_count, '
    || 'ROUND(100 * SUM(CASE WHEN "' || c.column_name || '" IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1) AS null_pct, '
    || CASE WHEN c.data_type LIKE '%CHAR%'
            THEN 'ROUND(100 * SUM(CASE WHEN "' || c.column_name || '" IS NOT NULL AND TRIM("' || c.column_name
                 || '") IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1)'
            ELSE '0' END || ' AS blank_pct, '
    || CASE WHEN c.data_type = 'DATE' OR c.data_type LIKE 'TIMESTAMP%'
            THEN 'TO_CHAR(MIN("' || c.column_name || '"), ''YYYY-MM-DD HH24:MI:SS'') AS min_value, '
                 || 'TO_CHAR(MAX("' || c.column_name || '"), ''YYYY-MM-DD HH24:MI:SS'') AS max_value '
            ELSE 'TO_CHAR(MIN("' || c.column_name || '")) AS min_value, TO_CHAR(MAX("' || c.column_name || '")) AS max_value '
       END
    || 'FROM ' || c.owner || '."' || c.table_name || '"'
    || CASE WHEN ROW_NUMBER() OVER (ORDER BY c.table_name, c.column_id) = COUNT(*) OVER () THEN NULL
            ELSE CHR(10) || 'UNION ALL' END AS stmt
FROM all_tab_columns c
WHERE c.owner = '<SCHEMA>' AND c.table_name IN ('TABLE_A','TABLE_B')
  AND c.data_type NOT IN ('CLOB','NCLOB','BLOB','BFILE','LONG','LONG RAW','XMLTYPE')
ORDER BY c.table_name, c.column_id;
```
Copy all rows of `stmt` into a new query window (they form one `UNION ALL` statement) and run it.

### Large tables
If a table has more than about 100 million rows, profile a sample and say so in the file (distinct counts from a sample are estimates, not facts): SQL Server `FROM <table> TABLESAMPLE (10 PERCENT)`, Oracle `FROM <table> SAMPLE (10)`. Run on a read replica, off peak.

## Step 3. Top values (only low-cardinality columns)
Pick the columns with `distinct_count <= 50` from `profile.csv`. Edit the `IN (...)` list below with `TABLE.COLUMN` names (upper case), run the generator, then run the SQL it prints. Output: `table_name, column_name, value, cnt, pct`.

### SQL Server generator
```sql
SELECT STRING_AGG(CAST(
  'SELECT * FROM (SELECT TOP 5 ''' + t.name + ''' AS table_name, ''' + c.name + ''' AS column_name, '
  + 'CAST(' + x.q + ' AS varchar(100)) AS value, COUNT(*) AS cnt, '
  + 'CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,1)) AS pct '
  + 'FROM ' + QUOTENAME(sc.name) + '.' + QUOTENAME(t.name) + ' GROUP BY ' + x.q + ' ORDER BY COUNT(*) DESC) q_' + CAST(c.column_id AS varchar(10))
  AS nvarchar(max)), CHAR(10) + 'UNION ALL' + CHAR(10)) WITHIN GROUP (ORDER BY t.name, c.column_id)
FROM sys.tables t
JOIN sys.schemas sc ON sc.schema_id = t.schema_id AND sc.name = '<SCHEMA>'
JOIN sys.columns c  ON c.object_id = t.object_id
CROSS APPLY (SELECT QUOTENAME(c.name) AS q) x
WHERE UPPER(t.name + '.' + c.name) IN ('TABLE_A.COLUMN_X','TABLE_B.COLUMN_Y');
```
Note: `q_<id>` aliases are only unique within one table; if two tables have columns with the same `column_id`, they still run because each subquery is separate in the `UNION ALL`.

### Oracle generator
```sql
SELECT 'SELECT * FROM (SELECT ''' || c.table_name || ''' AS table_name, ''' || c.column_name || ''' AS column_name, '
    || 'TO_CHAR("' || c.column_name || '") AS value, COUNT(*) AS cnt, '
    || 'ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct '
    || 'FROM ' || c.owner || '."' || c.table_name || '" GROUP BY "' || c.column_name || '" ORDER BY COUNT(*) DESC) '
    || 'WHERE ROWNUM <= 5'
    || CASE WHEN ROW_NUMBER() OVER (ORDER BY c.table_name, c.column_id) = COUNT(*) OVER () THEN NULL
            ELSE CHR(10) || 'UNION ALL' END AS stmt
FROM all_tab_columns c
WHERE c.owner = '<SCHEMA>' AND c.table_name || '.' || c.column_name IN ('TABLE_A.COLUMN_X','TABLE_B.COLUMN_Y')
ORDER BY c.table_name, c.column_id;
```

## Step 4. Merge into the inventory file
Save the three results as CSV with a header row (SSMS: right-click the grid, Save Results As. SQL Developer: right-click, Export, CSV. SQLcl: `SET SQLFORMAT CSV`). Then:
```
python skills/source-to-target-mapping/scripts/assemble_inventory.py structure.csv profile.csv top.csv projects/<NAME>/inputs/01_source_field_inventory.csv
```
The script joins on `table_name, column_name`, writes `top_values_or_pattern` as `"A (84.0%); B (5.0%)"`, and leaves a column empty when it was not profiled. It needs only Python 3 (standard library).

If you cannot run Python: open `structure.csv` in a spreadsheet, add the profile columns with a lookup on `table_name & column_name`, build the top-values text by hand (`value (pct%)` joined with `; `), keep the 12 column names and order, and save as CSV UTF-8.

## Step 5. Patterns for columns not suited to top values
For free text or high-cardinality columns write a short pattern into `top_values_or_pattern`, for example `pattern 9{8}` (8 digits), `contains @ in 99.8%`, `free text; 3% upper-case only`. Compute such percentages with a query (for example `SUM(CASE WHEN col LIKE '%@%' THEN 1 ELSE 0 END)`); never guess them.

## Safety
- Run on a read replica or a representative extract, never as a heavy query on a busy production system.
- The inventory can reveal sensitive values (top values and min/max of names, emails, ids). Review it for PII before sharing it outside the project, and mask those two columns for PII fields.
- Never put credentials in the repository. If the user offers a connection, use it only in their own environment; otherwise ask them to paste the query results.
