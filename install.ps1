# OpenCode -> VSCode bridge install (Windows PowerShell)
# Portable: extract this folder anywhere and run this script. No hardcoded paths.
$ErrorActionPreference = 'Stop'
$BridgeRoot = $PSScriptRoot
$McpServer = Join-Path $BridgeRoot 'vscode-bridge-mcp.mjs'
$TokenFile = if ($env:VSCODE_BRIDGE_TOKEN_FILE) { $env:VSCODE_BRIDGE_TOKEN_FILE } else { Join-Path $HOME '.config\opencode\vscode-bridge.token' }
$ExtDir = $BridgeRoot

Write-Output '== 0. Prerequisites =='
foreach ($cmd in @('node', 'code', 'opencode')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required command '$cmd' not found on PATH. Install Node.js 18+, VSCode (with the 'code' CLI), and OpenCode, then re-run."
  }
}
$nodeMajor = (& node --version) -replace '^v(\d+)\..*', '$1'
if ([int]$nodeMajor -lt 18) { throw "Node.js 18+ required (found $(& node --version))." }
Write-Output "node $(& node --version), code + opencode present."

Write-Output '== 1. Bridge token =='
New-Item -ItemType Directory -Force -Path (Split-Path $TokenFile) | Out-Null
if (-not (Test-Path $TokenFile)) {
  $bytes = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $tok = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  Set-Content -Path $TokenFile -Value ($tok + "`n")
  Write-Output "Generated token at $TokenFile"
} else { Write-Output "Token exists: $TokenFile" }

Write-Output ''
Write-Output '== 2. Package + install VSCode extension =='
Push-Location $ExtDir
try {
  # NOTE: npx.cmd (not npx.ps1) -- PowerShell script execution is often restricted.
  try {
    & npx.cmd --yes @vscode/vsce package --no-dependencies
  } catch {
    Write-Output "vsce packaging failed -- falling back to prebuilt vsix: $($_.Exception.Message)"
  }
  $Vsix = Get-ChildItem (Join-Path $ExtDir 'opencode-bridge-*.vsix') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
  if (-not $Vsix) { throw "No opencode-bridge-*.vsix in $ExtDir and packaging failed (network needed for vsce)." }
  & code --install-extension $Vsix --force
} finally { Pop-Location }
Write-Output 'Extension installed. Restart VSCode (or: Developer: Reload Window).'
Write-Output 'Check output channel: OpenCode Bridge (expect: listening on http://127.0.0.1:37651).'

Write-Output ''
Write-Output '== 3. Register MCP server with OpenCode (global) =='
try {
  & opencode mcp add vscode --global -- node $McpServer
} catch {
  Write-Output "mcp add reported an issue (a 'vscode' server may already be registered -- that is fine): $($_.Exception.Message)"
  Write-Output "To re-register cleanly, remove the old entry from your opencode config and re-run."
}
Write-Output ''
Write-Output '== 4. Verify bridge =='
$BridgeCli = Join-Path $BridgeRoot 'vscode-bridge.mjs'
$up = $false
for ($i = 1; $i -le 6; $i++) {
  try {
    $r = & node $BridgeCli status 2>$null | Out-String
    if ($r -match '"ok": true') { $up = $true; break }
  } catch {}
  if ($i -lt 6) { Start-Sleep 5 }
}
if ($up) {
  Write-Output 'Bridge is UP:'
  Write-Output $r
} else {
  Write-Output 'WARNING: bridge is not responding. Open VSCode and check:'
  Write-Output '  - Output channel "OpenCode Bridge" (expect: listening on http://127.0.0.1:37651)'
  Write-Output '  - Token file matches: ' + $TokenFile
  Write-Output "  - Then re-run: node `"$BridgeCli`" status"
}
Write-Output ''
Write-Output 'Done.'
