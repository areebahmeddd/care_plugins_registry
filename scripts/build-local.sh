#!/usr/bin/env bash
# Build all (or selected) plugins locally and assemble merged-dist/.
#
# Usage:
#   ./scripts/build-local.sh                      # build all plugins
#   ./scripts/build-local.sh care_excalidraw      # build one plugin
#   ./scripts/build-local.sh "care_excalidraw,care_analytics"  # build subset
#
# After this runs:
#   docker build -t care-plugins-local .
#   docker run --rm -p 8080:80 care-plugins-local
#
# Or without Docker:
#   npx serve merged-dist -p 8080 --cors
#
# Then set in care_fe/.env:
#   REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@localhost:8080/care_excalidraw/assets/remoteEntry.js

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGED_DIST="$ROOT/merged-dist"
PLUGINS_JSON="$ROOT/plugins.json"
FILTER="${1:-}"
REGISTRY_BASE_URL="${REGISTRY_BASE_URL:-http://localhost:8080}"

# Require jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: sudo apt install jq"
  exit 1
fi

echo "=== CARE Plugins Registry — Local Build ==="
echo "Base URL : $REGISTRY_BASE_URL"
echo "Filter   : ${FILTER:-all}"
echo ""

# Clean and recreate merged-dist
rm -rf "$MERGED_DIST"
mkdir -p "$MERGED_DIST"

BUILT=0
FAILED=0

while IFS= read -r plugin; do
  SLUG=$(echo "$plugin" | jq -r '.slug')
  REPO=$(echo "$plugin" | jq -r '.repo')
  REF=$(echo "$plugin" | jq -r '.ref // "main"')
  BUILD_DIR=$(echo "$plugin" | jq -r '.buildDir // "dist"')

  # Apply filter if provided
  if [[ -n "$FILTER" ]]; then
    IFS=',' read -ra SLUGS <<< "$FILTER"
    MATCH=0
    for S in "${SLUGS[@]}"; do
      S="${S// /}"  # trim spaces
      [[ "$S" == "$SLUG" ]] && MATCH=1 && break
    done
    if [[ "$MATCH" -eq 0 ]]; then
      echo "Skipping $SLUG"
      continue
    fi
  fi

  echo "--- $SLUG ---"
  SRC="$ROOT/src/$SLUG"

  # Clone if not already present
  if [[ ! -d "$SRC/.git" ]]; then
    echo "Cloning $REPO @ $REF ..."
    git clone --depth=1 --branch="$REF" "https://github.com/$REPO.git" "$SRC"
  else
    echo "Source exists at src/$SLUG — skipping clone (delete the folder to re-clone)"
  fi

  # Install
  echo "Installing dependencies..."
  npm ci --prefix "$SRC" --silent

  # Build
  echo "Building..."
  npm run build --prefix "$SRC"

  # Validate
  ENTRY="$SRC/$BUILD_DIR/assets/remoteEntry.js"
  if [[ ! -f "$ENTRY" ]]; then
    echo "ERROR: remoteEntry.js not found at $ENTRY"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Assemble
  echo "Copying $SLUG/dist/ → merged-dist/$SLUG/"
  cp -r "$SRC/$BUILD_DIR/." "$MERGED_DIST/$SLUG/"
  echo "✓ $SLUG ($(du -sh "$MERGED_DIST/$SLUG" | cut -f1))"
  BUILT=$((BUILT + 1))
  echo ""

done < <(jq -c '.plugins[]' "$PLUGINS_JSON")

# Generate manifest.json
echo "Generating manifest.json (base: $REGISTRY_BASE_URL)..."
REGISTRY_BASE_URL="$REGISTRY_BASE_URL" node "$ROOT/scripts/generate-manifest.mjs"

echo ""
echo "=== Done: $BUILT built, $FAILED failed ==="
echo ""
echo "Next steps — pick one:"
echo ""
echo "  [Docker] Build image and run on port 8080:"
echo "    docker build -t care-plugins-local $ROOT"
echo "    docker run --rm -p 8080:80 care-plugins-local"
echo ""
echo "  [No Docker] Serve merged-dist directly (no Caddy headers):"
echo "    npx serve merged-dist -p 8080 --cors"
echo ""
echo "  Then update care_fe/.env:"
echo "    REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@localhost:8080/care_excalidraw/assets/remoteEntry.js"
