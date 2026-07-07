# CARE Plugins Registry

A Docker image that builds and hosts all CARE frontend plugins under one domain, served by [Caddy](https://caddyserver.com).

```
https://your-registry-domain.com/<slug>/assets/remoteEntry.js
```

## Overview

Each CARE frontend plugin is a [Vite Module Federation](https://github.com/originjs/vite-plugin-federation) remote loaded by `care_fe` at runtime via a `remoteEntry.js` URL. All plugins are built inside a single Docker image and served as static files.

```
plugins.json
    |
    v
Docker multi-stage build
    |  git clone + npm ci + npm run build  (per plugin, parallel via BuildKit)
    |  generate manifest.json
    v
Caddy static file server
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

## Configuration

`REGISTRY_BASE_URL` is a Docker build argument. It sets the base URL written into `manifest.json`, which `care_fe` uses to load each plugin. It is not a runtime variable; changing it requires a new image build.

| Context                     | How to set it                                                                                             |
| --------------------------- | --------------------------------------------------------------------------------------------------------- |
| GitHub Actions (production) | Repository variable: **Settings > Secrets and variables > Actions > Variables**                           |
| Local dev                   | `REGISTRY_BASE_URL=http://localhost:8080 ./scripts/build-local.sh` (defaults to `http://localhost:8080`)  |
| Manual build                | `docker build --build-arg REGISTRY_BASE_URL=https://your-domain.com .`                                    |

## Deployment

### 1. Set the repository variable

In **Settings > Secrets and variables > Actions > Variables**, add:

| Name                | Value                              |
| ------------------- | ---------------------------------- |
| `REGISTRY_BASE_URL` | `https://your-registry-domain.com` |

`GITHUB_TOKEN` is provided automatically.

### 2. Push to main

The workflow builds and pushes a multi-platform Docker image to GHCR:

```
ghcr.io/areebahmeddd/care_plugins_registry:latest
ghcr.io/areebahmeddd/care_plugins_registry:sha-<short-sha>
```

### 3. Run on a server

```bash
curl -O https://raw.githubusercontent.com/areebahmeddd/care_plugins_registry/main/docker-compose.yml

docker compose pull
docker compose up -d
```

Verify: `http://your-server-ip/manifest.json`

## Connecting plugins to CARE

### Via `REACT_ENABLED_APPS`

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@your-registry-domain.com/care_excalidraw/assets/remoteEntry.js
```

No `https://` prefix. `care_fe` adds the protocol automatically.

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

1. Add an entry to `plugins.json`:

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

2. Add a matching build stage to the `Dockerfile`.

3. Validate locally:

```bash
npm run validate
```

4. Push to `main`. The plugin is available at:

```
https://your-registry-domain.com/care_my_plugin/assets/remoteEntry.js
```

## Pinning versions

`"ref": "main"` always builds the latest commit. To pin to a specific release:

```json
{ "slug": "care_excalidraw", "ref": "v1.2.0" }
```

## Local testing

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
