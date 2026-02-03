const { Client, GatewayIntentBits } = require('discord.js');
const axios = require('axios');

// Configuration from environment
const DISCORD_BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
const ALLOWED_GUILD_ID = process.env.ALLOWED_GUILD_ID || '';
const ALLOWED_CHANNEL_IDS = process.env.ALLOWED_CHANNEL_IDS
  ? process.env.ALLOWED_CHANNEL_IDS.split(',').map(id => id.trim())
  : [];
const COMMAND_PREFIX = (process.env.COMMAND_PREFIX || '!cme').toLowerCase();

// Validation
if (!DISCORD_BOT_TOKEN) {
  console.error('ERROR: DISCORD_BOT_TOKEN is required');
  process.exit(1);
}

if (!N8N_WEBHOOK_URL) {
  console.error('ERROR: N8N_WEBHOOK_URL is required');
  process.exit(1);
}

// Initialize Discord client with required intents
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent, // Required for reading message content
  ],
});

// Ready event
client.once('ready', () => {
  console.log(`[READY] Logged in as ${client.user.tag}`);
  console.log(`[CONFIG] n8n webhook: ${N8N_WEBHOOK_URL}`);
  console.log(`[CONFIG] Command prefix: ${COMMAND_PREFIX}`);

  if (ALLOWED_GUILD_ID) {
    console.log(`[SECURITY] Restricted to guild ID: ${ALLOWED_GUILD_ID}`);
  } else {
    console.log(`[SECURITY] No guild restriction (all guilds allowed)`);
  }

  if (ALLOWED_CHANNEL_IDS.length > 0) {
    console.log(`[SECURITY] Restricted to channel IDs: ${ALLOWED_CHANNEL_IDS.join(', ')}`);
  } else {
    console.log(`[SECURITY] No channel restriction (all channels allowed)`);
  }
});

// Message event handler
client.on('messageCreate', async (message) => {
  // Ignore bot messages
  if (message.author.bot) return;

  // Check guild allowlist
  if (ALLOWED_GUILD_ID && message.guildId !== ALLOWED_GUILD_ID) {
    return;
  }

  // Check channel allowlist
  if (ALLOWED_CHANNEL_IDS.length > 0 && !ALLOWED_CHANNEL_IDS.includes(message.channelId)) {
    return;
  }

  // Check if message starts with command prefix (case-insensitive)
  const content = message.content.trim();
  if (!content.toLowerCase().startsWith(COMMAND_PREFIX)) {
    return;
  }

  // Build payload for n8n
  const payload = {
    content: message.content,
    author: {
      id: message.author.id,
      username: message.author.username,
      discriminator: message.author.discriminator,
      tag: message.author.tag,
    },
    guild: message.guild ? {
      id: message.guild.id,
      name: message.guild.name,
    } : null,
    channel: {
      id: message.channelId,
      name: message.channel.name || 'DM',
    },
    message: {
      id: message.id,
      timestamp: message.createdTimestamp,
    },
    timestamp: new Date().toISOString(),
  };

  console.log(`[FORWARD] Message from ${message.author.tag} in ${message.guild?.name || 'DM'}: ${content}`);

  // Forward to n8n webhook
  try {
    const response = await axios.post(N8N_WEBHOOK_URL, payload, {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 10000, // 10 second timeout
    });

    console.log(`[SUCCESS] Forwarded to n8n (status: ${response.status})`);
  } catch (error) {
    console.error(`[ERROR] Failed to forward message to n8n:`, error.message);

    if (error.response) {
      console.error(`[ERROR] Response status: ${error.response.status}`);
      console.error(`[ERROR] Response data:`, error.response.data);
    }

    // Optionally react to message to indicate error
    try {
      await message.react('❌');
    } catch (reactError) {
      console.error(`[ERROR] Failed to add error reaction:`, reactError.message);
    }
  }
});

// Error handling
client.on('error', (error) => {
  console.error('[DISCORD ERROR]', error);
});

process.on('unhandledRejection', (error) => {
  console.error('[UNHANDLED REJECTION]', error);
});

// Login
console.log('[STARTUP] Connecting to Discord...');
client.login(DISCORD_BOT_TOKEN);
