# MCP sync (подмодуль)

Канон: `~/.config/ai/mcp-servers.json` (формат Cursor: `mcpServers`).

**Не один JSON для всех инструментов** — скрипт трансформирует:
- Cursor / Antigravity / Gemini → `mcpServers` как есть
- OpenCode → секция `mcp` с `type: local|remote`, `command[]`
- Grok → читает `~/.cursor/mcp.json` через `[compat.cursor] mcps`

## Команды

Базовый путь скриптов:

```powershell
$Mcp = "$env:USERPROFILE\.agents\skills\unified-ai-tooling\scripts\sync-mcp.ps1"
```

| Действие | Команда |
|---|---|
| Sync (pull+push) | `pwsh $Mcp -Action Sync` |
| Status | `pwsh $Mcp -Action Status` |
| Pull | `pwsh $Mcp -Action Pull` |
| Push | `pwsh $Mcp -Action Push` |

Обёртка: `pwsh ~/.config/ai/sync-mcp.ps1 -Action Sync`

## Куда синхронизируется

| Среда | Путь |
|---|---|
| Cursor | `~/.cursor/mcp.json` |
| Grok | `~/.cursor/mcp.json` (compat) |
| OpenCode | `~/.config/opencode/opencode.json` |
| Antigravity | `~/.gemini/config/mcp_config.json` |
| Gemini CLI | `~/.gemini/settings.json` → `mcpServers` |

Состояние: `~/.config/ai/environments.json`

## Добавить MCP

1. Правь `~/.config/ai/mcp-servers.json`
2. `pwsh $Mcp -Action Push`
3. Проверь `environments.json` — все `inSync: true`

Или пользователь добавил в одном UI → `Sync` (Pull подхватит).

## Формат записи (канон)

```json
"my-server": { "url": "https://mcp.example.com/mcp" }
```

```json
"my-server": { "command": "npx", "args": ["-y", "@scope/mcp-server"] }
```

## Codegraph / workspace

```powershell
$env:WORKSPACE_FOLDER = "C:\path\to\project"
pwsh $Mcp -Action Push
```

Antigravity получит абсолютный путь; Cursor/OpenCode — `${workspaceFolder}`.

## Не делать

- Не удалять MCP из canonical без подтверждения (extra в одной среде)
- Не править `%APPDATA%\orca\opencode-hooks\shared\opencode.json` для MCP
- OAuth-токены не переносятся между инструментами