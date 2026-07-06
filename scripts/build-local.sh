#!/usr/bin/env bash
# Build the plugin registry image locally.
#
# Usage:
#   ./scripts/build-local.sh
#
# The Dockerfile handles everything: git clone, npm ci, npm run build,
# manifest generation, and packaging into Caddy.
#
# Then run:
#   docker run --rm -p 8080:80 care-plugins-local
#
# And set in care_fe/.env:
#   REACT_ENABLED_APPS=ohcnetwork/care_excalidraw_fe@localhost:8080/care_excalidraw/assets/remoteEntry.js

set -euo pipefail

REGISTRY_BASE_URL="${REGISTRY_BASE_URL:-http://localhost:8080}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Building care-plugins-local (REGISTRY_BASE_URL=${REGISTRY_BASE_URL})"

docker build \
  --build-arg "REGISTRY_BASE_URL=${REGISTRY_BASE_URL}" \
  --tag care-plugins-local \
  "$ROOT"

echo ""
echo "Done. Run:"
echo "  docker run --rm -p 8080:80 care-plugins-local"
