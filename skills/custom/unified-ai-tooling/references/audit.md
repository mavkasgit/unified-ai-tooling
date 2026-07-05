# Аудит AI-стека (подмодуль)

**Только диагностика, без изменений.** После аудита — исправление по запросу пользователя.

## Команда

```powershell
pwsh "$env:USERPROFILE\.agents\skills\unified-ai-tooling\scripts\audit-setup.ps1"
```

Или через обёртку: `pwsh ~/.config/ai/audit-setup.ps1`

JSON: добавь `-Json`

## Отчёт

Читай `~/.config/ai/audit-report.json`:

- `overallInSync`, `issues[]`
- `components.mcp.tools.{cursor,grok,opencode,antigravity,gemini-cli}`
- `components.skills` — missingCustom, missingExternal, extraInstalled
- `components.opencode`, `components.grok`, `components.hooks`

Для только MCP: `~/.config/ai/environments.json` (после `sync-mcp.ps1 -Action Status`).

## Что сравнивается

| Компонент | Эталон | Инструменты |
|---|---|---|
| MCP | `~/.config/ai/mcp-servers.json` | Cursor, Grok, OpenCode, Antigravity, Gemini CLI |
| Скиллы (свои) | `skills/custom/` в репо | `~/.agents/skills/` |
| Скиллы (внешние) | `skills/external.manifest.json` | `~/.agents/skills/` |
| OpenCode | `opencode/*.json` | `%APPDATA%/orca/opencode-hooks/shared/` |
| Grok | `[compat.cursor]` | `~/.grok/config.toml` |
| Hooks | Orca | `~/.orca/agent-hooks/` |

## Отчёт пользователю

Таблица по инструментам: MCP servers ✅/❌, скиллы, OpenCode preset, hooks.

## Исправление (только по запросу)

| Проблема | Действие |
|---|---|
| MCP drift | см. `references/mcp.md` → Sync |
| Скиллы missing | `references/install.md` |
| OpenCode drift | `install.ps1` из репо |
| Grok compat | `grok/config.template.toml` |
| Hooks | установить Orca |

## Grok runtime

```powershell
grok inspect --json
```

Сравни MCP/skills runtime с `audit-report.json`.