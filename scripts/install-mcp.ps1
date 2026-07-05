# MCP-only install: template -> ~/.config/ai/mcp-servers.json + wrapper.
param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = 'Stop'

$AiConfigDir = Join-Path $env:USERPROFILE '.config\ai'
$SkillTarget = Join-Path $env:USERPROFILE '.agents\skills\unified-mcp'
$EnvFile = Join-Path $AiConfigDir '.env'
$CanonicalPath = Join-Path $AiConfigDir 'mcp-servers.json'
$TemplatePath = Join-Path $RepoRoot 'config\mcp-servers.template.json'

function Read-DotEnv {
    param([string]$Path)
    $vars = @{}
    if (-not (Test-Path $Path)) { return $vars }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        if ($line -match '^([^=]+)=(.*)$') { $vars[$Matches[1].Trim()] = $Matches[2].Trim() }
    }
    return $vars
}

function Resolve-CodegraphShim {
    $path = Join-Path $env:APPDATA 'npm\node_modules\@colbymchenry\codegraph\npm-shim.js'
    if (Test-Path $path) { return $path }
    throw 'codegraph not found. Install: npm install -g @colbymchenry/codegraph'
}

function Expand-Template {
    param([string]$Json, [hashtable]$Vars)
    $result = $Json
    foreach ($entry in $Vars.GetEnumerator()) {
        $result = $result.Replace("{{$($entry.Key)}}", $entry.Value)
    }
    return $result
}

if (-not (Test-Path $AiConfigDir)) {
    New-Item -ItemType Directory -Path $AiConfigDir -Force | Out-Null
}

if (-not (Test-Path $EnvFile)) {
    Copy-Item (Join-Path $RepoRoot '.env.example') $EnvFile
    Write-Host "  created $EnvFile"
}

if (-not (Test-Path $CanonicalPath)) {
    $envVars = Read-DotEnv $EnvFile
    $expanded = Expand-Template -Json (Get-Content $TemplatePath -Raw) -Vars @{
        POSTGRES_MCP_URL = $(if ($envVars['POSTGRES_MCP_URL']) { $envVars['POSTGRES_MCP_URL'] } else { 'postgresql://user:password@localhost:5432/dbname' })
        CODEGRAPH_SHIM   = (Resolve-CodegraphShim)
    }
    Set-Content -Path $CanonicalPath -Value $expanded -Encoding UTF8
    Write-Host "  generated $CanonicalPath"
}

$wrapper = @"
pwsh -NoProfile -ExecutionPolicy Bypass -File "`$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" @args
"@
Set-Content -Path (Join-Path $AiConfigDir 'sync-mcp.ps1') -Value $wrapper -Encoding UTF8

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\sync-mcp.ps1') -Action Sync