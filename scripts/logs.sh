#!/bin/bash

cd "$(dirname "$0")/.."

echo "Following logs for: discord-bridge, n8n, cme-tools-api"
echo "Press Ctrl+C to stop"
echo ""

docker compose logs -f discord-bridge n8n cme-tools-api
