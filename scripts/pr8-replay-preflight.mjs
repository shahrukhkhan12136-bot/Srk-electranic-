#!/usr/bin/env node
/**
 * PR #8 replay preflight: static inventory only.
 * This script NEVER opens a database connection and NEVER applies SQL.
 */
import { readdir, access } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const migrationDir = path.join(root, "supabase", "migrations");
const testDir = path.join(root, "supabase", "tests", "database");

async function sqlFiles(dir) {
  try {
    const entries = await readdir(dir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".sql"))
      .map((entry) => entry.name)
      .sort();
  } catch {
    return [];
  }
}

const migrations = await sqlFiles(migrationDir);
const pgTapTests = await sqlFiles(testDir);
const parsed = migrations.map((name) => ({
  name,
  version: name.match(/^(\d{14})/)?.[1] ?? null,
}));
const malformed = parsed.filter((item) => !item.version);
const versions = new Map();
for (const item of parsed) {
  if (!item.version) continue;
  const names = versions.get(item.version) ?? [];
  names.push(item.name);
  versions.set(item.version, names);
}
const duplicateVersions = [...versions.entries()]
  .filter(([, names]) => names.length > 1)
  .map(([version, names]) => ({ version, names }));

let hasConfig = true;
try {
  await access(path.join(root, "supabase", "config.toml"));
} catch {
  hasConfig = false;
}

console.log("PR #8 PostgreSQL replay preflight (static only)");
console.log(`Migration SQL files: ${migrations.length}`);
console.log(`pgTAP SQL files: ${pgTapTests.length}`);
console.log(`supabase/config.toml present: ${hasConfig ? "yes" : "NO"}`);
console.log(`Malformed/non-14-digit migration filenames: ${malformed.length}`);
for (const item of malformed) console.log(`  BLOCKER: ${item.name}`);
console.log(`Duplicate 14-digit migration versions: ${duplicateVersions.length}`);
for (const item of duplicateVersions) {
  console.log(`  BLOCKER: ${item.version}: ${item.names.join(", ")}`);
}

const blockers = [];
if (malformed.length) blockers.push("migration filenames need approved history reconciliation");
if (duplicateVersions.length) blockers.push("duplicate migration versions exist");
if (!hasConfig) blockers.push("Supabase local project config is missing");
if (!migrations.length) blockers.push("migration directory is empty");

if (blockers.length) {
  console.error("\nRESULT: BLOCKED — no SQL was executed.");
  for (const blocker of blockers) console.error(`- ${blocker}`);
  process.exitCode = 2;
} else {
  console.log("\nRESULT: STATIC PREFLIGHT CLEAR — runtime replay is still required.");
}
