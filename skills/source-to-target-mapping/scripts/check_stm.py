#!/usr/bin/env python3
"""Check an STM workbook against its inputs.

Usage:
    python check_stm.py <project_dir>
    python check_stm.py <project_dir> --stm <path to .xlsx>

<project_dir> contains inputs/ and outputs/. Needs: pip install openpyxl
Exit code 0 = no FAIL. WARN lines are reported but do not fail.
Rules are described in references/self-check.md and references/output-formats.md.
"""
import argparse
import csv
import glob
import os
import re
import sys

try:
    from openpyxl import load_workbook
except ImportError:
    sys.exit("openpyxl is required: pip install openpyxl")

SHEETS = ["0_Header", "1_Target_Mapping", "2_Source_Inventory", "3_Token_Glossary",
          "4_Lookups", "5_Open_Questions", "6_Tests_Recon"]
S1_COLS = ["STM Row ID", "Target table", "Target column", "Target business description", "Target datatype",
           "Nullable / key", "Source table.column(s)", "Source datatype", "Mapping type", "Transformation rule",
           "Join / filter / dedupe", "Null handling", "Default value", "Reject / warn handling",
           "Lookup / reference", "Data classification", "Masking / exclusion", "Evidence for meaning",
           "Confidence", "Open question", "Test case", "Status", "Comments"]
S2_COLS = ["Source field ID", "Table", "Column", "Decoded English name", "Description", "Vendor doc?", "Datatype",
           "Null?", "Key", "Profile summary", "Confidence", "Disposition"]
S5_COLS = ["ID", "Field(s)", "Question", "Evidence", "Proposed answer", "Owner", "Severity / impact"]
MAP_TYPES = {"DIRECT", "TRANSFORM", "LOOKUP", "DERIVE", "CONSTANT", "SYSTEM", "SPLIT/MERGE", "NOT MAPPED"}
CONF = {"High", "Medium", "Low"}
STATUS = {"Draft", "Inferred", "Confirmed", "Built", "Tested"}
SEVERITIES = ("BLOCKER", "High", "Gates production", "Medium", "Low")
DISPOSITIONS = ("Mapped:", "Not mapped:", "Staged raw only:", "Unknown:")
PLACEHOLDER = re.compile(r"\b(TODO|FIXME|lorem|\.\.\.|etc\.)", re.I)

results = []  # (level, check, message)


def add(level, check, msg):
    results.append((level, check, msg))


def rows_of(ws):
    data = list(ws.iter_rows(values_only=True))
    header = [("" if c is None else str(c)).strip() for c in data[0]] if data else []
    body = [["" if c is None else str(c).strip() for c in r] for r in data[1:] if any(c is not None for c in r)]
    return header, body


def parse_ddl(path):
    """Return {SCHEMA.TABLE: [(column, not_null_bool)]} from CREATE TABLE statements."""
    text = open(path, encoding="utf-8").read()
    tables = {}
    for m in re.finditer(r"CREATE\s+TABLE\s+([\w.]+)\s*\((.*?)\n\)\s*;", text, re.S | re.I):
        name = m.group(1).upper()
        cols = []
        for line in m.group(2).splitlines():
            line = line.split("--")[0].strip().rstrip(",")
            if not line or re.match(r"(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK)\b", line, re.I):
                continue
            cm = re.match(r"([A-Za-z_][\w]*)\s+([A-Za-z]+(?:\s*\([\d,\s]+\))?)(.*)", line)
            if cm:
                cols.append((cm.group(1).upper(), "NOT NULL" in cm.group(3).upper()))
        tables[name] = cols
    return tables


