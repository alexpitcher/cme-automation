#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "==================================="
echo "CME Automation Stack - Startup"
echo "==================================="

# Create .env if it doesn't exist
if [ ! -f .env ]; then
  echo "⚠️  .env file not found. Creating from .env.example..."
  cp .env.example .env
  echo ""
  echo "❌ IMPORTANT: Edit .env file and set all CHANGE_ME values before continuing!"
  echo ""
  echo "Required configuration:"
  echo "  Secrets:"
  echo "    - POSTGRES_PASSWORD (strong database password)"
  echo "    - N8N_ENCRYPTION_KEY (generate with: openssl rand -hex 32)"
  echo "    - CME_ROUTER_PASSWORD (your router admin password)"
  echo "    - CME_API_KEY (generate with: openssl rand -hex 24)"
  echo "    - DISCORD_BOT_TOKEN (from Discord Developer Portal)"
  echo ""
  echo "  Router configuration:"
  echo "    - CME_ROUTER_HOST (router IP address)"
  echo "    - CME_ROUTER_USERNAME (router admin username)"
  echo "    - CME_ROUTER_NAME (router identifier)"
  echo ""
  echo "  Git backup configuration:"
  echo "    - CME_GIT_REMOTE_URL (backup repository URL)"
  echo "    - CME_GIT_BACKUP_FOLDER (folder in repository)"
  echo ""
  echo "After editing .env, run this script again."
  exit 1
fi

# Check if critical secrets are still default values
if grep -q "CHANGE_ME" .env; then
  echo "❌ ERROR: .env file contains CHANGE_ME placeholders!"
  echo ""
  echo "Please edit .env and replace all CHANGE_ME values with actual secrets."
  echo "See .env.example for guidance."
  exit 1
fi

echo "✅ .env file found and validated"

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Set defaults
N8N_HOST=${N8N_HOST:-127.0.0.1}
N8N_PORT=${N8N_PORT:-5678}
COMMAND_PREFIX=${COMMAND_PREFIX:-!cme}

echo ""
echo "Starting Docker Compose stack..."
docker compose up -d --build

echo ""
echo "==================================="
echo "✅ Stack started successfully!"
echo "==================================="
echo ""
echo "Configuration:"
echo "  - Router:         ${CME_ROUTER_HOST} (${CME_ROUTER_NAME})"
echo "  - n8n:            http://${N8N_HOST}:${N8N_PORT}"
echo "  - Command prefix: ${COMMAND_PREFIX}"
echo "  - Timezone:       ${TZ:-Europe/London}"
echo ""
echo "Services:"
echo "  - n8n:            Exposed on http://${N8N_HOST}:${N8N_PORT}"
echo "  - postgres:       Internal only"
echo "  - cme-tools-api:  Internal only"
echo "  - discord-bridge: Internal only"
echo ""
echo "Next steps:"
echo "  1. Access n8n at http://${N8N_HOST}:${N8N_PORT}"
echo "  2. Create your first workflow (see README.md)"
echo "  3. Invite Discord bot to your server"
echo "  4. Test with: ${COMMAND_PREFIX} help"
echo ""
echo "Useful commands:"
echo "  - View logs:   ./scripts/logs.sh"
echo "  - Health check: ./scripts/smoke.sh"
echo "  - Stop stack:  docker compose down"
echo ""
