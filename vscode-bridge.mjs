#!/usr/bin/env node
// vscode-bridge CLI — manual control of the VSCode bridge without OpenCode.
// Usage:
//   node vscode-bridge.mjs status
//   node vscode-bridge.mjs list
//   node vscode-bridge.mjs read <target>
//   node vscode-bridge.mjs open <target>
//   node vscode-bridge.mjs save [--all] [<target>]
//   node vscode-bridge.mjs write <target> [--save] [--no-reveal] [--text <content> | --file <path> | stdin]

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

function tokenFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE;
  return path.join(os.homedir(), '.config', 'opencode', 'vscode-bridge.token');
}
function portFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE.replace(/\.token$/, '.port');
  return path.join(os.homedir(), '.config', 'opencode', 'vscode-bridge.port');
}
function port() {
  if (process.env.VSCODE_BRIDGE_PORT) return Number(process.env.VSCODE_BRIDGE_PORT);
  try {
    const p = Number(fs.readFileSync(portFilePath(), 'utf8').trim());
    if (Number.isInteger(p) && p >= 1 && p <= 65535) return p;
  } catch {}
  return 37651;
}
function base() {
  return `http://${process.env.VSCODE_BRIDGE_HOST || '127.0.0.1'}:${port()}`;
}
const TIMEOUT_MS = Number(process.env.VSCODE_BRIDGE_TIMEOUT_MS || 30000);
function token() {
  if (process.env.VSCODE_BRIDGE_TOKEN) return process.env.VSCODE_BRIDGE_TOKEN.trim();
  try { return fs.readFileSync(tokenFilePath(), 'utf8').trim(); } catch { return ''; }
}
async function call(route, opts = {}) {
  const headers = { 'content-type': 'application/json' };
  const t = token();
  if (t) headers['x-bridge-token'] = t;
  let res;
  try {
    res = await fetch(base() + route, { ...opts, headers, body: opts.body ? JSON.stringify(opts.body) : undefined, signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (e) {
    if (e && (e.name === 'TimeoutError' || e.name === 'AbortError')) {
      console.error(`bridge timed out after ${TIMEOUT_MS}ms — extension may be busy; retry or restart it ("OpenCode Bridge: Restart server").`);
    } else {
      console.error(`cannot reach bridge at ${base()} (${e.cause?.code || e.message})`);
      console.error('hint: is VSCode running with the opencode-bridge extension enabled?');
    }
    process.exit(1);
  }
  const data = await res.json().catch(() => ({ ok: false, error: `HTTP ${res.status}` }));
  if (!res.ok || data.ok === false) {
    console.error(`bridge error (${res.status}): ${data.error || 'unknown'}`);
    if (res.status === 401) console.error('hint: token mismatch — run the VSCode extension once, then reuse its token file.');
    if (route !== '/status') console.error('hint: is VSCode running with the opencode-bridge extension?');
    process.exit(1);
  }
  return data;
}
function readStdin() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) return resolve(null);
    let s = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => { s += c; });
    process.stdin.on('end', () => resolve(s));
  });
}
function usage() {
  console.log(`vscode-bridge CLI
Usage:
  status | list | read <target> | open <target> | save [--all] [<target>]
  write <target> [--save] [--no-reveal] [--text <s> | --file <p> | stdin]
Env: VSCODE_BRIDGE_PORT (overrides port file), VSCODE_BRIDGE_HOST, VSCODE_BRIDGE_TOKEN,
     VSCODE_BRIDGE_TOKEN_FILE, VSCODE_BRIDGE_TIMEOUT_MS (default 30000).
Port is auto-discovered from ~/.config/opencode/vscode-bridge.port when set by the extension.`);
}

const [cmd, ...rest] = process.argv.slice(2);
if (!cmd || cmd === '-h' || cmd === '--help') { usage(); process.exit(0); }

if (cmd === 'status') console.log(JSON.stringify(await call('/status'), null, 2));
else if (cmd === 'list') console.log(JSON.stringify(await call('/open-files'), null, 2));
else if (cmd === 'read') {
  if (!rest[0]) { console.error('missing <target>'); process.exit(1); }
  const r = await call('/read', { method: 'POST', body: { target: rest[0] } });
  process.stdout.write(r.content);
}
else if (cmd === 'open') {
  if (!rest[0]) { console.error('missing <target>'); process.exit(1); }
  console.log(JSON.stringify(await call('/open', { method: 'POST', body: { target: rest[0] } }), null, 2));
}
else if (cmd === 'save') {
  const all = rest.includes('--all');
  const target = rest.find((a) => !a.startsWith('--'));
  console.log(JSON.stringify(await call('/save', { method: 'POST', body: { target, all } }), null, 2));
}
else if (cmd === 'write') {
  const target = rest.find((a) => !a.startsWith('--'));
  if (!target) { console.error('missing <target>'); process.exit(1); }
  const save = rest.includes('--save');
  const reveal = !rest.includes('--no-reveal');
  let content = null;
  const ti = rest.indexOf('--text');
  const fi = rest.indexOf('--file');
  if (ti >= 0) content = rest[ti + 1] ?? '';
  else if (fi >= 0) content = fs.readFileSync(rest[fi + 1], 'utf8');
  else content = await readStdin();
  if (content === null) { console.error('provide --text, --file, or pipe stdin'); process.exit(1); }
  console.log(JSON.stringify(await call('/write', { method: 'POST', body: { target, content, save, reveal } }), null, 2));
}
else { console.error(`unknown command: ${cmd}`); usage(); process.exit(1); }
