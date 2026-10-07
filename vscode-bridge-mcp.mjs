#!/usr/bin/env node
// vscode-bridge MCP server (stdio) — zero dependencies.
// Exposes VSCode bridge HTTP API as MCP tools for OpenCode.
// Transport: newline-delimited JSON-RPC over stdio (MCP 2024-11-05).

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';

const VERSION = '0.1.3';
const FETCH_TIMEOUT_MS = Number(process.env.VSCODE_BRIDGE_TIMEOUT_MS || 30000);
const DEFAULT_MAX_CHARS = 100000;
const MAX_WRITE_CHARS = 10 * 1024 * 1024;

// Stay alive: a long-lived MCP server must never die on one bad request.
process.on('uncaughtException', (e) => { console.error(`[vscode-bridge] uncaught: ${(e && e.message) || e}`); });
process.on('unhandledRejection', (e) => { console.error(`[vscode-bridge] unhandled rejection: ${(e && e.message) || e}`); });

function tokenFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE;
  return path.join(os.homedir(), '.config', 'opencode', 'vscode-bridge.token');
}

function portFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE.replace(/\.token$/, '.port');
  return path.join(os.homedir(), '.config', 'opencode', 'vscode-bridge.port');
}

/** Port precedence: env > port file written by the extension > default. */
function bridgePort() {
  if (process.env.VSCODE_BRIDGE_PORT) return Number(process.env.VSCODE_BRIDGE_PORT);
  try {
    const p = Number(fs.readFileSync(portFilePath(), 'utf8').trim());
    if (Number.isInteger(p) && p >= 1 && p <= 65535) return p;
  } catch (_) {}
  return 37651;
}

function bridgeBase() {
  const host = process.env.VSCODE_BRIDGE_HOST || '127.0.0.1';
  return `http://${host}:${bridgePort()}`;
}

function bridgeToken() {
  if (process.env.VSCODE_BRIDGE_TOKEN) return process.env.VSCODE_BRIDGE_TOKEN.trim();
  try {
    const t = fs.readFileSync(tokenFilePath(), 'utf8').trim();
    if (t) return t;
  } catch (_) {}
  return '';
}

