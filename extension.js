// OpenCode Bridge VSCode extension — zero dependencies (vscode API + node builtins).
// HTTP API (localhost only):
//   GET  /status
//   GET  /open-files
//   POST /read  { target }
//   POST /write { target, content, reveal?, save? }
//   POST /open  { target, preview? }
//   POST /save  { target?, all? }
// Auth: header `x-bridge-token` or `Authorization: Bearer <token>` must match
// the shared token file (see getToken()).

const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

let server = null;
let output = null;
let sharedMode = false;

const VERSION = '0.1.3';
// Safety limits (bytes/chars). Read/write of very large files can OOM the
// extension host or flood MCP context — fail fast with a clear message instead.
const MAX_READ_BYTES = 8 * 1024 * 1024;
const MAX_WRITE_CHARS = 10 * 1024 * 1024;
const MAX_BODY_BYTES = 50 * 1024 * 1024;

function bridgeDir() {
  const dir = path.join(os.homedir(), '.config', 'opencode');
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function tokenFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE;
  return path.join(bridgeDir(), 'vscode-bridge.token');
}

function portFilePath() {
  if (process.env.VSCODE_BRIDGE_TOKEN_FILE) return process.env.VSCODE_BRIDGE_TOKEN_FILE.replace(/\.token$/, '.port');
  return path.join(bridgeDir(), 'vscode-bridge.port');
}

function readTokenFile() {
  try {
    const t = fs.readFileSync(tokenFilePath(), 'utf8').trim();
    return t || null;
  } catch (_) { return null; }
}

function getToken() {
  if (process.env.VSCODE_BRIDGE_TOKEN) return process.env.VSCODE_BRIDGE_TOKEN.trim();
  const existing = readTokenFile();
  if (existing) return existing;
  const token = crypto.randomBytes(32).toString('hex');
  fs.writeFileSync(tokenFilePath(), token + '\n', { mode: 0o600 });
  return token;
}

/** Re-read the token on every request so rotation/deletion recovers without restart. */
function currentToken(fallback) {
  if (process.env.VSCODE_BRIDGE_TOKEN) return process.env.VSCODE_BRIDGE_TOKEN.trim();
  return readTokenFile() || fallback;
}

function isLoopback(host) {
  return host === '127.0.0.1' || host === 'localhost' || host === '::1' || host === '::ffff:127.0.0.1';
}

/** Refuse binary payloads: they corrupt JSON transport and MCP context. */
function assertText(content, target) {
  if (content.includes('\0')) {
    throw new Error(`refusing binary content for ${target}: bridge transports text only`);
  }
}

function getSettings(vscode) {
  const cfg = vscode.workspace.getConfiguration('opencodeBridge');
  return {
    port: Number(process.env.VSCODE_BRIDGE_PORT || cfg.get('port', 37651)),
    host: process.env.VSCODE_BRIDGE_HOST || cfg.get('host', '127.0.0.1'),
    enabled: cfg.get('enabled', true),
  };
}

function describeDoc(vscode, doc) {
  const active = vscode.window.activeTextEditor?.document === doc;
  return {
    fsPath: doc.uri.scheme === 'file' ? doc.uri.fsPath : null,
    uri: doc.uri.toString(),
    fileName: doc.fileName,
    languageId: doc.languageId,
    isActive: !!active,
    isDirty: doc.isDirty,
    isUntitled: doc.isUntitled,
  };
}

function listOpen(vscode) {
  // textDocuments includes all open docs; visible editors cover preview tabs too.
  const seen = new Map();
  for (const doc of vscode.workspace.textDocuments) seen.set(doc.uri.toString(), doc);
  for (const ed of vscode.window.visibleTextEditors) seen.set(ed.document.uri.toString(), ed.document);
  return [...seen.values()].map((d) => describeDoc(vscode, d));
}

