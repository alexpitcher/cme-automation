#!/bin/bash

cd "$(dirname "$0")/.."

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set defaults
N8N_HOST=${N8N_HOST:-127.0.0.1}
N8N_PORT=${N8N_PORT:-5678}
POSTGRES_USER=${POSTGRES_USER:-n8n}

echo "==================================="
echo "CME Automation Stack - Health Check"
echo "==================================="
echo ""

# Check if stack is running
if ! docker compose ps | grep -q "Up"; then
  echo "❌ Stack is not running. Start it with: ./scripts/up.sh"
  exit 1
fi

echo "✅ Docker Compose stack is running"
echo ""

# Test n8n
echo "Testing n8n (http://${N8N_HOST}:${N8N_PORT})..."
if curl -s -f -m 5 "http://${N8N_HOST}:${N8N_PORT}/healthz" > /dev/null 2>&1; then
  echo "✅ n8n is healthy (healthz endpoint)"
elif curl -s -f -m 5 "http://${N8N_HOST}:${N8N_PORT}" > /dev/null 2>&1; then
  echo "✅ n8n is responding (base endpoint)"
else
  echo "❌ n8n is not responding"
fi
echo ""

# Test cme-tools-api from inside docker network
echo "Testing cme-tools-api (internal)..."
HEALTH_OUTPUT=$(docker compose exec -T cme-tools-api sh -c 'wget -qO- http://127.0.0.1:8000/health 2>/dev/null || curl -sf http://127.0.0.1:8000/health 2>/dev/null || echo "ERROR"')

if [ "$HEALTH_OUTPUT" != "ERROR" ] && [ -n "$HEALTH_OUTPUT" ]; then
  echo "✅ cme-tools-api is healthy"
  echo "   Response: $HEALTH_OUTPUT"
else
  echo "⚠️  cme-tools-api health check inconclusive"
  echo "   The API may be running but health endpoint might differ"
  echo "   Check logs with: ./scripts/logs.sh"
fi
echo ""

# Check discord-bridge logs for connection status
echo "Checking discord-bridge status..."
BRIDGE_LOGS=$(docker compose logs --tail 20 discord-bridge 2>/dev/null)

if echo "$BRIDGE_LOGS" | grep -q "\[READY\]"; then
  BOT_TAG=$(echo "$BRIDGE_LOGS" | grep "\[READY\]" | tail -1 | sed 's/.*as //' | sed 's/\x1b\[[0-9;]*m//g')
  echo "✅ Discord bridge connected: $BOT_TAG"
elif echo "$BRIDGE_LOGS" | grep -q "ERROR"; then
  echo "❌ Discord bridge has errors (check logs)"
else
  echo "⚠️  Discord bridge status unknown (check logs)"
fi
echo ""

# Check postgres
echo "Checking postgres..."
if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER}" > /dev/null 2>&1; then
  echo "✅ Postgres is ready"
else
  echo "❌ Postgres is not ready"
fi
echo ""

echo "==================================="
echo "Health check complete!"
echo "==================================="
echo ""
echo "To view detailed logs: ./scripts/logs.sh"
echo ""
