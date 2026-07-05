# Audit AI tooling setup: compare canonical/repo vs what each tool has installed.
# Usage:
#   pwsh scripts/audit-setup.ps1
#   pwsh scripts/audit-setup.ps1 -Json   # machine-readable only

param(
    [switch]$Json,
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

$AiConfigDir = Join-Path $env:USERPROFILE '.config\ai'
$ReportPath = Join-Path $AiConfigDir 'audit-report.json'

function Expand-HomePath {
    param([string]$Path)
    $p = $Path -replace '%APPDATA%', $env:APPDATA
    if ($p -match '^~[\\/]') { return Join-Path $env:USERPROFILE $p.Substring(2) }
    return $p
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return Get-Content $Path -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Get-FileFingerprint {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content $Path -Raw
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
}

function Get-JsonFingerprint {
    param($Object)
    if ($null -eq $Object) { return $null }
    ($Object | ConvertTo-Json -Depth 20 -Compress) | ForEach-Object {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($_)
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLower()
    }
}

function Get-InstalledSkillNames {
    $dir = Join-Path $env:USERPROFILE '.agents\skills'
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Directory | ForEach-Object { $_.Name } | Sort-Object)
}

function Get-ExpectedCustomSkills {
    $customDir = Join-Path $RepoRoot 'skills\custom'
    if (-not (Test-Path $customDir)) { return @() }
    return @(Get-ChildItem $customDir -Directory | ForEach-Object { $_.Name } | Sort-Object)
}

function Get-ExpectedExternalSkills {
    $manifest = Join-Path $RepoRoot 'skills\external.manifest.json'
    if (-not (Test-Path $manifest)) { return @() }
    $data = Read-JsonFile $manifest
    return @($data.skills | ForEach-Object { $_.name } | Sort-Object)
}

function Get-McpServerNamesFromFile {
    param([string]$Path, [string]$Format)
    $data = Read-JsonFile $Path
    if (-not $data) { return @() }
    $names = @()
    switch ($Format) {
        'cursor' { if ($data.mcpServers) { $names = @($data.mcpServers.PSObject.Properties.Name) } }
        'cursor-nested' { if ($data.mcpServers) { $names = @($data.mcpServers.PSObject.Properties.Name) } }
        'opencode' {
            if ($data.mcp) {
                $names = @($data.mcp.PSObject.Properties | Where-Object { $_.Value.enabled -ne $false } | ForEach-Object { $_.Name })
            }
        }
    }
    return @($names | Sort-Object)
}

function Test-GrokCompat {
    $path = Join-Path $env:USERPROFILE '.grok\config.toml'
    if (-not (Test-Path $path)) {
        return @{ exists = $false; cursorMcps = $false; cursorSkills = $false; inSync = $false }
    }
    $content = Get-Content $path -Raw
    return @{
        exists       = $true
        configPath   = $path
        cursorMcps   = $content -match '\[compat\.cursor\]' -and $content -match 'mcps\s*=\s*true'
        cursorSkills = $content -match '\[compat\.cursor\]' -and $content -match 'skills\s*=\s*true'
        inSync       = ($content -match '\[compat\.cursor\]') -and ($content -match 'mcps\s*=\s*true') -and ($content -match 'skills\s*=\s*true')
    }
}

function Test-HooksPresence {
    $orcaDir = Join-Path $env:USERPROFILE '.orca\agent-hooks'
    $agents = @('cursor', 'grok', 'antigravity', 'claude', 'gemini')
    $present = @{}
    foreach ($a in $agents) {
        $hook = Join-Path $orcaDir "$a-hook.cmd"
        if ($a -eq 'gemini') { $hook = Join-Path $orcaDir 'gemini-hook.cmd' }
        $present[$a] = Test-Path $hook
    }
    return @{
        orcaDir    = $orcaDir
        orcaExists = Test-Path $orcaDir
        agents     = $present
        cursorJson = Test-Path (Join-Path $env:USERPROFILE '.cursor\hooks.json')
        grokJson   = Test-Path (Join-Path $env:USERPROFILE '.grok\hooks\orca-status.json')
        geminiHooks = $null -ne $( $s = Read-JsonFile (Join-Path $env:USERPROFILE '.gemini\settings.json'); if ($s) { $s.hooks } )
        inSync     = (Test-Path $orcaDir) -and $present['cursor'] -and $present['grok']
    }
}

# --- MCP audit (inline, same targets as sync-mcp.ps1) ---
$mcpCanonicalPath = Join-Path $AiConfigDir 'mcp-servers.json'
$canonicalMcp = Read-JsonFile $mcpCanonicalPath
$canonicalMcpNames = @()
if ($null -ne $canonicalMcp -and $null -ne $canonicalMcp.mcpServers) {
    $canonicalMcpNames = @($canonicalMcp.mcpServers.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
}

$mcpTools = [ordered]@{
    cursor      = @{ label = 'Cursor';      path = Expand-HomePath '~/.cursor/mcp.json';                    format = 'cursor' }
    opencode    = @{ label = 'OpenCode';    path = Expand-HomePath '~/.config/opencode/opencode.json';       format = 'opencode' }
    antigravity = @{ label = 'Antigravity'; path = Expand-HomePath '~/.gemini/config/mcp_config.json';       format = 'cursor' }
    'gemini-cli'= @{ label = 'Gemini CLI';  path = Expand-HomePath '~/.gemini/settings.json';                format = 'cursor-nested' }
    grok        = @{ label = 'Grok';        follows = Expand-HomePath '~/.cursor/mcp.json'; note = 'compat.cursor.mcps' }
}

$mcpAudit = [ordered]@{}
$cursorMcpNames = @()
foreach ($entry in $mcpTools.GetEnumerator()) {
    $id = $entry.Key
    $t = $entry.Value
    if ($id -eq 'grok') {
        $missing = @($canonicalMcpNames | Where-Object { $_ -notin $cursorMcpNames })
        $extra = @($cursorMcpNames | Where-Object { $_ -notin $canonicalMcpNames })
        $mcpAudit[$id] = [ordered]@{
            label = $t.label; follows = $t.follows; note = $t.note
            servers = $cursorMcpNames; inSync = (-not $missing.Count -and -not $extra.Count)
            missingHere = $missing; extraHere = $extra
        }
        continue
    }
    $names = Get-McpServerNamesFromFile -Path $t.path -Format $t.format
    if ($id -eq 'cursor') { $cursorMcpNames = $names }
    $missing = @($canonicalMcpNames | Where-Object { $_ -notin $names })
    $extra = @($names | Where-Object { $_ -notin $canonicalMcpNames })
    $mcpAudit[$id] = [ordered]@{
        label = $t.label; configPath = $t.path; servers = $names
        serverCount = $names.Count; inSync = (-not $missing.Count -and -not $extra.Count)
        missingHere = $missing; extraHere = $extra; configExists = (Test-Path $t.path)
    }
}

# --- Skills audit ---
$installedSkills = Get-InstalledSkillNames
$expectedCustom = Get-ExpectedCustomSkills
$expectedExternal = Get-ExpectedExternalSkills
$expectedAll = @($expectedCustom + $expectedExternal | Sort-Object -Unique)

$skillsAudit = [ordered]@{
    installedDir   = Expand-HomePath '~/.agents/skills'
    installed      = $installedSkills
    expectedCustom = $expectedCustom
    expectedExternal = $expectedExternal
    missingCustom  = @($expectedCustom | Where-Object { $_ -notin $installedSkills })
    missingExternal = @($expectedExternal | Where-Object { $_ -notin $installedSkills })
    extraInstalled = @($installedSkills | Where-Object { $_ -notin $expectedAll })
    inSync         = (-not @($expectedCustom | Where-Object { $_ -notin $installedSkills }).Count)
}

# --- OpenCode audit ---
$orcaShared = Join-Path $env:APPDATA 'orca\opencode-hooks\shared'
$opencodeFiles = @('oh-my-opencode-slim.json', 'opencode.json')
$opencodeAudit = [ordered]@{}
foreach ($file in $opencodeFiles) {
    $installed = Join-Path $orcaShared $file
    $repo = Join-Path $RepoRoot "opencode\$file"
    $installedJson = Read-JsonFile $installed
    $repoJson = Read-JsonFile $repo
    $opencodeAudit[$file] = [ordered]@{
        installedPath = $installed
        repoPath      = $repo
        installedExists = (Test-Path $installed)
        repoExists    = (Test-Path $repo)
        inSync        = (Get-JsonFingerprint $installedJson) -eq (Get-JsonFingerprint $repoJson)
        preset        = $installedJson.preset
    }
}

# --- Grok + Hooks ---
$grokAudit = Test-GrokCompat
$hooksAudit = Test-HooksPresence

# --- Summary ---
$issues = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path $mcpCanonicalPath)) { $issues.Add('mcp: canonical mcp-servers.json missing') }
foreach ($entry in $mcpAudit.GetEnumerator()) {
    if (-not $entry.Value.inSync) { $issues.Add("mcp/$($entry.Key): out of sync") }
}
if ($skillsAudit.missingCustom.Count) { $issues.Add("skills: missing custom: $($skillsAudit.missingCustom -join ', ')") }
if ($skillsAudit.missingExternal.Count) { $issues.Add("skills: missing external: $($skillsAudit.missingExternal -join ', ')") }
foreach ($entry in $opencodeAudit.GetEnumerator()) {
    if (-not $entry.Value.inSync) { $issues.Add("opencode/$($entry.Key): differs from repo") }
}
if (-not $grokAudit.inSync) { $issues.Add('grok: compat.cursor not fully enabled') }
if (-not $hooksAudit.inSync) { $issues.Add('hooks: orca hooks incomplete') }