/** Resolve a target string to a vscode.Uri. Supports file:// URIs, absolute paths, workspace-relative paths. */
function resolveTarget(vscode, target) {
  if (!target || typeof target !== 'string') throw new Error('missing "target"');
  // Windows drive-letter (C:\... or C:/...) and UNC (\\...) paths must be checked
  // before the URI-scheme test — "C:" otherwise looks like a URI scheme.
  if (/^[a-zA-Z]:[\\/]/.test(target) || target.startsWith('\\\\')) return vscode.Uri.file(target);
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(target)) return vscode.Uri.parse(target);
  if (path.isAbsolute(target)) return vscode.Uri.file(target);
  const folder = vscode.workspace.workspaceFolders?.[0]?.uri;
  if (folder) return vscode.Uri.joinPath(folder, target);
  return vscode.Uri.file(path.resolve(target));
}

function findOpenDoc(vscode, uri) {
  const key = uri.toString();
  return vscode.workspace.textDocuments.find((d) => d.uri.toString() === key) || null;
}

async function readTarget(vscode, target) {
  const uri = resolveTarget(vscode, target);
  const open = findOpenDoc(vscode, uri);
  if (open) {
    const content = open.getText();
    if (content.length > MAX_READ_BYTES) {
      throw new Error(`open document exceeds ${MAX_READ_BYTES} bytes (${content.length}); refusing to transfer`);
    }
    assertText(content.slice(0, 65536), target);
    return { fsPath: open.uri.scheme === 'file' ? open.uri.fsPath : null, uri: open.uri.toString(), content, isDirty: open.isDirty, from: 'editor' };
  }
  if (uri.scheme !== 'file') throw new Error('document is not open and target is not a file path: ' + target);
  const bytes = await vscode.workspace.fs.readFile(uri);
  if (bytes.length > MAX_READ_BYTES) {
    throw new Error(`file exceeds ${MAX_READ_BYTES} bytes (${bytes.length}); refusing to transfer`);
  }
  const content = Buffer.from(bytes).toString('utf8');
  assertText(content.slice(0, 65536), target);
  return { fsPath: uri.fsPath, uri: uri.toString(), content, isDirty: false, from: 'disk' };
}

async function writeTarget(vscode, target, content, opts = {}) {
  if (typeof content !== 'string') throw new Error('"content" must be a string');
  if (content.length > MAX_WRITE_CHARS) {
    throw new Error(`content exceeds ${MAX_WRITE_CHARS} chars (${content.length}); refusing to write`);
  }
  assertText(content.slice(0, 65536), target);
  const reveal = opts.reveal !== false;
  const save = opts.save === true;
  const uri = resolveTarget(vscode, target);
  let doc = findOpenDoc(vscode, uri);
  if (!doc) {
    if (uri.scheme !== 'file') throw new Error('cannot create non-file document: ' + target);
    // Ensure parent dir exists for new files (path.dirname is sturdier than '..' juggling).
    const parent = path.dirname(uri.fsPath);
    try {
      await vscode.workspace.fs.createDirectory(vscode.Uri.file(parent));
    } catch (e) {
      if (!/exists|EEXIST/i.test(String((e && e.message) || e))) throw e;
    }
    try {
      doc = await vscode.workspace.openTextDocument(uri);
    } catch (_) {
      // File does not exist yet: write bytes directly, then open.
      await vscode.workspace.fs.writeFile(uri, Buffer.from(content, 'utf8'));
      doc = await vscode.workspace.openTextDocument(uri);
      if (reveal) await vscode.window.showTextDocument(doc, { preview: false });
      return { fsPath: uri.fsPath, uri: uri.toString(), saved: true, revealed: reveal };
    }
  }
  if (doc.isUntitled && save) {
    throw new Error('cannot save untitled document (VSCode would prompt for a path): open or write a file path instead');
  }
  const fullRange = new vscode.Range(doc.positionAt(0), doc.positionAt(doc.getText().length));
  const edit = new vscode.WorkspaceEdit();
  edit.replace(doc.uri, fullRange, content);
  const applied = await vscode.workspace.applyEdit(edit);
  if (!applied) throw new Error('edit was not applied');
  if (reveal) await vscode.window.showTextDocument(doc, { preview: false });
  let saved = false;
  if (save) saved = await doc.save();
  return { fsPath: doc.uri.scheme === 'file' ? doc.uri.fsPath : null, uri: doc.uri.toString(), saved, revealed: reveal };
}

