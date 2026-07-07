#!/usr/bin/env node
// Writes merged-dist/manifest.json after all plugins are assembled.
// Usage: npm run manifest

import { readFileSync, writeFileSync, readdirSync, existsSync } from "fs";
import { resolve, join } from "path";

const ROOT = resolve(import.meta.dirname, "..");
const MERGED_DIST = join(ROOT, "merged-dist");
const PLUGINS_JSON = join(ROOT, "plugins.json");

const registry = JSON.parse(readFileSync(PLUGINS_JSON, "utf8"));

const pluginsBySlug = Object.fromEntries(
  registry.plugins.map((p) => [p.slug, p]),
);

// Only include slugs that have a built remoteEntry.js
const builtSlugs = readdirSync(MERGED_DIST).filter((entry) => {
  // Skip Cloudflare Pages reserved files
  if (entry.startsWith("_") || entry === "manifest.json") return false;
  const remoteEntry = join(MERGED_DIST, entry, "assets", "remoteEntry.js");
  return existsSync(remoteEntry);
});

const deployedAt = new Date().toISOString();

const registryBaseUrl =
  process.env.REGISTRY_BASE_URL || "http://localhost";

const manifest = {
  schemaVersion: 1,
  deployedAt,
  registryBaseUrl,

  plugins: builtSlugs.map((slug) => {
    const config = pluginsBySlug[slug] ?? {};
    const baseUrl = `${registryBaseUrl}/${slug}`;
    return {
      slug,
      name: config.name ?? slug,
      repo: config.repo ?? null,
      ref: config.ref ?? null,
      registrySlug: config.registrySlug ?? slug,
      remoteEntryUrl: `${baseUrl}/assets/remoteEntry.js`,
      appBaseUrl: baseUrl,
    };
  }),
};

const outputPath = join(MERGED_DIST, "manifest.json");
writeFileSync(outputPath, JSON.stringify(manifest, null, 2));

console.log(`manifest.json written with ${manifest.plugins.length} plugin(s):`);
for (const p of manifest.plugins) {
  console.log(`${p.slug}  ${p.remoteEntryUrl}`);
}
