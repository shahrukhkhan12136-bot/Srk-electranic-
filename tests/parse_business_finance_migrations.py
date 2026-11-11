#!/usr/bin/env python3
"""Parse the top-level PostgreSQL statements in the business finance migrations.

pglast validates SQL statement syntax. PL/pgSQL function bodies are dollar-quoted
strings at this layer and still require runtime/function-level testing separately.
"""
from pathlib import Path
from pglast import parse_sql

FILES = (
    Path("supabase/migrations/20261110080448_srk_business_finance_dashboard.sql"),
    Path("supabase/migrations/20261111090000_harden_business_finance_dashboard.sql"),
)

for path in FILES:
    source = path.read_text(encoding="utf-8")
    statements = parse_sql(source)
    if not statements:
        raise SystemExit(f"FAIL: no SQL statements parsed in {path}")
    print(f"PASS: {path} ({len(statements)} top-level SQL statements)")

print("PASS: business finance migration SQL syntax parsed; PL/pgSQL bodies require database runtime tests.")
