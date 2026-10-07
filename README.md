# VSCode Bridge for OpenCode

Lets OpenCode **read and write files through VSCode** — including unsaved editor buffers — via a localhost HTTP bridge plus an MCP server.

```
OpenCode agent → MCP stdio → vscode-bridge-mcp.mjs → HTTP 127.0.0.1:37651 → VSCode extension → editors / workspace fs
                                                  ↑
CLI: vscode-bridge.mjs ──────────────────────────┘ (manual testing)
```

## Layout (all files at branch root)

| Path | What |
|---|---|
| `extension.js` + `package.json` | VSCode extension source (zero deps). Runs the HTTP server. |
| `opencode-bridge-0.1.3.vsix` | Prebuilt extension package for offline install. |
| `vscode-bridge-mcp.mjs` | MCP stdio server exposing `vscode_*` tools. |
| `vscode-bridge.mjs` | CLI for manual testing (`status`, `list`, `read`, `write`, `open`, `save`). |
| `install.ps1` | Generates token, installs extension, registers MCP globally. |
| `opencode.jsonc.snippet` | Manual MCP config if you prefer editing config by hand. |

## HTTP API (extension, localhost only)

- `GET /status` — no auth. Workspace folders, open count, active file.
- `GET /open-files` — auth. `[{ fsPath, uri, fileName, languageId, isActive, isDirty, isUntitled }]`.
- `POST /read { target }` — editor buffer if open (includes unsaved), else disk.
- `POST /write { target, content, reveal?, save? }` — full-file replace in editor; `save=true` writes to disk.
- `POST /open { target, preview? }`
- `POST /save { target?, all? }`

`target` = absolute path, workspace-relative path, or `file://`/`untitled:` URI. Auth header: `x-bridge-token: <token>` (or `Authorization: Bearer <token>`).

## Setup (any computer)

Prerequisites on the new machine: **Node.js 18+**, **VSCode** (with the `code` CLI on PATH), **OpenCode**.

1. Extract this zip anywhere, e.g. `C:\Tools\vscode-bridge`.
2. Run the installer (it checks prerequisites, creates the token, installs the
   extension, registers the MCP server globally, and verifies the bridge):

```powershell
powershell -ExecutionPolicy Bypass -File "C:\\Tools\\vscode-bridge\\install.ps1"
```

3. Open VSCode, then check the **OpenCode Bridge** output channel: `listening on http://127.0.0.1:37651`.

Manual alternative (same steps the script automates, with `<bridge>` = your extracted folder):

1. Package and install the extension:
   ```powershell
   cd "<bridge>"
   npx.cmd --yes @vscode/vsce package --no-dependencies
   code --install-extension opencode-bridge-*.vsix --force
   ```
   (Use `npx.cmd`, not `npx.ps1`, if PowerShell script execution is restricted.
   A prebuilt `.vsix` is included, so this also works offline.)
2. Reload VSCode. A token is created at `%USERPROFILE%\.config\opencode\vscode-bridge.token` (or pre-create it so MCP/CLI match before first run).
3. Register MCP: `opencode mcp add vscode --global -- node "<bridge>\vscode-bridge-mcp.mjs"`

> Note: the extension declares `capabilities.untrustedWorkspaces.supported` so it loads
> in single-file / empty-window sessions, which VS Code may otherwise treat as untrusted
> and silently refuse to activate extensions in. Without that declaration the bridge
> server never starts and every client fails with `ECONNREFUSED`.

## Usage

```powershell
node "<bridge>\vscode-bridge.mjs" status
node "<bridge>\vscode-bridge.mjs" list
node "<bridge>\vscode-bridge.mjs" read C:\path\to\file.txt
echo "new content" | node "<bridge>\vscode-bridge.mjs" write C:\path\to\file.txt --save
```
(`<bridge>` = the folder you extracted this to.)

In OpenCode, use MCP tools: `vscode_status`, `vscode_list_open`, `vscode_read`, `vscode_write`, `vscode_open`, `vscode_save`.

## Config / env

| Env | Default | Meaning |
|---|---|---|
| `VSCODE_BRIDGE_PORT` | `37651` (or port file) | Bridge port. Overrides the auto-discovered port file. Set the same value in VSCode setting `opencodeBridge.port` when changing it. |
| `VSCODE_BRIDGE_HOST` | `127.0.0.1` | Bind/host. Keep loopback (the extension warns in its output channel otherwise). |
| `VSCODE_BRIDGE_TOKEN` | (token file) | Inline override; otherwise read from token file. Re-read per request, so rotation needs no restart. |
| `VSCODE_BRIDGE_TOKEN_FILE` | `~/.config/opencode/vscode-bridge.token` | Shared secret location. |
| `VSCODE_BRIDGE_TIMEOUT_MS` | `30000` | HTTP timeout for MCP server and CLI. |

The extension writes its actual port to `~/.config/opencode/vscode-bridge.port` on startup;
MCP/CLI discover it automatically unless `VSCODE_BRIDGE_PORT` is set.

VSCode settings: `opencodeBridge.port`, `opencodeBridge.host`, `opencodeBridge.enabled`. Commands: *OpenCode Bridge: Restart server / Show status*.

## Limits (fail fast, by design)

- Reads: files / editor buffers over 8 MB are refused (narrow the target instead).
- Writes: content over 10 MB is refused client- and server-side (split the write).
- `vscode_read` truncates at `maxChars` (default 100000; raise per call if needed).
- Binary content (NUL bytes) is refused — text transport only.
- Saving an untitled document is refused (VSCode would pop a Save-As dialog).

## Multiple windows

Only one bridge owns the port per machine. A second window probes the port: if it is
already serving `opencode-bridge` (same token), it shares it (reported as `"shared": true`
in `/status`) instead of crashing. Note the bridge reflects the owning window's editors —
for predictable results, keep the files you work with open in that window.

## Security

Localhost-only server, token required for everything except `/status`. Token file is created `0600` where supported. Do not expose the port or commit the token. The bridge can read/write any file the VSCode process can — that is the point, so keep the token local.

## Troubleshooting

- `401 unauthorized` → token mismatch. The extension and MCP/CLI must read the same token file (or `VSCODE_BRIDGE_TOKEN`). Delete the token file and reload VSCode + re-run install to regenerate consistently.
- `fetch failed / connection refused` → VSCode not running, extension not installed, or wrong port. Check *Output → OpenCode Bridge*.
- MCP shows `disconnected` → run `opencode mcp list`; test the MCP server directly: `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node vscode-bridge-mcp.mjs`.
- Port in use by our own bridge (second VSCode window) → the newcomer shares it and
  `/status` reports `"shared": true`. The bridge reflects the owning window's editors.
- Port in use by something else → the extension logs a clear error naming the port.
  Set `opencodeBridge.port` in VSCode settings and matching `VSCODE_BRIDGE_PORT` env for MCP/CLI.
