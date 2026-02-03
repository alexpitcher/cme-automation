# CME Automation Stack

LAN-only automation stack for controlling Cisco CME Tools API via n8n, triggered by Discord bot commands.

## What This Stack Does

This system allows you to manage your Cisco CME router configuration through Discord commands:

1. **Discord Bot** listens for messages starting with `!cme` in your Discord server
2. **Discord Bridge** forwards these commands to an internal n8n webhook
3. **n8n Workflow** processes the command, optionally uses AI (Gemini) to parse intent
4. **CME Tools API** executes the configuration changes on your Cisco router
5. **Git Backups** are automatically pushed to your internal Git repository
6. **Response** is sent back to Discord with the result

## Architecture

```
Discord (Cloud)
    ↓ (outbound connection)
Discord Bridge Container
    ↓ (internal network)
n8n Container (bound to 127.0.0.1:5678 by default)
    ↓ (internal network)
CME Tools API Container
    ↓ (LAN)
Cisco CME Router (your router IP)
    ↓ (backup pushes)
Git Repository (your backup repo)
```

**Security Notes:**
- n8n is bound to 127.0.0.1 only (not exposed to LAN/Internet)
- All inter-service communication happens on internal Docker network
- Discord bot uses outbound connection only (no inbound ports)
- API key required for CME Tools API access
- Optional guild/channel restrictions for Discord bot

## Prerequisites

- Linux VM with Docker and Docker Compose installed
- Discord bot token (see setup instructions below)
- Access to your Cisco CME router on the LAN
- Git repository for configuration backups (optional but recommended)

## Quick Start

### 1. Configure Environment Variables

Copy the example environment file and edit it:

```bash
cp .env.example .env
nano .env  # or vim, vi, etc.
```

**Required Variables:**

| Variable | Description | How to Generate |
|----------|-------------|-----------------|
| `POSTGRES_PASSWORD` | Database password | Strong random password |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | `openssl rand -hex 32` |
| `CME_ROUTER_HOST` | Router IP address | Your router's LAN IP |
| `CME_ROUTER_USERNAME` | Router admin username | Your router username |
| `CME_ROUTER_PASSWORD` | Router admin password | Your router password |
| `CME_ROUTER_NAME` | Router identifier | Name for logging/backups |
| `CME_API_KEY` | API key for CME Tools | `openssl rand -hex 24` |
| `CME_GIT_REMOTE_URL` | Git repository URL | Your backup repo URL |
| `CME_GIT_BACKUP_FOLDER` | Folder in git repo | Folder name for backups |
| `DISCORD_BOT_TOKEN` | Discord bot token | See Discord setup below |

**Optional Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone for all containers | `Europe/London` |
| `POSTGRES_USER` | Database user | `n8n` |
| `POSTGRES_DB` | Database name | `n8n` |
| `N8N_HOST` | n8n bind address | `127.0.0.1` (LAN-only) |
| `N8N_PORT` | n8n port | `5678` |
| `N8N_WEBHOOK_URL` | Public webhook URL | `http://127.0.0.1:5678/` |
| `N8N_INTERNAL_WEBHOOK_URL` | Internal webhook path | `http://n8n:5678/webhook/cme-discord` |
| `N8N_PROXY_HOPS` | Proxy hops count | `1` |
| `N8N_DIAGNOSTICS_ENABLED` | Enable n8n diagnostics | `false` |
| `N8N_PERSONALIZATION_ENABLED` | Enable n8n personalization | `false` |
| `CME_SESSION_IDLE_TIMEOUT_SECONDS` | Router session timeout | `30` |
| `CME_GIT_BRANCH` | Git branch for backups | `main` |
| `CME_GIT_HTTP_USERNAME` | Git username if auth required | (empty) |
| `CME_GIT_HTTP_TOKEN` | Git token/password if auth required | (empty) |
| `ALLOWED_GUILD_ID` | Restrict bot to specific guild ID | (all guilds) |
| `ALLOWED_CHANNEL_IDS` | Restrict bot to specific channels (comma-separated) | (all channels) |
| `COMMAND_PREFIX` | Command prefix for bot | `!cme` |

### 2. Create Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click "New Application" and give it a name (e.g., "CME Automation")
3. Go to "Bot" section and click "Add Bot"
4. **IMPORTANT:** Under "Privileged Gateway Intents", enable:
   - ✅ **Message Content Intent** (required for reading messages)
   - ✅ Server Members Intent (optional)
   - ✅ Presence Intent (optional)
5. Under "Token", click "Reset Token" and copy it to your `.env` as `DISCORD_BOT_TOKEN`
6. Save your token securely!

### 3. Invite Bot to Your Server

Generate an invite URL:

1. In Discord Developer Portal, go to "OAuth2" → "URL Generator"
2. Select scopes:
   - ✅ `bot`
3. Select bot permissions:
   - ✅ Read Messages/View Channels
   - ✅ Send Messages
   - ✅ Add Reactions (optional, for error indicators)
4. Copy the generated URL and open it in your browser
5. Select your server and authorize the bot

### 4. Start the Stack

