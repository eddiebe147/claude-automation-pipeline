#!/usr/bin/env node
/**
 * Clawdbot MCP Bridge
 *
 * Bridges Clawdbot Gateway WebSocket API to LobeHub via MCP Protocol.
 * Exposes Clawdbot's 30+ tools as MCP tools for AI agents.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import WebSocket from "ws";
import { z } from "zod";

// Configuration from environment
const CLAWDBOT_GATEWAY_URL = process.env.CLAWDBOT_GATEWAY_URL || "ws://127.0.0.1:18789";
const CLAWDBOT_AUTH_TOKEN = process.env.CLAWDBOT_AUTH_TOKEN || "";

// Types for Clawdbot protocol
interface ClawdbotRequest {
  type: "req";
  id: string;
  method: string;
  params: Record<string, unknown>;
}

interface ClawdbotResponse {
  type: "res";
  id: string;
  ok: boolean;
  payload?: unknown;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
}

// Tool definitions that map to Clawdbot gateway methods
const CLAWDBOT_TOOLS: Tool[] = [
  // Agent & Chat Tools
  {
    name: "clawdbot_agent",
    description: "Execute an AI agent with a message. The agent processes the message and returns a response.",
    inputSchema: {
      type: "object",
      properties: {
        message: { type: "string", description: "Message for the agent to process" },
        model: { type: "string", description: "Model to use (optional)" },
        sessionId: { type: "string", description: "Session ID for context continuity (optional)" },
      },
      required: ["message"],
    },
  },
  {
    name: "clawdbot_chat_send",
    description: "Send a chat message to a specific channel (telegram, whatsapp, etc.)",
    inputSchema: {
      type: "object",
      properties: {
        channel: { type: "string", description: "Channel name (telegram, whatsapp, email)" },
        to: { type: "string", description: "Recipient ID or chat ID" },
        text: { type: "string", description: "Message text to send" },
      },
      required: ["channel", "to", "text"],
    },
  },
  {
    name: "clawdbot_chat_history",
    description: "Get chat history from a channel",
    inputSchema: {
      type: "object",
      properties: {
        channel: { type: "string", description: "Channel name" },
        chatId: { type: "string", description: "Chat/conversation ID" },
        limit: { type: "number", description: "Max messages to retrieve (default 50)" },
      },
      required: ["channel", "chatId"],
    },
  },

  // Configuration Tools
  {
    name: "clawdbot_config_get",
    description: "Get Clawdbot configuration",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "JSON path to config section (optional)" },
      },
    },
  },
  {
    name: "clawdbot_models_list",
    description: "List available AI models (local Ollama + cloud providers)",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Skills Tools
  {
    name: "clawdbot_skills_status",
    description: "Get status of installed skills",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_skills_install",
    description: "Install a new skill by name",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Skill name to install" },
      },
      required: ["name"],
    },
  },

  // Session Management
  {
    name: "clawdbot_sessions_list",
    description: "List active agent sessions",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_sessions_preview",
    description: "Preview a session's context/history",
    inputSchema: {
      type: "object",
      properties: {
        sessionId: { type: "string", description: "Session ID to preview" },
      },
      required: ["sessionId"],
    },
  },

  // Cron/Scheduling Tools
  {
    name: "clawdbot_cron_list",
    description: "List scheduled cron jobs",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_cron_add",
    description: "Add a new scheduled task",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Name for the cron job" },
        schedule: { type: "string", description: "Cron expression (e.g., '0 9 * * *' for 9 AM daily)" },
        command: { type: "string", description: "Command/message to execute" },
      },
      required: ["name", "schedule", "command"],
    },
  },
  {
    name: "clawdbot_cron_remove",
    description: "Remove a scheduled task",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Name of the cron job to remove" },
      },
      required: ["name"],
    },
  },

  // System Tools
  {
    name: "clawdbot_health",
    description: "Get Clawdbot gateway health status",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_status",
    description: "Get detailed Clawdbot status including channels, nodes, and sessions",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_channels_status",
    description: "Get status of communication channels (Telegram, WhatsApp, etc.)",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },

  // Memory Tools
  {
    name: "clawdbot_memory_search",
    description: "Search Clawdbot's memory/knowledge base",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        limit: { type: "number", description: "Max results (default 10)" },
      },
      required: ["query"],
    },
  },

  // Node/Remote Tools
  {
    name: "clawdbot_node_list",
    description: "List connected remote nodes",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "clawdbot_node_invoke",
    description: "Invoke a method on a remote node",
    inputSchema: {
      type: "object",
      properties: {
        nodeId: { type: "string", description: "ID of the target node" },
        method: { type: "string", description: "Method to invoke on the node" },
        params: { type: "object", description: "Parameters for the method" },
      },
      required: ["nodeId", "method"],
    },
  },
];

// Map MCP tool names to Clawdbot gateway methods
const TOOL_TO_METHOD: Record<string, string> = {
  clawdbot_agent: "agent",
  clawdbot_chat_send: "chat.send",
  clawdbot_chat_history: "chat.history",
  clawdbot_config_get: "config.get",
  clawdbot_models_list: "models.list",
  clawdbot_skills_status: "skills.status",
  clawdbot_skills_install: "skills.install",
  clawdbot_sessions_list: "sessions.list",
  clawdbot_sessions_preview: "sessions.preview",
  clawdbot_cron_list: "cron.list",
  clawdbot_cron_add: "cron.add",
  clawdbot_cron_remove: "cron.remove",
  clawdbot_health: "health",
  clawdbot_status: "status",
  clawdbot_channels_status: "channels.status",
  clawdbot_memory_search: "memory.search",
  clawdbot_node_list: "node.list",
  clawdbot_node_invoke: "node.invoke",
};

/**
 * Clawdbot Gateway Client
 * Manages WebSocket connection and request/response handling
 */
