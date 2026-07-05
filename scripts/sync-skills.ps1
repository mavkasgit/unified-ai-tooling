# Install custom + external skills from unified-ai-tooling repo.
param(
    [switch]$CustomOnly,
    [switch]$ExternalOnly
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$CustomSource = Join-Path $RepoRoot 'skills\custom'
$ExternalManifest = Join-Path $RepoRoot 'skills\external.manifest.json'
$SkillTarget = Join-Path $env:USERPROFILE '.agents\skills'

if (-not (Test-Path $SkillTarget)) {
    New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
}

function Install-CustomSkills {
    if (-not (Test-Path $CustomSource)) { return }
    Get-ChildItem $CustomSource -Directory | ForEach-Object {
        $dest = Join-Path $SkillTarget $_.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $_.FullName $dest -Recurse -Force
        Write-Host "  custom -> $dest"
    }
}

function Install-ExternalSkills {
    if (-not (Test-Path $ExternalManifest)) { return }
    $manifest = Get-Content $ExternalManifest -Raw | ConvertFrom-Json
    foreach ($skill in $manifest.skills) {
        Write-Host "  external: $($skill.name) ($($skill.source))"
        npx skills add $skill.source -g -y 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  failed: $($skill.name)"
        }
    }
}

Write-Host 'Syncing skills...'
if (-not $ExternalOnly) { Install-CustomSkills }
if (-not $CustomOnly) { Install-ExternalSkills }
Write-Host 'Done.'