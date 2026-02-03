# Changes - Generic Configuration Update

## Summary

The docker-compose stack has been updated to be fully generic and configurable via environment variables. All hardcoded values (IP addresses, usernames, URLs, etc.) have been moved to `.env`.

## What Changed

### 1. docker-compose.yml
All hardcoded values replaced with environment variables:

**Before (hardcoded):**
- Router IP: `10.20.102.11`
- Router username: `admin`
- Router name: `a14-con`
- Git URL: `https://git.int.a14.io/a14/a14-cfg.git`
- Git folder: `a14-con`
- Timezone: `Europe/London`
- n8n binding: `127.0.0.1:5678`

**After (configurable via .env):**
- `${CME_ROUTER_HOST}` - Router IP address
- `${CME_ROUTER_USERNAME}` - Router username
- `${CME_ROUTER_NAME}` - Router identifier
- `${CME_GIT_REMOTE_URL}` - Git repository URL
- `${CME_GIT_BACKUP_FOLDER}` - Git backup folder
- `${TZ:-Europe/London}` - Timezone with default
- `${N8N_HOST:-127.0.0.1}:${N8N_PORT:-5678}` - n8n binding with defaults

### 2. .env.example
Expanded with all new variables organized into sections:
- Timezone configuration
- Postgres database configuration
- n8n configuration (including host/port binding)
- Cisco CME router configuration
- CME Tools API configuration
- Git backup configuration
- Discord bot configuration

All variables include descriptions and examples.

### 3. README.md
Updated documentation:
- Environment variables table expanded with all new options
- Prerequisites section made generic (removed specific IPs/URLs)
- Architecture diagram made generic
- Added "Customization" section explaining all configurable options
- "Environment Details" renamed to "Customization"

### 4. scripts/up.sh
- Now loads and displays configured values on startup
- Shows router host, n8n URL, command prefix, timezone
- Updated error messages to list all required configuration

### 5. scripts/smoke.sh
- Now loads .env and uses configured values
- Health checks use `${N8N_HOST}:${N8N_PORT}` instead of hardcoded
- Postgres check uses `${POSTGRES_USER}` from env

## New Environment Variables

### Required (must be set):
- `CME_ROUTER_HOST` - Your router's IP address
- `CME_ROUTER_USERNAME` - Your router's admin username
- `CME_ROUTER_NAME` - Identifier for your router
- `CME_GIT_REMOTE_URL` - Your backup repository URL
- `CME_GIT_BACKUP_FOLDER` - Folder name in repository

### Optional (with sensible defaults):
- `TZ` (default: `Europe/London`)
- `N8N_HOST` (default: `127.0.0.1`)
- `N8N_PORT` (default: `5678`)
- `N8N_WEBHOOK_URL` (default: `http://127.0.0.1:5678/`)
- `N8N_INTERNAL_WEBHOOK_URL` (default: `http://n8n:5678/webhook/cme-discord`)
- `CME_SESSION_IDLE_TIMEOUT_SECONDS` (default: `30`)
- `CME_GIT_BRANCH` (default: `main`)
- `COMMAND_PREFIX` (default: `!cme`)
- And more...

## Benefits

1. **Reusability**: Stack can be deployed in different environments by changing .env
2. **Flexibility**: Easy to customize ports, IPs, URLs without editing compose file
3. **Security**: Keeps environment-specific details in .env (not committed to git)
4. **Documentation**: All options are documented in .env.example
5. **Maintainability**: Easier to update and manage configuration

## Migration from Old Version

If you had the old version with hardcoded values:

1. Copy your existing `.env` file as backup
2. Copy `.env.example` to `.env`
3. Add the new required variables:
   ```bash
   CME_ROUTER_HOST=10.20.102.11
   CME_ROUTER_USERNAME=admin
   CME_ROUTER_NAME=a14-con
   CME_GIT_REMOTE_URL=https://git.int.a14.io/a14/a14-cfg.git
   CME_GIT_BACKUP_FOLDER=a14-con
   ```
4. Copy your existing secret values from backup
5. Review optional variables and customize if needed
6. Run `./scripts/up.sh`

## Testing

After updating:
1. Validate YAML: `python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))"`
2. Check config: `docker compose config` (requires Docker installed)
3. Start stack: `./scripts/up.sh`
4. Run health checks: `./scripts/smoke.sh`
