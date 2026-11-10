# Generating `01_source_field_inventory.csv` from SQL Server or Oracle

Use this when the user asks how to create the source field inventory / field list / column profile file, or has a SQL Server or Oracle source and no inventory yet. Present the steps below to the user (adapt table and schema names to their project).

Target file: `projects/<NAME>/inputs/01_source_field_inventory.csv`
Columns, in order: `table,column,datatype,length,nullable,key,vendor_description,distinct_count,null_pct,min,max,top_values_or_pattern`

Fastest route: build it from the catalog views (structure), add a generated profiling query (statistics), join the two on `table, column`, export as CSV.

## Step 1: Structure columns (instant)
Gives `table, column, datatype, length, nullable, key, vendor_description`.

### SQL Server
```sql
SELECT t.name AS [table], c.name AS [column], ty.name AS datatype,
       CASE WHEN ty.name IN ('decimal','numeric') THEN CONCAT(c.precision,',',c.scale)
            WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS varchar) END AS length,
       CASE c.is_nullable WHEN 1 THEN 'Y' ELSE 'N' END AS nullable,
       CASE WHEN pk.column_id IS NOT NULL THEN 'PK' END AS [key],
       CAST(ep.value AS nvarchar(500)) AS vendor_description
FROM sys.tables t
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types ty   ON ty.user_type_id = c.user_type_id
LEFT JOIN (SELECT ic.object_id, ic.column_id FROM sys.index_columns ic
           JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
           WHERE i.is_primary_key = 1) pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
                                    AND ep.name = 'MS_Description'
WHERE t.name IN ('MSG_HDR','MSG_RCPT','MBX_MST')   -- replace with the project's tables
ORDER BY t.name, c.column_id;
```
Note: `max_length` is in bytes (double the character length for `nvarchar`).

### Oracle
```sql
SELECT c.table_name AS "table", c.column_name AS "column", c.data_type AS datatype,
       NVL(TO_CHAR(c.data_precision || CASE WHEN c.data_scale IS NOT NULL THEN ',' || c.data_scale END),
           TO_CHAR(c.char_length)) AS length,
       c.nullable AS nullable,
       CASE WHEN pk.column_name IS NOT NULL THEN 'PK' END AS key,
       cc.comments AS vendor_description
FROM all_tab_columns c
LEFT JOIN all_col_comments cc ON cc.owner = c.owner AND cc.table_name = c.table_name AND cc.column_name = c.column_name
LEFT JOIN (SELECT cols.owner, cols.table_name, cols.column_name
           FROM all_constraints con JOIN all_cons_columns cols
             ON cols.owner = con.owner AND cols.constraint_name = con.constraint_name
           WHERE con.constraint_type = 'P') pk
  ON pk.owner = c.owner AND pk.table_name = c.table_name AND pk.column_name = c.column_name
WHERE c.owner = 'MAIL02' AND c.table_name IN ('MSG_HDR','MSG_RCPT','MBX_MST')   -- replace schema/tables
ORDER BY c.table_name, c.column_id;
```
`vendor_description` is filled only where column comments exist. Blanks are the undocumented fields the mapping skill infers.

## Step 2: Profiling columns (generate the SQL, do not hand-write it)
Gives `distinct_count, null_pct, min, max`. Write a query that outputs one `SELECT` per column, copy its output, run it.

### SQL Server generator
```sql
SELECT STRING_AGG(CAST(
 'SELECT ''' + t.name + ''' AS [table], ''' + c.name + ''' AS [column], ' +
 'COUNT(DISTINCT [' + c.name + ']) AS distinct_count, ' +
 'ROUND(100.0*SUM(CASE WHEN [' + c.name + '] IS NULL THEN 1 ELSE 0 END)/COUNT(*),1) AS null_pct, ' +
 'CAST(MIN([' + c.name + ']) AS varchar(100)) AS [min], CAST(MAX([' + c.name + ']) AS varchar(100)) AS [max] ' +
 'FROM [' + t.name + ']' AS nvarchar(max)), ' UNION ALL ')
FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name IN ('MSG_HDR','MSG_RCPT','MBX_MST');
```
Gotchas: `MIN/MAX` fail on `text`, `ntext`, `image`, `xml` and `bit` columns, so exclude those types in the generator's WHERE clause.

### Oracle generator
Same idea with `LISTAGG(... , ' UNION ALL ') WITHIN GROUP (ORDER BY ...)` over `all_tab_columns`, using `TO_CHAR(MIN(col))` and `TO_CHAR(MAX(col))`. Exclude LOB columns. `LISTAGG` output over 4000 characters needs `XMLAGG` or splitting by table.

### `top_values_or_pattern`
For columns with fewer than about 50 distinct values, run `SELECT col, COUNT(*) FROM tbl GROUP BY col ORDER BY COUNT(*) DESC` and keep the top 3 to 5 as `value (pct%)`. For free-text columns, record a pattern note instead (for example `pattern 9{8}`, `contains @ in 99.8%`).

## Step 3: Join and export
1. Join the Step 1 and Step 2 results on `table, column`.
2. Export as CSV: SSMS (results grid, right-click, Save Results As), SQL Developer (right-click grid, Export, CSV), or command line (`sqlcmd -s"," -W -o out.csv`, or `SET MARKUP CSV ON` in SQLcl).
3. Save as `projects/<NAME>/inputs/01_source_field_inventory.csv` with the column order above.

## Safety and offers
- Profile on a read replica or representative sample, not production. Use `TABLESAMPLE` (SQL Server) or `SAMPLE(10)` (Oracle) for huge tables, and note in the file that distinct counts from a sample are estimates.
- Offer to do it for the user: they can paste the catalog output or profile results, or provide a connection, and the skill assembles the CSV (joins, top-values pass). Never put credentials into the repo.
