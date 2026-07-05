# Unified MCP sync: pull from all AI tools -> canonical -> push to all.
# Usage:
#   pwsh ~/.agents/skills/unified-mcp/scripts/sync-mcp.ps1              # pull + push
#   pwsh ~/.agents/skills/unified-mcp/scripts/sync-mcp.ps1 -Action Pull
#   pwsh ~/.agents/skills/unified-mcp/scripts/sync-mcp.ps1 -Action Push
#   pwsh ~/.agents/skills/unified-mcp/scripts/sync-mcp.ps1 -Action Status
#   $env:WORKSPACE_FOLDER = 'C:\path\to\project'; ... -Action Push

param(
    [ValidateSet('Sync', 'Pull', 'Push', 'Status')]
    [string]$Action = 'Sync'
)

$ErrorActionPreference = 'Stop'

$AiConfigDir = Join-Path $env:USERPROFILE '.config\ai'
$CanonicalPath = Join-Path $AiConfigDir 'mcp-servers.json'
$StatePath = Join-Path $AiConfigDir 'environments.json'

if (-not (Test-Path $AiConfigDir)) {
    New-Item -ItemType Directory -Path $AiConfigDir -Force | Out-Null
}

function Expand-HomePath {
    param([string]$Path)
    if ($Path -match '^~[\\/]') {
        return Join-Path $env:USERPROFILE $Path.Substring(2)
    }
    return $Path
}