async function bridgeFetch(route, { method = 'GET', body } = {}) {
  const token = bridgeToken();
  const headers = { 'content-type': 'application/json' };
  if (token) headers['x-bridge-token'] = token;
  let res;
  try {
    res = await fetch(bridgeBase() + route, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
  } catch (e) {
    if (e && (e.name === 'TimeoutError' || e.name === 'AbortError')) {
      throw new Error(`VSCode bridge at ${bridgeBase()} timed out after ${FETCH_TIMEOUT_MS}ms. The extension may be busy — retry, or restart it via "OpenCode Bridge: Restart server".`);
    }
    throw new Error(`cannot reach VSCode bridge at ${bridgeBase()} (${e.cause?.code || e.message}). Is VSCode running with the opencode-bridge extension enabled?`);
  }
  let data = null;
  try { data = await res.json(); } catch (_) { data = { ok: false, error: `bridge HTTP ${res.status}` }; }
  if (!res.ok || data?.ok === false) {
    const hint = res.status === 401
      ? ' (bad token — ensure VSCode extension ran once and token file matches)'
      : res.status === 404 ? ' (is the VSCode extension running?)' : '';
    throw new Error((data?.error || `bridge request failed: ${method} ${route} -> HTTP ${res.status}`) + hint);
  }
  return data;
}

const TOOLS = [
  {
    name: 'vscode_status',
    description: 'Check the VSCode bridge: workspace folders, open-file count, active file. Use first to verify VSCode is reachable.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'vscode_list_open',
    description: 'List files currently open in VSCode editors (fsPath, language, dirty, active).',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'vscode_read',
    description: 'Read a file through VSCode. Prefers the open editor buffer (includes unsaved changes); falls back to disk. Target may be an absolute path, workspace-relative path, or file:// URI. Large outputs are truncated at maxChars.',
    inputSchema: {
      type: 'object',
      required: ['target'],
      properties: {
        target: { type: 'string', description: 'Absolute path, workspace-relative path, or file:// URI' },
        maxChars: { type: 'number', description: `Truncate content at this many chars (default ${DEFAULT_MAX_CHARS})`, default: DEFAULT_MAX_CHARS },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'vscode_write',
    description: 'Write full file content through VSCode (applies to the open editor, opens the file if needed). Set save=true to also save to disk; reveal=false to skip focusing the editor.',
    inputSchema: {
      type: 'object',
      required: ['target', 'content'],
      properties: {
        target: { type: 'string', description: 'Absolute path, workspace-relative path, or file:// URI' },
        content: { type: 'string', description: 'Complete new file content' },
        save: { type: 'boolean', description: 'Save to disk after writing (default false)', default: false },
        reveal: { type: 'boolean', description: 'Reveal/focus in editor (default true)', default: true },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'vscode_open',
    description: 'Open a file in VSCode (by path or URI) and reveal it.',
    inputSchema: {
      type: 'object',
      required: ['target'],
      properties: {
        target: { type: 'string' },
        preview: { type: 'boolean', default: false },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'vscode_save',
    description: 'Save editor(s): pass target for one file, all=true for save-all, neither for the active editor.',
    inputSchema: {
      type: 'object',
      properties: {
        target: { type: 'string' },
        all: { type: 'boolean', default: false },
      },
      additionalProperties: false,
    },
  },
];

function textResult(obj) {
  return { content: [{ type: 'text', text: JSON.stringify(obj, null, 2) }] };
}

async function callTool(name, args = {}) {
  switch (name) {
    case 'vscode_status': return textResult(await bridgeFetch('/status'));
    case 'vscode_list_open': return textResult(await bridgeFetch('/open-files'));
    case 'vscode_read': {
      if (!args.target) throw new Error('missing required argument: target');
      const data = await bridgeFetch('/read', { method: 'POST', body: { target: args.target } });
      const max = Number.isFinite(Number(args.maxChars)) ? Number(args.maxChars) : DEFAULT_MAX_CHARS;
      if (typeof data.content === 'string' && data.content.length > max) {
        data.content = data.content.slice(0, max);
        data.truncated = true;
        data.note = `content truncated to maxChars=${max}; re-read with a larger maxChars if needed`;
      }
      return textResult(data);
    }
    case 'vscode_write':
      if (!args.target) throw new Error('missing required argument: target');
      if (typeof args.content !== 'string') throw new Error('missing required argument: content (string)');
      if (args.content.length > MAX_WRITE_CHARS) throw new Error(`content exceeds ${MAX_WRITE_CHARS} chars; split the write`);
      return textResult(await bridgeFetch('/write', {
        method: 'POST',
        body: { target: args.target, content: args.content, save: args.save === true, reveal: args.reveal !== false },
      }));
    case 'vscode_open':
      if (!args.target) throw new Error('missing required argument: target');
      return textResult(await bridgeFetch('/open', { method: 'POST', body: { target: args.target, preview: args.preview === true } }));
    case 'vscode_save':
      return textResult(await bridgeFetch('/save', { method: 'POST', body: { target: args.target, all: args.all === true } }));
    default: throw new Error(`unknown tool: ${name}`);
  }
}

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
let initialized = false;

async function handleMessage(msg) {
  const { id = null, method, params = {} } = msg || {};
  const reply = (result) => ({ jsonrpc: '2.0', id, result });
  const fail = (code, message, data) => ({ jsonrpc: '2.0', id, error: { code, message, data } });
  try {
    if (method === 'initialize') {
      initialized = true;
      return reply({
        protocolVersion: '2024-11-05',
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: 'vscode-bridge', version: VERSION },
      });
    }
    if (method === 'notifications/initialized' || (method || '').startsWith('notifications/')) return null;
    if (method === 'ping') return reply({});
    if (method === 'tools/list') return reply({ tools: TOOLS });
    if (method === 'tools/call') {
      const { name, arguments: args } = params;
      try {
        return reply(await callTool(name, args || {}));
      } catch (e) {
        return reply({ content: [{ type: 'text', text: `Error: ${e.message}` }], isError: true });
      }
    }
    if (id === null || id === undefined) return null;
    return fail(-32601, `method not found: ${method}`);
  } catch (e) {
    return fail(-32603, e.message || String(e));
  }
}

for await (const line of rl) {
  const trimmed = line.trim();
  if (!trimmed) continue;
  let msg = null;
  try { msg = JSON.parse(trimmed); } catch { continue; }
  const res = await handleMessage(msg);
  if (res) process.stdout.write(JSON.stringify(res) + '\n');
}
