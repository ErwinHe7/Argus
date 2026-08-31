#!/usr/bin/env node
// axio7-market-mcp — stdio MCP server exposing AXIO7 market intelligence
// to Claude Desktop / Claude Code / Codex / any MCP-capable client.
//
// Run:  node dist/index.js
// Dev:  npm run dev
//
// Env:
//   AXIO7_API_BASE_URL   default https://axio7.com
//   AXIO7_API_TOKEN      optional bearer token for per-user routes
//   AXIO7_API_TIMEOUT_MS default 25000
//
// Transport: stdio only (local). For remote MCP add OAuth wrapper later.

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolResult,
  type ListToolsResult,
} from '@modelcontextprotocol/sdk/types.js';
import { ALL_TOOLS, describeBackend } from './tools.js';

const server = new Server(
  {
    name: 'axio7-market-mcp',
    version: '0.1.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async (): Promise<ListToolsResult> => {
  return {
    tools: ALL_TOOLS.map((t) => ({
      name: t.name,
      description: t.description,
      inputSchema: t.inputSchema as ListToolsResult['tools'][number]['inputSchema'],
    })),
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request): Promise<CallToolResult> => {
  const { name, arguments: rawArgs } = request.params;
  const tool = ALL_TOOLS.find((t) => t.name === name);
  if (!tool) {
    return {
      isError: true,
      content: [{ type: 'text', text: `unknown tool: ${name}` }],
    };
  }
  try {
    const args = (rawArgs ?? {}) as Record<string, unknown>;
    const result = await tool.handler(args);
    return {
      content: [
        {
          type: 'text',
          text: typeof result === 'string' ? result : JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      isError: true,
      content: [{ type: 'text', text: `tool error (${name}): ${message}` }],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr is fine — MCP reserves stdout for JSON-RPC frames.
  process.stderr.write(`[axio7-market-mcp] ready · ${describeBackend()} · ${ALL_TOOLS.length} tools\n`);
}

main().catch((err) => {
  process.stderr.write(`[axio7-market-mcp] fatal: ${err instanceof Error ? err.stack : String(err)}\n`);
  process.exit(1);
});