async function openTarget(vscode, target, preview = false) {
  const uri = resolveTarget(vscode, target);
  const doc = await vscode.workspace.openTextDocument(uri);
  await vscode.window.showTextDocument(doc, { preview });
  return { fsPath: doc.uri.scheme === 'file' ? doc.uri.fsPath : null, uri: doc.uri.toString() };
}

async function saveTarget(vscode, target, all) {
  if (all) {
    const ok = await vscode.workspace.saveAll(false);
    return { saved: ok ? ['*'] : [] };
  }
  if (!target) {
    const doc = vscode.window.activeTextEditor?.document;
    if (!doc) throw new Error('no active editor to save');
    const ok = await doc.save();
    return { saved: ok ? [doc.uri.toString()] : [] };
  }
  const uri = resolveTarget(vscode, target);
  const doc = findOpenDoc(vscode, uri);
  if (!doc) throw new Error('document is not open: ' + target);
  const ok = await doc.save();
  return { saved: ok ? [doc.uri.toString()] : [] };
}

function sendJson(res, code, obj) {
  try {
    const body = JSON.stringify(obj);
    res.writeHead(code, { 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) });
    res.end(body);
  } catch (_) { try { res.destroy(); } catch (_) {} }
}

function readBody(req, res) {
  return new Promise((resolve, reject) => {
    let data = '';
    let rejected = false;
    req.on('data', (c) => {
      data += c;
      if (!rejected && data.length > MAX_BODY_BYTES) {
        rejected = true;
        sendJson(res, 413, { ok: false, error: `request body exceeds ${MAX_BODY_BYTES} bytes` });
        req.destroy();
        reject(new Error('request body too large'));
      }
    });
    req.on('end', () => {
      if (rejected) return;
      if (!data) return resolve({});
      try { resolve(JSON.parse(data)); } catch (e) { reject(new Error('invalid JSON body')); }
    });
    req.on('error', reject);
  });
}

async function handleRequest(vscode, req, res, startupToken) {
  const url = new URL(req.url || '/', 'http://localhost');
  if (url.pathname !== '/status') {
    const given = req.headers['x-bridge-token'] || (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    if (!given || given !== currentToken(startupToken)) return sendJson(res, 401, { ok: false, error: 'unauthorized: bad or missing token' });
  }
  try {
    if (req.method === 'GET' && url.pathname === '/status') {
      const folders = (vscode.workspace.workspaceFolders || []).map((f) => ({ name: f.name, fsPath: f.uri.fsPath, uri: f.uri.toString() }));
      const active = vscode.window.activeTextEditor?.document;
      return sendJson(res, 200, {
        ok: true, extension: 'opencode-bridge', version: VERSION,
        shared: sharedMode,
        workspaceFolders: folders,
        openCount: vscode.workspace.textDocuments.length,
        activeFile: active ? describeDoc(vscode, active) : null,
      });
    }
    if (req.method === 'GET' && url.pathname === '/open-files') {
      return sendJson(res, 200, { ok: true, files: listOpen(vscode) });
    }
    if (req.method === 'POST' && ['/read', '/write', '/open', '/save'].includes(url.pathname)) {
      const body = await readBody(req, res);
      if (url.pathname === '/read') {
        const r = await readTarget(vscode, body.target);
        return sendJson(res, 200, { ok: true, ...r });
      }
      if (url.pathname === '/write') {
        const r = await writeTarget(vscode, body.target, body.content, { reveal: body.reveal, save: body.save });
        return sendJson(res, 200, { ok: true, ...r });
      }
      if (url.pathname === '/open') {
        const r = await openTarget(vscode, body.target, body.preview === true);
        return sendJson(res, 200, { ok: true, ...r });
      }
      if (url.pathname === '/save') {
        const r = await saveTarget(vscode, body.target, body.all === true);
        return sendJson(res, 200, { ok: true, ...r });
      }
    }
    return sendJson(res, 404, { ok: false, error: 'not found: ' + req.method + ' ' + url.pathname });
  } catch (e) {
    return sendJson(res, 500, { ok: false, error: String((e && e.message) || e) });
  }
}

/** Probe a port: is our own bridge already serving there (e.g. another window)? */
function probeOwnBridge(host, port) {
  return new Promise((resolve) => {
    const req = http.get({ host, port, path: '/status', timeout: 2000 }, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve(res.statusCode === 200 && parsed && parsed.extension === 'opencode-bridge');
        } catch (_) { resolve(false); }
      });
    });
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.on('error', () => resolve(false));
  });
}

