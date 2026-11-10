#!/usr/bin/env python3
"""Merge structure, profile and top-value CSVs into 01_source_field_inventory.csv.

Usage:
    python assemble_inventory.py structure.csv profile.csv top.csv out.csv

structure.csv : table_name, column_name, datatype, length, nullable, key, vendor_description
profile.csv   : table_name, column_name, distinct_count, null_pct, blank_pct, min_value, max_value
top.csv       : table_name, column_name, value, cnt, pct          (may be missing or empty)
Only the Python standard library is needed. Column names are matched case-insensitively.
"""
import csv
import sys
from collections import defaultdict

HEADER = ["table", "column", "datatype", "length", "nullable", "key", "vendor_description",
          "distinct_count", "null_pct", "min", "max", "top_values_or_pattern", "blank_pct"]


def read(path):
    try:
        with open(path, newline="", encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f))
    except FileNotFoundError:
        return []
    return [{(k or "").strip().lower(): (v or "").strip() for k, v in r.items()} for r in rows]


def key(r):
    return (r.get("table_name", "").upper(), r.get("column_name", "").upper())


def fmt(num):
    try:
        x = float(num)
        return str(int(x)) if x == int(x) else str(x)
    except ValueError:
        return num


def main(structure, profile, top, out):
    s_rows, p_rows, t_rows = read(structure), read(profile), read(top)
    if not s_rows:
        sys.exit("structure.csv is empty or missing")
    prof = {key(r): r for r in p_rows}
    tops = defaultdict(list)
    for r in t_rows:
        tops[key(r)].append(r)
    missing = 0
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        for s in s_rows:
            k = key(s)
            p = prof.get(k)
            if p is None:
                missing += 1
                p = {}
            t = "; ".join(f"{r['value']} ({r['pct']}%)" for r in
                          sorted(tops.get(k, []), key=lambda r: -float(r.get("cnt") or 0)))
            w.writerow([s.get("table_name"), s.get("column_name"), s.get("datatype"), s.get("length"),
                        s.get("nullable"), s.get("key"), s.get("vendor_description"),
                        fmt(p.get("distinct_count", "")), fmt(p.get("null_pct", "")),
                        p.get("min_value", ""), p.get("max_value", ""), t, fmt(p.get("blank_pct", ""))])
    print(f"wrote {out}: {len(s_rows)} columns, {missing} without a profile row")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
