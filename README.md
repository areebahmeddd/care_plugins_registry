# CARE Plugins Registry

A single Docker image (served by [Caddy](https://caddyserver.com)) that builds and hosts all CARE frontend plugins under one domain.

```
https://your-registry-domain.com/<slug>/assets/remoteEntry.js
```

## Overview

Each CARE frontend plugin is a [Vite Module Federation](https://github.com/originjs/vite-plugin-federation) remote that `care_fe` loads at runtime via a `remoteEntry.js` URL. This registry centralises all plugins into a single deployment: one pipeline, one image, one domain.

```
plugins.json
    |
    v
GitHub Actions matrix  (one parallel job per plugin)
    |  git clone → npm ci → npm run build → upload artifact
    v
publish job  (merges all artifacts, generates manifest.json, docker build)
    |
    v
GHCR (ghcr.io/areebahmeddd/care_plugins_registry)
    |
    v
VPS / any Docker host
    docker compose pull && docker compose up -d
```

```
merged-dist/  (baked into the image at build time)
  care_excalidraw/
    assets/
      remoteEntry.js
      <hashed-chunks>.js
    locale/
      en.json
  care_ai_vision/
    assets/
      remoteEntry.js
  manifest.json
```

## Supported plugins

| Slug                      | Source repository                                                                      | Default ref |
| ------------------------- | -------------------------------------------------------------------------------------- | ----------- |
| `care_ai_vision`          | [care_ai_vision_fe](https://github.com/ohcnetwork/care_ai_vision_fe)                   | `main`      |
| `care_analytics`          | [care_analytics_fe](https://github.com/ohcnetwork/care_analytics_fe)                   | `master`    |
| `care_excalidraw`         | [care_excalidraw_fe](https://github.com/ohcnetwork/care_excalidraw_fe)                 | `main`      |
| `care_pretty_print`       | [care_pretty_print_fe](https://github.com/ohcnetwork/care_pretty_print_fe)             | `main`      |
| `care_system_diagnostics` | [care_system_diagnostics_fe](https://github.com/ohcnetwork/care_system_diagnostics_fe) | `main`      |

## Setup

### 1. Add the repository variable

In **Settings → Secrets and variables → Actions → Variables**:

| Name                | Value                                |
| ------------------- | ------------------------------------ |
| `REGISTRY_BASE_URL` | `https://your-registry-domain.com`   |

`GITHUB_TOKEN` is provided automatically — no extra secrets needed for GHCR.

### 2. Push to main

The workflow reads `plugins.json`, builds all plugins in parallel, assembles `merged-dist/`, generates `manifest.json`, then builds and pushes a multi-platform Docker image to GHCR:

```
ghcr.io/areebahmeddd/care_plugins_registry:latest
ghcr.io/areebahmeddd/care_plugins_registry:sha-<short-sha>
```

### 3. Run on a server

```bash
# Pull docker-compose.yml onto your server
curl -O https://raw.githubusercontent.com/areebahmeddd/care_plugins_registry/main/docker-compose.yml

docker compose pull
docker compose up -d
```

Verify:

```
http://your-server-ip/manifest.json
```

## Connecting plugins to CARE

### Via `REACT_ENABLED_APPS`

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@your-registry-domain.com/care_excalidraw/assets/remoteEntry.js
```

> Note: no `https://` prefix — `care_fe` adds the protocol automatically.

### Via the plug_config API

```json
{
  "slug": "care_excalidraw",
  "meta": {
    "url": "https://your-registry-domain.com/care_excalidraw/assets/remoteEntry.js",
    "name": "care_excalidraw"
  }
}
```

## Adding a plugin

Add an entry to `plugins.json`:

```json
{
  "slug": "care_my_plugin",
  "name": "CARE My Plugin",
  "repo": "myorg/care_my_plugin_fe",
  "ref": "main",
  "buildDir": "dist",
  "registrySlug": "care_my_plugin"
}
```

Validate the entry locally:

```bash
npm run validate
```

Merge to `main`. The plugin becomes available at:

```
https://your-registry-domain.com/<slug>/assets/remoteEntry.js
```

## Pinning versions

`"ref": "main"` always builds the latest commit. For production, pin to a tag or SHA:

```json
{ "slug": "care_excalidraw", "ref": "v1.2.0" }
```

## Local testing

```bash
# Build one plugin manually
git clone --depth=1 https://github.com/ohcnetwork/care_excalidraw_fe
cd care_excalidraw_fe && npm ci && npm run build && cd ..

# Assemble
mkdir -p merged-dist/care_excalidraw
cp -r care_excalidraw_fe/dist/. merged-dist/care_excalidraw/

# Generate manifest
REGISTRY_BASE_URL=http://localhost node scripts/generate-manifest.mjs

# Build and run the image
docker build -t care_plugins_registry .
docker run -p 80:80 care_plugins_registry
```

Point a local CARE instance at it:

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@localhost/care_excalidraw/assets/remoteEntry.js
```

## Triggering a single-plugin rebuild

```bash
gh workflow run deploy.yml --field plugin_filter=care_excalidraw
```

Leave `plugin_filter` empty to rebuild all plugins.
