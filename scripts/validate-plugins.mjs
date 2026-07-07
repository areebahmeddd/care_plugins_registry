#!/usr/bin/env node
// Validates plugins.json entries and checks that each repo is reachable.
// Usage: npm run validate

import { readFileSync } from "fs";
import { resolve } from "path";

const ROOT = resolve(import.meta.dirname, "..");
const registry = JSON.parse(
  readFileSync(resolve(ROOT, "plugins.json"), "utf8"),
);

let ok = true;

for (const plugin of registry.plugins) {
  const required = ["slug", "repo", "ref", "buildDir", "registrySlug"];
  for (const field of required) {
    if (!plugin[field]) {
      console.error(`[${plugin.slug ?? "?"}] Missing required field: ${field}`);
      ok = false;
    }
  }

  // Slug format: lowercase snake_case
  if (plugin.slug && !/^[a-z][a-z0-9_]*$/.test(plugin.slug)) {
    console.error(`[${plugin.slug}] slug must be snake_case alphanumeric`);
    ok = false;
  }

  // Repo format: org/repo
  if (plugin.repo && !/^[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+$/.test(plugin.repo)) {
    console.error(`[${plugin.slug}] repo must be in org/repo format`);
    ok = false;
  }

  if (!ok) continue;

  // HEAD request against GitHub; works for public repos without auth
  const url = `https://github.com/${plugin.repo}/tree/${plugin.ref}`;
  try {
    const res = await fetch(url, { method: "HEAD", redirect: "follow" });
    if (res.ok) {
      console.log(`${plugin.slug}  (${plugin.repo}@${plugin.ref})`);
    } else {
      console.error(`[${plugin.slug}] HTTP ${res.status}: ${url}`);
      console.error(`Private repos require a GitHub PAT in CI.`);
      ok = false;
    }
  } catch (err) {
    console.error(
      `[${plugin.slug}] Network error checking ${url}: ${err.message}`,
    );
    ok = false;
  }
}

if (!ok) {
  process.exitCode = 1;
} else {
  console.log(
    `\nAll ${registry.plugins.length} plugin(s) validated successfully.`,
  );
}
