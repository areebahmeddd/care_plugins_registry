# CARE Plugins Registry

A single [Cloudflare Pages](https://pages.cloudflare.com) project that builds and serves all CARE frontend plugins under one domain.

```
https://care-plugins-registry.pages.dev/<slug>/assets/remoteEntry.js
```

## Overview

Each CARE frontend plugin is a [Vite Module Federation](https://github.com/originjs/vite-plugin-federation) remote that the `care_fe` host loads at runtime via a `remoteEntry.js` URL. Historically each plugin has been deployed to its own Cloudflare Pages project. This repository centralises that into a single deployment: one pipeline, one project, one domain.

```
plugins.json
    |
    v
GitHub Actions matrix  (one parallel job per plugin)
    |  git clone -> install -> npm run build -> upload artifact
    v
deploy job  (merges all artifacts, adds _headers and manifest.json)
    |
    v
Cloudflare Pages  (merged-dist/ deployed as static assets)
    merged-dist/
      care_excalidraw/
        assets/
          remoteEntry.js
          <hashed-chunks>.js
      care_ai_vision/
        assets/
          remoteEntry.js
      manifest.json
      _headers
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

### 1. Create the Cloudflare Pages project

```bash
npx wrangler pages project create care-plugins-registry
```

This registers the project name in your Cloudflare account. No Git integration in Cloudflare is required; the GitHub Actions workflow deploys via the API.

### 2. Add repository secrets and variables

In **Settings > Secrets and variables > Actions**:

| Name                            | Type     | Value                                              |
| ------------------------------- | -------- | -------------------------------------------------- |
| `CLOUDFLARE_API_TOKEN`          | Secret   | API token with _Cloudflare Pages: Edit_ permission |
| `CLOUDFLARE_ACCOUNT_ID`         | Secret   | Account ID from the Cloudflare dashboard URL       |
| `CLOUDFLARE_PAGES_PROJECT_NAME` | Variable | `care-plugins-registry` (or your custom name)      |

### 3. Push to main

The workflow reads `plugins.json`, builds all plugins in parallel, assembles the output directory, and deploys to Cloudflare Pages.

Check the deployment:

```
https://care-plugins-registry.pages.dev/manifest.json
```

## Connecting plugins to CARE

### Via the App Store UI

Set the **App base URL** to:

```
https://care-plugins-registry.pages.dev/<slug>
```

For example: `https://care-plugins-registry.pages.dev/care_excalidraw`

CARE computes the remoteEntry URL as `{appBaseUrl}/assets/remoteEntry.js`.

### Via `REACT_ENABLED_APPS`

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@https://care-plugins-registry.pages.dev/care_excalidraw/assets/remoteEntry.js
```

### Via the plug_config API

```json
{
  "slug": "care_excalidraw",
  "meta": {
    "url": "https://care-plugins-registry.pages.dev/care_excalidraw/assets/remoteEntry.js",
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

Merge to `main`. The plugin becomes available at:

```
https://care-plugins-registry.pages.dev/<slug>/assets/remoteEntry.js
```

## Pinning versions

`"ref": "main"` always builds the latest commit. For production, pin to a tag or SHA:

```json
{ "slug": "care_excalidraw", "ref": "v1.2.0" }
```

## Local testing

```bash
# Clone and build a plugin
git clone --depth=1 https://github.com/ohcnetwork/care_excalidraw_fe
cd care_excalidraw_fe && npm install && npm run build && cd ..

# Assemble and preview
mkdir -p merged-dist/care_excalidraw
cp -r care_excalidraw_fe/dist/. merged-dist/care_excalidraw/
cp _headers merged-dist/_headers
node scripts/generate-manifest.mjs
npx wrangler pages dev merged-dist --port 8788
```

Point a local CARE instance at it:

```env
REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@http://localhost:8788/care_excalidraw/assets/remoteEntry.js
```

## Triggering a single-plugin rebuild

```bash
gh workflow run deploy.yml --field plugin_filter=care_excalidraw
```

Leave `plugin_filter` empty to rebuild all plugins.