async function startServer(vscode, context) {
  stopServer();
  sharedMode = false;
  const { port, host, enabled } = getSettings(vscode);
  if (!enabled) {
    output?.appendLine('[bridge] disabled via opencodeBridge.enabled');
    return;
  }
  if (!isLoopback(host)) {
    output?.appendLine(`[bridge] WARNING: host is ${host} — bridge should stay on loopback`);
  }
  const token = getToken();
  server = http.createServer((req, res) => { handleRequest(vscode, req, res, token).catch((e) => {
    // readBody rejections already answered (e.g. 413); only answer if untouched.
    if (!res.headersSent && !res.writableEnded) {
      try { sendJson(res, 500, { ok: false, error: 'internal' }); } catch (_) {}
    }
  }); });
  server.on('error', (e) => output?.appendLine('[bridge] server error: ' + String((e && e.message) || e)));
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(port, host, () => resolve());
    });
  } catch (e) {
    if (e && e.code === 'EADDRINUSE' && await probeOwnBridge(host, port)) {
      // Another VSCode window already serves this bridge: share it instead of failing.
      stopServer();
      sharedMode = true;
      output?.appendLine(`[bridge] port ${port} already serves opencode-bridge (another window) — sharing it`);
      context.workspaceState.update('opencodeBridge.port', port);
      return;
    }
    throw new Error(`cannot listen on ${host}:${port} (${(e && e.message) || e}). ` +
      `Pick a free port via the opencodeBridge.port setting (and matching VSCODE_BRIDGE_PORT).`);
  }
  try { fs.writeFileSync(portFilePath(), String(port) + '\n'); } catch (e) {
    output?.appendLine('[bridge] warning: cannot write port file: ' + String((e && e.message) || e));
  }
  output?.appendLine(`[bridge] listening on http://${host}:${port} (token file: ${tokenFilePath()})`);
  context.workspaceState.update('opencodeBridge.port', port);
}

function stopServer() {
  if (server) { try { server.close(); } catch (_) {} server = null; }
}

/** @param {import('vscode').ExtensionContext} context */
async function activate(context) {
  const vscode = require('vscode');
  output = vscode.window.createOutputChannel('OpenCode Bridge');
  context.subscriptions.push(
    vscode.commands.registerCommand('opencodeBridge.restart', async () => { await startServer(vscode, context); vscode.window.showInformationMessage('OpenCode Bridge restarted.'); }),
    vscode.commands.registerCommand('opencodeBridge.status', async () => {
      const { port, host } = getSettings(vscode);
      vscode.window.showInformationMessage(`OpenCode Bridge: http://${host}:${port} — ${vscode.workspace.textDocuments.length} open docs. Token: ${tokenFilePath()}`);
    }),
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('opencodeBridge')) startServer(vscode, context).catch((err) => output?.appendLine('[bridge] restart failed: ' + err));
    }),
  );
  await startServer(vscode, context);
}

function deactivate() { stopServer(); }

module.exports = { activate, deactivate };