class ClawdbotClient {
  private ws: WebSocket | null = null;
  private requestId = 0;
  private pendingRequests = new Map<string, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
  }>();
  private connected = false;
  private connecting = false;

  constructor(
    private readonly url: string,
    private readonly authToken: string
  ) {}

  async connect(): Promise<void> {
    if (this.connected) return;
    if (this.connecting) {
      // Wait for ongoing connection
      await new Promise<void>((resolve) => {
        const check = () => {
          if (this.connected) resolve();
          else setTimeout(check, 100);
        };
        check();
      });
      return;
    }

    this.connecting = true;

    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);

      this.ws.on("open", async () => {
        try {
          // Send connect handshake
          await this.sendHandshake();
          this.connected = true;
          this.connecting = false;
          resolve();
        } catch (err) {
          this.connecting = false;
          reject(err);
        }
      });

      this.ws.on("message", (data) => {
        try {
          const message = JSON.parse(data.toString()) as ClawdbotResponse;
          if (message.type === "res" && message.id) {
            const pending = this.pendingRequests.get(message.id);
            if (pending) {
              this.pendingRequests.delete(message.id);
              if (message.ok) {
                pending.resolve(message.payload);
              } else {
                pending.reject(new Error(message.error?.message || "Unknown error"));
              }
            }
          }
        } catch (err) {
          console.error("Failed to parse gateway message:", err);
        }
      });

      this.ws.on("error", (err) => {
        console.error("WebSocket error:", err);
        this.connected = false;
        this.connecting = false;
      });

      this.ws.on("close", () => {
        this.connected = false;
        this.connecting = false;
        // Reject all pending requests
        for (const [id, pending] of this.pendingRequests) {
          pending.reject(new Error("Connection closed"));
          this.pendingRequests.delete(id);
        }
      });
    });
  }

  private async sendHandshake(): Promise<void> {
    const handshakeId = `handshake-${Date.now()}`;

    const connectRequest: ClawdbotRequest = {
      type: "req",
      id: handshakeId,
      method: "connect",
      params: {
        minProtocol: 1,
        maxProtocol: 1,
        client: {
          id: "mcp-bridge",
          displayName: "LobeHub MCP Bridge",
          version: "1.0.0",
          platform: process.platform,
          mode: "backend",
        },
        auth: {
          token: this.authToken,
        },
        role: "operator",
        scopes: ["operator.admin", "operator.read", "operator.write"],
      },
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(handshakeId);
        reject(new Error("Handshake timeout"));
      }, 10000);

      this.pendingRequests.set(handshakeId, {
        resolve: () => {
          clearTimeout(timeout);
          resolve();
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        },
      });

      this.ws?.send(JSON.stringify(connectRequest));
    });
  }

  async request(method: string, params: Record<string, unknown> = {}): Promise<unknown> {
    if (!this.connected) {
      await this.connect();
    }

    const id = `req-${++this.requestId}-${Date.now()}`;

    const request: ClawdbotRequest = {
      type: "req",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Request timeout for ${method}`));
      }, 60000); // 60s timeout for agent requests

      this.pendingRequests.set(id, {
        resolve: (value) => {
          clearTimeout(timeout);
          resolve(value);
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        },
      });

      this.ws?.send(JSON.stringify(request));
    });
  }

  close(): void {
    this.ws?.close();
    this.connected = false;
  }
}

/**
 * MCP Server
 * Exposes Clawdbot tools via MCP protocol
 */
async function main() {
  const clawdbot = new ClawdbotClient(CLAWDBOT_GATEWAY_URL, CLAWDBOT_AUTH_TOKEN);

  const server = new Server(
    {
      name: "clawdbot-mcp-bridge",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // List available tools
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: CLAWDBOT_TOOLS };
  });

  // Handle tool calls
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    const method = TOOL_TO_METHOD[name];
    if (!method) {
      throw new Error(`Unknown tool: ${name}`);
    }

    try {
      const result = await clawdbot.request(method, args as Record<string, unknown> || {});

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: `Error: ${message}`,
          },
        ],
        isError: true,
      };
    }
  });

  // Start server with stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("Clawdbot MCP Bridge started");
  console.error(`Gateway: ${CLAWDBOT_GATEWAY_URL}`);

  // Handle graceful shutdown
  process.on("SIGINT", () => {
    clawdbot.close();
    process.exit(0);
  });

  process.on("SIGTERM", () => {
    clawdbot.close();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("Failed to start MCP bridge:", err);
  process.exit(1);
});
