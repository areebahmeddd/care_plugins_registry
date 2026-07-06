# CARE Plugins Registry

A Docker image that builds and hosts all CARE frontend plugins under one domain, served by [Caddy](https://caddyserver.com).

```
https://your-registry-domain.com/<slug>/assets/remoteEntry.js
```

## Overview

Each CARE frontend plugin is a [Vite Module Federation](https://github.com/originjs/vite-plugin-federation) remote that `care_fe` loads at runtime via a `remoteEntry.js` URL. This registry builds all plugins inside a single Docker image and serves them from one domain.

```
plugins.json
    |
    v
Docker multi-stage build  (all plugin builds run in parallel via BuildKit)
    |  git clone + npm ci + npm run build  (per plugin, inside Docker)
    |  generate manifest.json
    v
Caddy static file server  (baked into the final image)
    |
    v
GHCR (ghcr.io/areebahmeddd/care_plugins_registry)
    |
    v
VPS / any Docker host
    docker compose pull && docker compose up -d
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

In **Settings > Secrets and variables > Actions > Variables**:

| Name                | Value                              |
| ------------------- | ---------------------------------- |
| `REGISTRY_BASE_URL` | `https://your-registry-domain.com` |

`GITHUB_TOKEN` is provided automatically. No extra secrets are needed for GHCR.

### 2. Push to main

The workflow builds a multi-platform Docker image with all plugins baked in and pushes it to GHCR:

```
ghcr.io/areebahmeddd/care_plugins_registry:latest
ghcr.io/areebahmeddd/care_plugins_registry:sha-<short-sha>
```

`REGISTRY_BASE_URL` is passed as a build argument and baked into `manifest.json` at build time.

### 3. Run on a server

```bash
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

Note: no `https://` prefix. `care_fe` adds the protocol automatically.

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

Add a corresponding build stage to the `Dockerfile` following the same pattern as the existing stages.

Validate the entry locally:

```bash
npm run validate
```

Push to `main`. The plugin becomes available at:

```
https://your-registry-domain.com/care_my_plugin/assets/remoteEntry.js
```

## Pinning versions

`"ref": "main"` always builds the latest commit. For production, pin to a tag or SHA:

```json
{ "slug": "care_excalidraw", "ref": "v1.2.0" }
```

## Local testing

The Dockerfile is self-contained. Pass `REGISTRY_BASE_URL` as a build argument to set the base URL baked into `manifest.json`.

```bash
./scripts/build-local.sh
# or manually:
docker build --build-arg REGISTRY_BASE_URL=http://localhost:8080 --tag care-plugins-local .
docker run --rm -p 8080:80 care-plugins-local
```

Set in `care_fe/.env`:

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@localhost:8080/care_excalidraw/assets/remoteEntry.js
```

The Caddy config does not change between environments. Only `manifest.json` content differs based on the `REGISTRY_BASE_URL` used at build time.