```bash
./scripts/up.sh
```

This script will:
- Check for `.env` file and validate secrets
- Build the Discord bridge container
- Pull required images (n8n, postgres, cme-tools-api)
- Start all services with persistent volumes
- Display next steps

### 5. Access n8n

Open your browser to: http://127.0.0.1:5678

**First-time setup:**
1. Create an admin account (email + password)
2. Skip the onboarding/personalization steps
3. You'll be taken to the workflows dashboard

### 6. Create n8n Workflow

Now you need to create the workflow that processes Discord commands and calls the CME API.

#### Step-by-Step Workflow Creation

1. **Create New Workflow**
   - Click "Add Workflow" button
   - Name it "CME Discord Commands"

2. **Add Webhook Trigger Node**
   - Click "+" to add node
   - Search for "Webhook"
   - Select "Webhook" trigger
   - Configure:
     - **HTTP Method:** POST
     - **Path:** `cme-discord`
     - **Authentication:** None (internal network only)
   - Save and execute the node to activate it

3. **Add Code Node (Parse Command)**
   - Add a "Code" node after the Webhook
   - This node extracts the command from Discord message
   - Example code:
   ```javascript
   const content = $input.item.json.content || '';
   const command = content.replace(/^!cme\s*/i, '').trim();

   return {
     json: {
       originalMessage: $input.item.json,
       command: command,
       author: $input.item.json.author,
       channel: $input.item.json.channel
     }
   };
   ```

4. **Add Switch/IF Node (Route by Command Type)**
   - Add an "IF" or "Switch" node
   - Create conditions for different commands:
     - `!cme plan <config>` → route to plan endpoint
     - `!cme validate <config>` → route to validate endpoint
     - `!cme apply <config>` → route to apply endpoint
     - `!cme help` → return help text

5. **Optional: Add Gemini Node (AI Intent Parsing)**
   - Add "Google Gemini" node
   - Model: "gemini-2.5-flash-lite"
   - Prompt template:
   ```
   Parse this Cisco router command and extract the intent as JSON:

   Command: {{ $json.command }}

   Return JSON with: { "action": "plan|validate|apply", "config": "..." }
   ```
   - This helps parse natural language into structured commands

6. **Add HTTP Request Node (Call CME API Plan)**
   - Add "HTTP Request" node
   - Configure:
     - **Method:** POST
     - **URL:** `http://cme-tools-api:8000/plan`
     - **Authentication:** None (use headers instead)
     - **Headers:**
       ```json
       {
         "X-API-Key": "{{ $env.CME_API_KEY }}",
         "Content-Type": "application/json"
       }
       ```
     - **Body (JSON):**
       ```json
       {
         "config": "{{ $json.command }}"
       }
       ```

7. **Add HTTP Request Nodes for Other Endpoints**
   - Create similar nodes for:
     - `/validate` - Validates configuration without applying
     - `/apply` - Applies configuration to router
   - Route these based on the command type from step 4

8. **Add Response Node (Send to Discord)**
   - Option A: Use Discord node (requires Discord credentials setup)
   - Option B: Use HTTP Request to Discord API
     - **Method:** POST
     - **URL:** `https://discord.com/api/v10/channels/{{ $json.channel.id }}/messages`
     - **Authentication:** Use Discord bot token in header:
       ```
       Authorization: Bot YOUR_DISCORD_BOT_TOKEN
       ```
     - **Body:**
       ```json
       {
         "content": "✅ Result: {{ $json.result }}"
       }
       ```

9. **Add Error Handling**
   - Connect error outputs to a separate branch
   - Send error messages back to Discord
   - Example error response:
     ```json
     {
       "content": "❌ Error: {{ $json.error.message }}"
     }
     ```

10. **Activate Workflow**
    - Click "Active" toggle in top-right
    - Ensure webhook is listening

#### Example Workflow Structure

```
Webhook Trigger (cme-discord)
    ↓
Code (Parse command)
    ↓
IF (Check command type)
    ├─→ plan → HTTP (CME API /plan) → Discord Response
    ├─→ validate → HTTP (CME API /validate) → Discord Response
    ├─→ apply → HTTP (CME API /apply) → Discord Response
    └─→ help → Discord Response (static help text)
```

#### CME Tools API Endpoints

Assuming the API listens on port 8000 (internal):

- `POST http://cme-tools-api:8000/plan` - Generate configuration plan
- `POST http://cme-tools-api:8000/validate` - Validate configuration
- `POST http://cme-tools-api:8000/apply` - Apply configuration to router
- `GET http://cme-tools-api:8000/health` - Health check

All endpoints require `X-API-Key` header with the value from `CME_API_KEY` in your `.env`.

Refer to the cme-tools-api documentation for exact payload schemas.

### 7. Test the System

1. In Discord, send a message in an allowed channel:
   ```
   !cme help
   ```

2. Check that:
   - Discord bridge logs show message forwarded
   - n8n workflow receives webhook
   - Response is sent back to Discord

3. Try a real command (example):
   ```
   !cme plan dial-peer voice 100 voip
   ```

## Managing the Stack

