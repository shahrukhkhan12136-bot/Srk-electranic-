import { copyFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const project = path.resolve(here, "..");
const repo = path.resolve(project, "../../..");
const web = path.join(project, "www");
await mkdir(path.join(web, "assets"), { recursive: true });
await copyFile(path.join(repo, "srk-config.js"), path.join(web, "srk-config.js"));
await copyFile(
  path.join(repo, "assets", "founder-shahrukh-khan.webp"),
  path.join(web, "assets", "founder-shahrukh-khan.webp")
);
console.log("Prepared isolated Customer POC web assets.");