def expand_ids(text):
    """Expand 'STM-ADR-0002..0004' and lists into individual STM ids."""
    ids = set()
    for m in re.finditer(r"(STM-[A-Z]{3,4})-(\d{4})(?:\.\.(?:STM-[A-Z]{3,4}-)?(\d{4}))?", text):
        pre, a, b = m.group(1), int(m.group(2)), m.group(3)
        for n in range(a, int(b) + 1 if b else a + 1):
            ids.add(f"{pre}-{n:04d}")
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("project_dir")
    ap.add_argument("--stm")
    a = ap.parse_args()
    inp = os.path.join(a.project_dir, "inputs")
    out = os.path.join(a.project_dir, "outputs")
    stm = a.stm or (sorted(glob.glob(os.path.join(out, "01_STM_*.xlsx")) or [None])[0])
    if not stm or not os.path.exists(stm):
        sys.exit("FAIL: no outputs/01_STM_*.xlsx found")

    for f in ("02_ETL_Handoff_Notes.md", "03_Steward_Questions.md"):
        if not os.path.exists(os.path.join(out, f)):
            add("FAIL", "C01 files", f"missing outputs/{f}")

    wb = load_workbook(stm, data_only=True)
    names = wb.sheetnames
    if names != SHEETS:
        add("FAIL", "C02 sheets", f"sheet names/order are {names}, expected {SHEETS}")
        return finish()
    s0 = rows_of(wb["0_Header"])
    s1h, s1 = rows_of(wb["1_Target_Mapping"])
    s2h, s2 = rows_of(wb["2_Source_Inventory"])
    s5h, s5 = rows_of(wb["5_Open_Questions"])
    s6h, s6 = rows_of(wb["6_Tests_Recon"])
    s3h, s3 = rows_of(wb["3_Token_Glossary"])
    s4h, s4 = rows_of(wb["4_Lookups"])

    if s1h != S1_COLS:
        add("FAIL", "C03 columns", "sheet 1 header differs from the standard 23 columns")
        return finish()
    if s2h != S2_COLS:
        add("FAIL", "C03 columns", "sheet 2 header differs from the standard 12 columns")
    if s5h[:7] != S5_COLS:
        add("FAIL", "C03 columns", "sheet 5 first 7 columns differ from the standard")

    ix = {c: i for i, c in enumerate(S1_COLS)}
    blockers = {r[0] for r in s5 if r[6].startswith("BLOCKER")}

    # C04 row ids
    ids = [r[ix["STM Row ID"]] for r in s1]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        add("FAIL", "C04 row ids", f"duplicate ids: {sorted(dup)}")
    bad = [i for i in ids if not re.fullmatch(r"STM-[A-Z]{3,4}-\d{4}", i)]
    if bad:
        add("FAIL", "C04 row ids", f"bad id format: {bad[:5]}")

    # C05 DDL coverage
    ddl_path = os.path.join(inp, "03_target_model.sql")
    ddl = parse_ddl(ddl_path) if os.path.exists(ddl_path) else {}
    if not ddl:
        add("FAIL", "C05 ddl", "could not parse inputs/03_target_model.sql")
    want = {(t, c): nn for t, cols in ddl.items() for c, nn in cols}
    have = {}
    for r in s1:
        k = (r[ix["Target table"]].upper(), r[ix["Target column"]].upper())
        have[k] = have.get(k, 0) + 1
    for k in want:
        if k not in have:
            add("FAIL", "C05 coverage", f"target column {k[0]}.{k[1]} has no STM row")
    for k, n in have.items():
        if k not in want:
            add("FAIL", "C05 coverage", f"STM row for {k[0]}.{k[1]} is not in the DDL")
        elif n > 1:
            add("FAIL", "C05 coverage", f"{k[0]}.{k[1]} has {n} STM rows")

    # C06 allowed values, C07 mandatory not unmapped, C08 low vs confirmed
    for r in s1:
        rid = r[0]
        if r[ix["Mapping type"]] not in MAP_TYPES:
            add("FAIL", "C06 values", f"{rid}: mapping type '{r[ix['Mapping type']]}'")
        if r[ix["Confidence"]] not in CONF:
            add("FAIL", "C06 values", f"{rid}: confidence '{r[ix['Confidence']]}'")
        if r[ix["Status"]] not in STATUS:
            add("FAIL", "C06 values", f"{rid}: status '{r[ix['Status']]}'")
        k = (r[ix["Target table"]].upper(), r[ix["Target column"]].upper())
        if r[ix["Mapping type"]] == "NOT MAPPED" and want.get(k):
            cited = re.findall(r"Q-\d{3}", r[ix["Open question"]])
            blocker = any(q in blockers for q in cited)
            if not (blocker and r[ix["Status"]] == "Draft"):
                add("FAIL", "C07 mandatory", f"{rid}: NOT NULL column {k[1]} is NOT MAPPED without a BLOCKER question and status Draft")
        if r[ix["Confidence"]] == "Low" and r[ix["Status"]] in ("Confirmed", "Built", "Tested"):
            add("FAIL", "C08 low confirmed", f"{rid}: Low confidence but status {r[ix['Status']]}")
        if r[ix["Mapping type"]] not in ("NOT MAPPED", "CONSTANT", "SYSTEM") and len(r[ix["Transformation rule"]]) < 3:
            add("FAIL", "C09 rule", f"{rid}: empty transformation rule")
        if r[ix["Mapping type"]] in ("TRANSFORM", "DERIVE", "LOOKUP", "SPLIT/MERGE") and "=" not in r[ix["Transformation rule"]]:
            add("WARN", "C09 rule", f"{rid}: rule is not written as 'COLUMN = expression'")
        if r[ix["Confidence"]] in ("Medium", "Low") and not re.search(r"\(score \d+\)", r[ix["Evidence for meaning"]]):
            add("WARN", "C10 score", f"{rid}: Medium/Low row without '(score NN)' in the evidence text")
        if r[ix["Source table.column(s)"]].upper().startswith("NONE") and r[ix["Confidence"]] == "High":
            add("WARN", "C10 score", f"{rid}: no source but confidence High")

    # C11 source coverage
    inv_path = os.path.join(inp, "01_source_field_inventory.csv")
    inv = []
    if os.path.exists(inv_path):
        with open(inv_path, newline="", encoding="utf-8") as f:
            inv = [(r["table"].upper(), r["column"].upper()) for r in csv.DictReader(f)]
    s2k = {}
    for r in s2:
        k = (r[1].upper(), r[2].upper())
        s2k[k] = s2k.get(k, 0) + 1
    for k in inv:
        if k not in s2k:
            add("FAIL", "C11 source coverage", f"source column {k[0]}.{k[1]} missing from sheet 2")
    for k, n in s2k.items():
        if k not in set(inv):
            add("WARN", "C11 source coverage", f"sheet 2 has {k[0]}.{k[1]} that is not in the inventory file")
        if n > 1:
            add("FAIL", "C11 source coverage", f"{k[0]}.{k[1]} appears {n} times in sheet 2")

    # C12 dispositions
    idset = set(ids)
    for r in s2:
        d = r[11]
        if not d.startswith(DISPOSITIONS):
            add("FAIL", "C12 disposition", f"{r[0]}: disposition '{d[:40]}'")
        elif d.startswith("Mapped:"):
            refs = expand_ids(d)
            if not refs:
                add("FAIL", "C12 disposition", f"{r[0]}: 'Mapped' without STM ids")
            for ref in refs - idset:
                add("FAIL", "C12 disposition", f"{r[0]}: {ref} does not exist in sheet 1")

    # C13 cross references
    qids = {r[0] for r in s5}
    tids = {r[0] for r in s6}
    if len(qids) != len(s5):
        add("FAIL", "C13 questions", "duplicate question ids in sheet 5")
    for r in s5:
        if not r[6].startswith(SEVERITIES):
            add("FAIL", "C13 questions", f"{r[0]}: severity must start with one of {SEVERITIES}")
    for r in s1:
        for q in re.findall(r"Q-\d{3}", r[ix["Open question"]] + " " + r[ix["Comments"]]):
            if q not in qids:
                add("FAIL", "C13 questions", f"{r[0]} cites {q} which is not in sheet 5")
        for t in re.findall(r"(?:TC|RC)-[A-Z]*\d+", r[ix["Test case"]]):
            if t not in tids:
                add("FAIL", "C13 tests", f"{r[0]} cites {t} which is not in sheet 6")
        if r[ix["Mapping type"]] in ("TRANSFORM", "DERIVE", "LOOKUP") and not r[ix["Test case"]]:
            add("WARN", "C13 tests", f"{r[0]}: non-DIRECT row without a test case")
    q_md = os.path.join(out, "03_Steward_Questions.md")
    if os.path.exists(q_md):
        md = open(q_md, encoding="utf-8").read()
        for q in sorted(qids):
            if q not in md:
                add("FAIL", "C14 question file", f"{q} is in sheet 5 but not in 03_Steward_Questions.md")

    # C15 lookups
    codes_path = os.path.join(inp, "04_reference_codes.csv")
    if os.path.exists(codes_path):
        with open(codes_path, newline="", encoding="utf-8") as f:
            code_sets = {r["code_set"] for r in csv.DictReader(f)}
        s4sets = {r[0] for r in s4}
        for cs in code_sets - s4sets:
            add("FAIL", "C15 lookups", f"code set {cs} is missing from sheet 4")
        rules = " ".join(r[ix["Transformation rule"]] + " " + r[ix["Lookup / reference"]] for r in s1)
        for cs in code_sets:
            if cs not in rules:
                add("WARN", "C15 lookups", f"code set {cs} is not used by any rule")

    # C16 placeholders and numbers
    for sheet_name, (h, body) in (("1_Target_Mapping", (s1h, s1)), ("5_Open_Questions", (s5h, s5))):
        for r in body:
            for c in r:
                m = PLACEHOLDER.search(c)
                if m and "Rule-language" not in c:
                    add("WARN", "C16 placeholder", f"{sheet_name} {r[0]}: found '{m.group(0)}'")
                    break
    inv_text = open(inv_path, encoding="utf-8").read() if os.path.exists(inv_path) else ""
    for r in s2:
        prof = r[9]
        for num in re.findall(r"distinct (\d+)", prof):
            if f",{num}," not in inv_text:
                add("FAIL", "C17 invented numbers", f"{r[0]}: distinct {num} is not in the inventory file")

    # C18 header counts
    hdr = " ".join(" ".join(r) for r in s0[1])
    if not hdr.strip():
        add("FAIL", "C18 header", "sheet 0 is empty")
    items = [r[0] for r in s0[1]]
    for need in ("STM ID / version", "Load pattern", "Assumptions", "Status"):
        if need not in items:
            add("FAIL", "C18 header", f"sheet 0 lacks item '{need}'")

    finish(len(s1), len(want), len(s2), len(inv))


def finish(n_rows=0, n_target=0, n_src=0, n_inv=0):
    fails = [r for r in results if r[0] == "FAIL"]
    warns = [r for r in results if r[0] == "WARN"]
    for level, check, msg in results:
        print(f"{level}  {check}: {msg}")
    print(f"\nsheet1 rows {n_rows} / DDL columns {n_target}; sheet2 rows {n_src} / inventory rows {n_inv}")
    print(f"FAIL {len(fails)}  WARN {len(warns)}")
    print("RESULT: " + ("PASS" if not fails else "FAIL"))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
