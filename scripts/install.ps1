# Full install: MCP + skills + OpenCode + Grok compat config.
# Usage: pwsh scripts/install.ps1 [-SkipExternalSkills] [-SkipMcp]

param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$SkipExternalSkills,
    [switch]$SkipMcp
)

$ErrorActionPreference = 'Stop'

Write-Host "Installing unified-ai-tooling from $RepoRoot"

# 1. Skills (custom always; external via npx unless skipped)
$skillArgs = @('-File', (Join-Path $RepoRoot 'scripts\sync-skills.ps1'))
if ($SkipExternalSkills) { $skillArgs += '-CustomOnly' }
& pwsh -NoProfile -ExecutionPolicy Bypass @skillArgs

# 2. MCP
if (-not $SkipMcp) {
    $mcpInstall = Join-Path $RepoRoot 'scripts\install-mcp.ps1'
    if (Test-Path $mcpInstall) {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $mcpInstall -RepoRoot $RepoRoot
    }
    else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\sync-mcp.ps1') -Action Sync
    }
}

# 3. OpenCode orchestration -> %APPDATA%\orca\opencode-hooks\shared\
$orcaShared = Join-Path $env:APPDATA 'orca\opencode-hooks\shared'
if (-not (Test-Path $orcaShared)) {
    New-Item -ItemType Directory -Path $orcaShared -Force | Out-Null
}
foreach ($file in @('oh-my-opencode-slim.json', 'opencode.json')) {
    $src = Join-Path $RepoRoot "opencode\$file"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $orcaShared $file) -Force
        Write-Host "  opencode -> $(Join-Path $orcaShared $file)"
    }
}

# 4. Grok config.template.toml -> merge [compat.*] if missing
$grokConfig = Join-Path $env:USERPROFILE '.grok\config.toml'
$grokTemplate = Join-Path $RepoRoot 'grok\config.template.toml'
if (Test-Path $grokTemplate) {
    if (-not (Test-Path $grokConfig)) {
        Copy-Item $grokTemplate $grokConfig
        Write-Host "  grok -> $grokConfig (created)"
    }
    elseif ((Get-Content $grokConfig -Raw) -notmatch '\[compat\.cursor\]') {
        Add-Content $grokConfig "`n# unified-ai-tooling compat`n"
        Get-Content $grokTemplate -Raw | Select-String -Pattern '\[compat\..*\][\s\S]*' -AllMatches |
            ForEach-Object { $_.Matches } | ForEach-Object { Add-Content $grokConfig $_.Value }
        Write-Host "  grok -> $grokConfig (compat added)"
    }
    else {
        Write-Host "  grok -> $grokConfig (kept)"
    }
}

# 5. Orca hooks check
$orcaHooks = Join-Path $env:USERPROFILE '.orca\agent-hooks'
if (-not (Test-Path $orcaHooks)) {
    Write-Warning 'Orca hooks not found at ~/.orca/agent-hooks — install Orca for unified agent hooks'
}
else {
    Write-Host "  hooks -> $orcaHooks (orca, ok)"
}

Write-Host ''
Write-Host 'Done. Components:'
Write-Host '  skills  -> ~/.agents/skills/'
Write-Host '  mcp     -> ~/.config/ai/ + all AI tools'
Write-Host '  opencode -> %APPDATA%/orca/opencode-hooks/shared/'
Write-Host '  grok    -> ~/.grok/config.toml [compat]'