### Start the stack
```bash
./scripts/up.sh
```

### Stop the stack
```bash
docker compose down
```

### Stop and remove all data (DESTRUCTIVE)
```bash
docker compose down -v
```

### View logs
```bash
./scripts/logs.sh
```

### Run health checks
```bash
./scripts/smoke.sh
```

### Restart a single service
```bash
docker compose restart discord-bridge
docker compose restart n8n
docker compose restart cme-tools-api
```

### Update images
```bash
docker compose pull
docker compose up -d --build
```

## Troubleshooting

### Discord bot not connecting

Check logs:
```bash
docker compose logs discord-bridge
```

Common issues:
- Invalid `DISCORD_BOT_TOKEN`
- Message Content Intent not enabled in Discord Developer Portal

### n8n not accessible

- Ensure you're accessing from the same machine: http://127.0.0.1:5678
- Check if container is running: `docker compose ps`
- Check logs: `docker compose logs n8n`

### CME API not responding

- Check if router is accessible from container: `ping 10.20.102.11`
- Verify router credentials in `.env`
- Check API logs: `docker compose logs cme-tools-api`
- Verify API key matches between `.env` and n8n workflow

### Messages not forwarding to n8n

- Ensure n8n workflow is **activated** (toggle in top-right)
- Verify webhook path is `cme-discord` in both workflow and docker-compose.yml
- Check discord-bridge logs for forwarding errors
- Verify channel/guild restrictions in `.env`

### Git backups not working

- Check if `CME_GIT_HTTP_USERNAME` and `CME_GIT_HTTP_TOKEN` are set (if repo requires auth)
- Verify git remote URL is correct
- Check cme-tools-api logs for git errors
- Ensure backup folder `a14-con` exists in repository

## Security Considerations

1. **LAN-Only Access**: n8n is bound to 127.0.0.1 only. To access from other machines:
   - Set up SSH tunnel: `ssh -L 5678:127.0.0.1:5678 user@your-vm`
   - Or configure a reverse proxy (nginx, Caddy) with authentication
   - **Do NOT** change binding to 0.0.0.0 without proper authentication!

2. **Secrets Management**:
   - Never commit `.env` to git (already in .gitignore)
   - Rotate API keys periodically
   - Use strong passwords for all services

3. **Discord Security**:
   - Use `ALLOWED_GUILD_ID` to restrict bot to your server only
   - Use `ALLOWED_CHANNEL_IDS` to restrict to specific channels
   - Consider using Discord roles for additional access control

4. **Network Isolation**:
   - All services run on isolated Docker network
   - Only n8n has exposed port (127.0.0.1 only)
   - CME API and Discord bridge are internal only

5. **Backup Security**:
   - Backups are pushed to your internal Git server
   - Ensure Git credentials are stored securely
   - Consider using SSH keys instead of HTTP tokens

## File Structure

```
cme-automation/
├── docker-compose.yml       # Main orchestration file
├── .env                     # Secrets (DO NOT COMMIT)
├── .env.example             # Template for .env
├── README.md                # This file
├── discord-bridge/          # Discord bot source
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
└── scripts/                 # Utility scripts
    ├── up.sh                # Start stack
    ├── logs.sh              # View logs
    └── smoke.sh             # Health checks
```

## Volumes

Persistent data is stored in Docker volumes:

- `postgres_data` - n8n database
- `n8n_data` - n8n workflows and settings
- `cme_state` - CME Tools API state/cache

To backup these volumes:
```bash
docker run --rm -v cme-automation_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup.tar.gz -C /data .
```

To restore:
```bash
docker run --rm -v cme-automation_n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-backup.tar.gz -C /data
```

## Customization

All deployment settings are configurable via `.env`:

- **Timezone:** Set via `TZ` (default: `Europe/London`)
- **Router:** Configure `CME_ROUTER_HOST`, `CME_ROUTER_USERNAME`, `CME_ROUTER_PASSWORD`
- **Router Name:** Set via `CME_ROUTER_NAME` (used in logging and backups)
- **Git Backup:** Configure `CME_GIT_REMOTE_URL`, `CME_GIT_BRANCH`, `CME_GIT_BACKUP_FOLDER`
- **n8n Access:** Change `N8N_HOST` and `N8N_PORT` if needed (default: `127.0.0.1:5678`)
- **Command Prefix:** Customize Discord command prefix via `COMMAND_PREFIX` (default: `!cme`)

See `.env.example` for all available configuration options with defaults and examples.

## Next Steps

1. Set up n8n workflow credentials for Discord (if using Discord node)
2. Configure additional n8n nodes (email notifications, logging, etc.)
3. Create custom commands for common router operations
4. Set up monitoring/alerting for stack health
5. Consider adding authentication to n8n if exposing via reverse proxy
6. Document your specific CME commands and workflows

## Support

For issues with:
- **n8n:** https://docs.n8n.io
- **Docker Compose:** https://docs.docker.com/compose
- **discord.js:** https://discord.js.org
- **CME Tools API:** Check the API's documentation or repository

## License

This stack configuration is provided as-is for internal use.
