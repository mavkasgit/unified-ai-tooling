# Wrapper -> unified-ai-tooling skill scripts
param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-ai-tooling\scripts\install-mcp.ps1" -RepoRoot $RepoRoot