$report = [ordered]@{
    version     = 1
    auditedAt   = (Get-Date).ToString('o')
    repoRoot    = $RepoRoot
    overallInSync = ($issues.Count -eq 0)
    issueCount  = $issues.Count
    issues      = $issues
    components  = [ordered]@{
        mcp      = [ordered]@{ canonical = $canonicalMcpNames; canonicalPath = $mcpCanonicalPath; tools = $mcpAudit }
        skills   = $skillsAudit
        opencode = $opencodeAudit
        grok     = $grokAudit
        hooks    = $hooksAudit
    }
}

if (-not (Test-Path $AiConfigDir)) { New-Item -ItemType Directory -Path $AiConfigDir -Force | Out-Null }
$report | ConvertTo-Json -Depth 12 | Set-Content -Path $ReportPath -Encoding UTF8

if ($Json) {
    Get-Content $ReportPath -Raw
    exit $(if ($report.overallInSync) { 0 } else { 1 })
}

Write-Host "AI Setup Audit — $(if ($report.overallInSync) { 'ALL IN SYNC' } else { "$($issues.Count) issue(s)" })"
Write-Host "Report: $ReportPath"
Write-Host ''

Write-Host ("MCP (canonical: {0})" -f ($canonicalMcpNames -join ', '))
foreach ($entry in $mcpAudit.GetEnumerator()) {
    $s = if ($entry.Value.inSync) { 'ok' } else { 'DRIFT' }
    Write-Host ("  [{0}] {1,-12} servers={2} missing={3} extra={4}" -f $s, $entry.Key, ($entry.Value.servers -join ','), ($entry.Value.missingHere -join ','), ($entry.Value.extraHere -join ','))
}

