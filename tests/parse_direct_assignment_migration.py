"""Parse the direct-assignment migration with PostgreSQL's grammar via pglast.
This checks SQL syntax only; it does not execute the migration or validate runtime behavior.
"""
from pathlib import Path
from pglast import parse_sql

path = Path("supabase/migrations/20261110030000_admin_direct_electrician_assignment.sql")
sql = path.read_text(encoding="utf-8")
statements = parse_sql(sql)
assert len(statements) >= 4, f"Expected function plus ACL statements, got {len(statements)}"
print(f"PASS PostgreSQL parser accepted {path} ({len(statements)} SQL statements)")
print("Scope: syntax parsing only; no database execution or schema/runtime validation.")