$ToolTargets = [ordered]@{
    cursor = @{
        label  = 'Cursor'
        path   = Expand-HomePath '~/.cursor/mcp.json'
        format = 'cursor'
    }
    grok = @{
        label  = 'Grok'
        path   = Expand-HomePath '~/.grok/config.toml'
        format = 'grok-compat'
        note   = 'MCP via [compat.cursor] -> ~/.cursor/mcp.json'
    }
    opencode = @{
        label  = 'OpenCode'
        path   = Expand-HomePath '~/.config/opencode/opencode.json'
        format = 'opencode'
    }
    antigravity = @{
        label  = 'Antigravity IDE'
        path   = Expand-HomePath '~/.gemini/config/mcp_config.json'
        format = 'cursor'
    }
    'gemini-cli' = @{
        label  = 'Gemini CLI'
        path   = Expand-HomePath '~/.gemini/settings.json'
        format = 'cursor-nested'
        section = 'mcpServers'
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param([string]$Path, $Object)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Object | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding UTF8
}

function ConvertTo-CanonicalServer {
    param($Server)
    $result = [ordered]@{}
    if ($Server.url) {
        $result.url = [string]$Server.url
        if ($Server.headers) { $result.headers = $Server.headers }
        if ($Server.env) { $result.env = $Server.env }
        return [pscustomobject]$result
    }

    if ($Server.command -is [System.Array]) {
        $cmd = @($Server.command)
        if ($cmd.Count -gt 0) {
            $result.command = [string]$cmd[0]
            if ($cmd.Count -gt 1) {
                $result.args = @($cmd[1..($cmd.Count - 1)] | ForEach-Object { [string]$_ })
            }
        }
    }
    else {
        $result.command = [string]$Server.command
        if ($Server.args) {
            $result.args = @($Server.args | ForEach-Object { [string]$_ })
        }
    }

    if ($Server.env) { $result.env = $Server.env }
    return [pscustomobject]$result
}

function Get-ServersFromTool {
    param($Target)

    $data = Read-JsonFile $Target.path
    if (-not $data) { return @{} }

    $servers = @{}
    switch ($Target.format) {
        'cursor' {
            if ($data.mcpServers) {
                foreach ($prop in $data.mcpServers.PSObject.Properties) {
                    $servers[$prop.Name] = ConvertTo-CanonicalServer $prop.Value
                }
            }
        }
        'cursor-nested' {
            $section = $Target.section
            if ($data.$section) {
                foreach ($prop in $data.$section.PSObject.Properties) {
                    $servers[$prop.Name] = ConvertTo-CanonicalServer $prop.Value
                }
            }
        }
        'opencode' {
            if ($data.mcp) {
                foreach ($prop in $data.mcp.PSObject.Properties) {
                    $entry = $prop.Value
                    if ($entry.enabled -eq $false) { continue }
                    if ($entry.type -eq 'remote' -or $entry.url) {
                        $servers[$prop.Name] = ConvertTo-CanonicalServer ([pscustomobject]@{ url = $entry.url; headers = $entry.headers })
                    }
                    else {
                        $servers[$prop.Name] = ConvertTo-CanonicalServer ([pscustomobject]@{ command = $entry.command })
                    }
                }
            }
        }
        'grok-compat' {
            # Grok reads Cursor config; nothing to parse here.
        }
    }
    return $servers
}

function Expand-McpArg {
    param([string]$Value)
    if ($Value -match '^\$\{([^:}]+)(?::-([^}]*))?\}$') {
        $name = $Matches[1]
        $default = $Matches[2]
        $envValue = [Environment]::GetEnvironmentVariable($name)
        if ($envValue) { return $envValue }
        if ($null -ne $default) { return $default }
    }
    return $Value
}

function ConvertTo-OpenCodeMcp {
    param($CanonicalServers)
    $mcp = [ordered]@{}
    foreach ($entry in $CanonicalServers.GetEnumerator()) {
        $name = $entry.Key
        $server = $entry.Value
        if ($server.url) {
            $mcp[$name] = [ordered]@{
                type    = 'remote'
                url     = $server.url
                enabled = $true
            }
            if ($server.headers) { $mcp[$name].headers = $server.headers }
        }
        else {
            $args = @()
            if ($server.args) {
                foreach ($arg in $server.args) { $args += Expand-McpArg ([string]$arg) }
            }
            $mcp[$name] = [ordered]@{
                type    = 'local'
                command = @($server.command) + $args
                enabled = $true
            }
        }
    }
    return $mcp
}

function Get-CanonicalServers {
    if (-not (Test-Path $CanonicalPath)) {
        return @{}
    }
    $canonical = Read-JsonFile $CanonicalPath
    $servers = @{}
    if ($canonical.mcpServers) {
        foreach ($prop in $canonical.mcpServers.PSObject.Properties) {
            $servers[$prop.Name] = ConvertTo-CanonicalServer $prop.Value
        }
    }
    return $servers
}

function Save-CanonicalServers {
    param($Servers)
    $payload = [ordered]@{
        mcpServers = [ordered]@{}
    }
    foreach ($entry in ($Servers.GetEnumerator() | Sort-Object Name)) {
        $payload.mcpServers[$entry.Key] = $entry.Value
    }
    Write-JsonFile $CanonicalPath ([pscustomobject]$payload)
}

function Merge-Servers {
    param($Base, $Incoming, [string]$SourceLabel)
    $added = @()
    $updated = @()
    foreach ($entry in $Incoming.GetEnumerator()) {
        $name = $entry.Key
        $incomingJson = ($entry.Value | ConvertTo-Json -Depth 8 -Compress)
        if (-not $Base.ContainsKey($name)) {
            $Base[$name] = $entry.Value
            $added += $name
        }
        else {
            $existingJson = ($Base[$name] | ConvertTo-Json -Depth 8 -Compress)
            if ($existingJson -ne $incomingJson) {
                $Base[$name] = $entry.Value
                $updated += $name
            }
        }
    }
    return [pscustomobject]@{
        Added   = $added
        Updated = $updated
    }
}

function Apply-WorkspaceSubstitution {
    param($Servers, [string]$Workspace)
    $clone = @{}
    foreach ($entry in $Servers.GetEnumerator()) {
        $server = $entry.Value | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        if ($server.args) {
            $args = @($server.args)
            for ($i = 0; $i -lt $args.Count; $i++) {
                if ($args[$i] -eq '${workspaceFolder}') {
                    $args[$i] = $Workspace
                }
            }
            $server.args = $args
        }
        $clone[$entry.Key] = $server
    }
    return $clone
}

function Push-ToTool {
    param($Target, $Servers)

    switch ($Target.format) {
        'cursor' {
            Write-JsonFile $Target.path ([pscustomobject]@{ mcpServers = $Servers })
        }
        'cursor-nested' {
            $settings = Read-JsonFile $Target.path
            if (-not $settings) {
                $settings = [pscustomobject]@{}
            }
            $settings | Add-Member -NotePropertyName $Target.section -NotePropertyValue $Servers -Force
            Write-JsonFile $Target.path $settings
        }
        'opencode' {
            $openCode = Read-JsonFile $Target.path
            if (-not $openCode) {
                $openCode = [pscustomobject]@{ '$schema' = 'https://opencode.ai/config.json' }
            }
            $openCode | Add-Member -NotePropertyName 'mcp' -NotePropertyValue (ConvertTo-OpenCodeMcp $Servers) -Force
            Write-JsonFile $Target.path $openCode
        }
        'grok-compat' {
            # Grok uses ~/.cursor/mcp.json via compat; no direct write.
        }
    }
}

function Get-ServerNames {
    param($Servers)
    return @($Servers.Keys | Sort-Object)
}

function Update-StateFile {
    param(
        $CanonicalServers,
        [hashtable]$PerToolServers,
        [string]$LastAction,
        [hashtable]$PullSummary
    )

    $toolState = [ordered]@{}
    foreach ($entry in $ToolTargets.GetEnumerator()) {
        $id = $entry.Key
        $target = $entry.Value

        if ($target.format -eq 'grok-compat') {
            $cursorState = $toolState['cursor']
            $toolState[$id] = [ordered]@{
                label       = $target.label
                configPath  = $target.path
                format      = $target.format
                follows     = (Expand-HomePath '~/.cursor/mcp.json')
                serverCount = $cursorState.serverCount
                servers     = $cursorState.servers
                inSync      = $cursorState.inSync
                missingHere = $cursorState.missingHere
                extraHere   = $cursorState.extraHere
                note        = $target.note
            }
            continue
        }

        $servers = if ($PerToolServers.ContainsKey($id)) { $PerToolServers[$id] } else { @{} }
        $canonicalNames = Get-ServerNames $CanonicalServers
        $toolNames = Get-ServerNames $servers
        $onlyCanonical = @($canonicalNames | Where-Object { $_ -notin $toolNames })
        $onlyTool = @($toolNames | Where-Object { $_ -notin $canonicalNames })

        $toolState[$id] = [ordered]@{
            label        = $target.label
            configPath   = $target.path
            format       = $target.format
            serverCount  = $toolNames.Count
            servers      = $toolNames
            inSync       = ($onlyCanonical.Count -eq 0 -and $onlyTool.Count -eq 0)
            missingHere  = $onlyCanonical
            extraHere    = $onlyTool
        }
        if ($target.note) { $toolState[$id].note = $target.note }
    }

    $state = [ordered]@{
        version       = 1
        updatedAt     = (Get-Date).ToString('o')
        lastAction    = $LastAction
        canonicalPath = $CanonicalPath
        canonical     = [ordered]@{
            serverCount = (Get-ServerNames $CanonicalServers).Count
            servers     = Get-ServerNames $CanonicalServers
        }
        tools         = $toolState
    }

    if ($PullSummary) {
        $state.pullSummary = $PullSummary
    }

    Write-JsonFile $StatePath ([pscustomobject]$state)
}

function Invoke-Pull {
    $canonical = Get-CanonicalServers
    $summary = [ordered]@{}
    $perTool = @{}

    foreach ($entry in $ToolTargets.GetEnumerator()) {
        $id = $entry.Key
        $target = $entry.Value
        if ($target.format -eq 'grok-compat') { continue }

        $toolServers = Get-ServersFromTool $target
        $perTool[$id] = $toolServers
        if ($toolServers.Count -eq 0) {
            $summary[$id] = 'no servers found'
            continue
        }

        $merge = Merge-Servers -Base $canonical -Incoming $toolServers -SourceLabel $target.label
        $parts = @()
        if ($merge.Added.Count) { $parts += "added: $($merge.Added -join ', ')" }
        if ($merge.Updated.Count) { $parts += "updated: $($merge.Updated -join ', ')" }
        if (-not $parts.Count) { $parts += 'unchanged' }
        $summary[$id] = ($parts -join '; ')
    }

    Save-CanonicalServers $canonical
    return [pscustomobject]@{
        Canonical = $canonical
        PerTool   = $perTool
        Summary   = $summary
    }
}

function Invoke-Push {
    param($CanonicalServers)

    $workspace = if ($env:WORKSPACE_FOLDER) { $env:WORKSPACE_FOLDER } else { 'C:\Users\user\VibeCoding\ktm2000' }
    $cursorServers = $CanonicalServers
    $antigravityServers = Apply-WorkspaceSubstitution -Servers $CanonicalServers -Workspace $workspace

    foreach ($entry in $ToolTargets.GetEnumerator()) {
        $id = $entry.Key
        $target = $entry.Value
        if ($target.format -eq 'grok-compat') { continue }

        $payload = if ($id -in @('antigravity', 'gemini-cli')) { $antigravityServers } else { $cursorServers }
        Push-ToTool -Target $target -Servers $payload
        Write-Host "  -> $($target.label): $($target.path)"
    }
}

function Show-Status {
    $canonical = Get-CanonicalServers
    $perTool = @{}
    foreach ($entry in $ToolTargets.GetEnumerator()) {
        if ($entry.Value.format -eq 'grok-compat') { continue }
        $perTool[$entry.Key] = Get-ServersFromTool $entry.Value
    }
    Update-StateFile -CanonicalServers $canonical -PerToolServers $perTool -LastAction 'status'

    Write-Host "Canonical: $CanonicalPath"
    Write-Host "  servers: $((Get-ServerNames $canonical) -join ', ')"
    Write-Host ""
    foreach ($entry in $ToolTargets.GetEnumerator()) {
        $id = $entry.Key
        $target = $entry.Value
        Write-Host "$($target.label) [$id]"
        Write-Host "  path: $($target.path)"
        if ($target.note) { Write-Host "  note: $($target.note)" }
        if ($id -eq 'grok') {
            Write-Host "  follows: ~/.cursor/mcp.json"
            continue
        }
        $toolServers = $perTool[$id]
        if (-not $toolServers -or $toolServers.Count -eq 0) {
            Write-Host "  servers: (none)"
            continue
        }
        $canonicalNames = Get-ServerNames $canonical
        $toolNames = Get-ServerNames $toolServers
        $missing = @($canonicalNames | Where-Object { $_ -notin $toolNames })
        $extra = @($toolNames | Where-Object { $_ -notin $canonicalNames })
        Write-Host "  servers: $($toolNames -join ', ')"
        if ($missing.Count) { Write-Host "  missing: $($missing -join ', ')" }
        if ($extra.Count) { Write-Host "  extra: $($extra -join ', ')" }
        if (-not $missing.Count -and -not $extra.Count) { Write-Host "  status: in sync" }
    }
    Write-Host ""
    Write-Host "State file: $StatePath"
}

# --- main ---
Write-Host "Unified MCP ($Action)"

switch ($Action) {
    'Status' {
        Show-Status
    }
    'Pull' {
        $pull = Invoke-Pull
        Write-Host 'Pull complete:'
        foreach ($entry in $pull.Summary.GetEnumerator()) {
            Write-Host "  $($ToolTargets[$entry.Key].label): $($entry.Value)"
        }
        Update-StateFile -CanonicalServers $pull.Canonical -PerToolServers $pull.PerTool -LastAction 'pull' -PullSummary $pull.Summary
        Write-Host "Canonical updated: $CanonicalPath"
        Write-Host "State updated: $StatePath"
    }
    'Push' {
        $canonical = Get-CanonicalServers
        if ($canonical.Count -eq 0) {
            throw "Canonical MCP config is empty. Run Pull first or edit $CanonicalPath"
        }
        Write-Host 'Pushing canonical MCP to all tools...'
        Invoke-Push -CanonicalServers $canonical
        $perTool = @{}
        foreach ($entry in $ToolTargets.GetEnumerator()) {
            if ($entry.Value.format -eq 'grok-compat') { continue }
            $perTool[$entry.Key] = Get-ServersFromTool $entry.Value
        }
        Update-StateFile -CanonicalServers $canonical -PerToolServers $perTool -LastAction 'push'
        Write-Host "State updated: $StatePath"
        Write-Host 'Done. Restart tools or press r in /mcps to reload.'
    }
    'Sync' {
        $pull = Invoke-Pull
        Write-Host 'Pull:'
        foreach ($entry in $pull.Summary.GetEnumerator()) {
            Write-Host "  $($ToolTargets[$entry.Key].label): $($entry.Value)"
        }
        Write-Host 'Push:'
        Invoke-Push -CanonicalServers $pull.Canonical
        Update-StateFile -CanonicalServers $pull.Canonical -PerToolServers $pull.PerTool -LastAction 'sync' -PullSummary $pull.Summary
        Write-Host "State updated: $StatePath"
        Write-Host 'Done. Restart tools or press r in /mcps to reload.'
    }
}