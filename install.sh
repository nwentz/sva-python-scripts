#!/usr/bin/env bash
# OpenCode -> VSCode bridge install (macOS / Linux).
# Portable: run from this folder. No hardcoded paths.
# Usage: bash install.sh
set -u
BRIDGE_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_SERVER="$BRIDGE_DIR/vscode-bridge-mcp.mjs"
TOKEN_FILE="${VSCODE_BRIDGE_TOKEN_FILE:-$HOME/.config/opencode/vscode-bridge.token}"

echo '== 0. Prerequisites =='
for cmd in node code opencode; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' not found on PATH." >&2
    echo "Install Node.js 18+, VSCode (run 'Shell Command: Install code command in PATH'" >&2
    echo "from VSCode's command palette), and OpenCode, then re-run." >&2
    exit 1
  fi
done
NODE_MAJOR="$(node --version | sed 's/^v\([0-9]*\)\..*/\1/')"
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: Node.js 18+ required (found $(node --version))." >&2
  exit 1
fi
echo "node $(node --version), code + opencode present."

echo ''
echo '== 1. Bridge token =='
mkdir -p "$(dirname "$TOKEN_FILE")"
if [ ! -f "$TOKEN_FILE" ]; then
  node -e "console.log(require('crypto').randomBytes(32).toString('hex'))" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "Generated token at $TOKEN_FILE"
else
  echo "Token exists: $TOKEN_FILE"
fi

echo ''
echo '== 2. Package + install VSCode extension =='
VSIX=""
if (cd "$BRIDGE_DIR" && npx --yes @vscode/vsce package --no-dependencies); then
  echo "Packaged with vsce."
else
  echo "vsce packaging failed -- falling back to prebuilt vsix."
fi
# Newest vsix wins (freshly packaged or prebuilt).
# shellcheck disable=SC2012
VSIX="$(ls -t "$BRIDGE_DIR"/opencode-bridge-*.vsix 2>/dev/null | head -n 1)"
if [ -z "$VSIX" ]; then
  echo "ERROR: no opencode-bridge-*.vsix in $BRIDGE_DIR and packaging failed (network needed for vsce)." >&2
  exit 1
fi
code --install-extension "$VSIX" --force
echo 'Extension installed. Restart VSCode (or: Developer: Reload Window).'
echo 'Check output channel: OpenCode Bridge (expect: listening on http://127.0.0.1:37651).'

echo ''
echo '== 3. Register MCP server with OpenCode (global) =='
if opencode mcp add vscode --global -- node "$MCP_SERVER"; then
  echo "MCP server registered."
else
  echo "mcp add reported an issue (a 'vscode' server may already be registered -- that is fine)."
  echo "To re-register cleanly, remove the old entry from your opencode config and re-run."
fi

echo ''
echo '== 4. Verify bridge =='
UP=0
for i in 1 2 3 4 5 6; do
  if node "$BRIDGE_DIR/vscode-bridge.mjs" status 2>/dev/null | grep -q '"ok": true'; then
    UP=1
    break
  fi
  if [ "$i" -lt 6 ]; then sleep 5; fi
done
if [ "$UP" -eq 1 ]; then
  echo 'Bridge is UP:'
  node "$BRIDGE_DIR/vscode-bridge.mjs" status
else
  echo 'WARNING: bridge is not responding. Open VSCode and check:'
  echo '  - Output channel "OpenCode Bridge" (expect: listening on http://127.0.0.1:37651)'
  echo "  - Token file matches: $TOKEN_FILE"
  echo "  - Then re-run: node \"$BRIDGE_DIR/vscode-bridge.mjs\" status"
fi
echo ''
echo 'Done.'