Write-Host ''
Write-Host 'Skills'
Write-Host ("  installed={0}" -f ($installedSkills -join ', '))
if ($skillsAudit.missingCustom.Count) { Write-Host ("  missing custom: {0}" -f ($skillsAudit.missingCustom -join ', ')) }
if ($skillsAudit.missingExternal.Count) { Write-Host ("  missing external: {0}" -f ($skillsAudit.missingExternal -join ', ')) }
if ($skillsAudit.extraInstalled.Count) { Write-Host ("  extra local: {0}" -f ($skillsAudit.extraInstalled -join ', ')) }

Write-Host ''
Write-Host 'OpenCode'
foreach ($entry in $opencodeAudit.GetEnumerator()) {
    $s = if ($entry.Value.inSync) { 'ok' } else { 'DRIFT' }
    Write-Host ("  [{0}] {1} preset={2}" -f $s, $entry.Key, $entry.Value.preset)
}

Write-Host ''
Write-Host ("Grok compat: {0}" -f $(if ($grokAudit.inSync) { 'ok' } else { 'DRIFT' }))
Write-Host ("Hooks orca:  {0}" -f $(if ($hooksAudit.inSync) { 'ok' } else { 'DRIFT' }))

if ($issues.Count) {
    Write-Host ''
    Write-Host 'Issues:'
    $issues | ForEach-Object { Write-Host "  - $_" }
    Write-Host ''
    Write-Host 'Fix: pwsh scripts/install.ps1  or  pwsh scripts/sync-mcp.ps1 -Action Sync'
}

exit $(if ($report.overallInSync) { 0 } else { 1 })