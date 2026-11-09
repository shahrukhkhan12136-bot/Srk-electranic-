"""Parse project SQL migrations with PostgreSQL grammar via pglast.
This checks top-level SQL syntax only; PL/pgSQL function bodies are string literals,
so this does not execute or validate their procedural runtime behavior.
"""
from pathlib import Path
from pglast import parse_sql

paths = [
    Path("supabase/migrations/20261110030000_admin_direct_electrician_assignment.sql"),
    Path("supabase/migrations/20261110040000_customer_admin_complaints.sql"),
    Path("supabase/migrations/20261110050000_electrician_verification_documents.sql"),
    Path("supabase/migrations/20261110060000_admin_audit_log.sql"),
]
for path in paths:
    sql = path.read_text(encoding="utf-8")
    statements = parse_sql(sql)
    assert statements, f"No SQL statements parsed in {path}"
    print(f"PASS PostgreSQL parser accepted {path} ({len(statements)} SQL statements)")
print("Scope: top-level syntax parsing only; no PL/pgSQL execution, database schema validation, or runtime testing.")
