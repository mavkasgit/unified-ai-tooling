# Install unified-mcp from this repo to local AI tool paths.
# Usage:
#   pwsh scripts/install.ps1
#   pwsh scripts/install.ps1 -RepoRoot C:\path\to\unified-mcp

param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

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
        if ($line -match '^([^=]+)=(.*)$') {
            $vars[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $vars
}

function Resolve-CodegraphShim {
    $candidates = @(
        (Join-Path $env:APPDATA 'npm\node_modules\@colbymchenry\codegraph\npm-shim.js'),
        (Join-Path $env:USERPROFILE 'AppData\Roaming\npm\node_modules\@colbymchenry\codegraph\npm-shim.js')
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
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

Write-Host "Installing unified-mcp from $RepoRoot"

# 1. Skill + scripts -> ~/.agents/skills/unified-mcp
if (Test-Path $SkillTarget) {
    Remove-Item $SkillTarget -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $SkillTarget 'scripts') -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'skill\SKILL.md') (Join-Path $SkillTarget 'SKILL.md') -Force
Copy-Item (Join-Path $RepoRoot 'scripts\sync-mcp.ps1') (Join-Path $SkillTarget 'scripts\sync-mcp.ps1') -Force
Write-Host "  skill -> $SkillTarget"

# 2. Config dir
if (-not (Test-Path $AiConfigDir)) {
    New-Item -ItemType Directory -Path $AiConfigDir -Force | Out-Null
}

# 3. .env.example copy if no .env
if (-not (Test-Path $EnvFile)) {
    Copy-Item (Join-Path $RepoRoot '.env.example') $EnvFile
    Write-Host "  created $EnvFile (edit before first sync)"
}

# 4. Generate mcp-servers.json from template (only if missing)
if (-not (Test-Path $CanonicalPath)) {
    $envVars = Read-DotEnv $EnvFile
    $postgresUrl = $envVars['POSTGRES_MCP_URL']
    if (-not $postgresUrl) {
        $postgresUrl = 'postgresql://user:password@localhost:5432/dbname'
    }
    $templateVars = @{
        POSTGRES_MCP_URL = $postgresUrl
        CODEGRAPH_SHIM   = (Resolve-CodegraphShim)
    }
    $templateJson = Get-Content $TemplatePath -Raw
    $expanded = Expand-Template -Json $templateJson -Vars $templateVars
    Set-Content -Path $CanonicalPath -Value $expanded -Encoding UTF8
    Write-Host "  generated $CanonicalPath"
}
else {
    Write-Host "  kept existing $CanonicalPath"
}

# 5. Wrapper script
$wrapper = @"
# Thin wrapper — logic in unified-mcp skill (installed from GitHub).
pwsh -NoProfile -ExecutionPolicy Bypass -File "`$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" @args
"@
Set-Content -Path (Join-Path $AiConfigDir 'sync-mcp.ps1') -Value $wrapper -Encoding UTF8
Write-Host "  wrapper -> $(Join-Path $AiConfigDir 'sync-mcp.ps1')"

Write-Host ''
Write-Host 'Done. Next steps:'
Write-Host "  1. Edit $EnvFile (postgres URL, workspace)"
Write-Host '  2. pwsh ~/.config/ai/sync-mcp.ps1 -Action Sync'
Write-Host '  3. Restart AI tools or press r in /mcps'