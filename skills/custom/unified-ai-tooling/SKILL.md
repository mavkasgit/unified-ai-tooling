---
name: unified-ai-tooling
description: >
  Единый стек AI-инструментов: MCP, скиллы, OpenCode orchestration, Grok compat.
  Синхронизирует конфиги между OpenCode, Grok, Cursor, Antigravity. Триггеры:
  unified ai, ai tooling, синхронизировать скиллы, обновить ai стек, /unified-ai.
---

# unified-ai-tooling

Репозиторий: `https://github.com/mavkasgit/unified-ai-tooling`

## Что входит в стек

| Компонент | Канон / источник | Куда ставится |
|---|---|---|
| **MCP** | `~/.config/ai/mcp-servers.json` | Cursor, Grok, OpenCode, Antigravity |
| **Скиллы (свои)** | `skills/custom/` в репо | `~/.agents/skills/` |
| **Скиллы (внешние)** | `skills/external.manifest.json` | `npx skills add` |
| **OpenCode** | `opencode/*.json` | `%APPDATA%/orca/opencode-hooks/shared/` |
| **Grok compat** | `grok/config.template.toml` | `~/.grok/config.toml` |
| **Hooks** | Orca | `~/.orca/agent-hooks/` (не в git) |

Состояние MCP: `~/.config/ai/environments.json`

## Команды

```powershell
# Полная установка / обновление
cd unified-ai-tooling
git pull
pwsh scripts/install.ps1

# Только MCP
pwsh scripts/sync-mcp.ps1 -Action Sync

# Только скиллы
pwsh scripts/sync-skills.ps1
pwsh scripts/sync-skills.ps1 -CustomOnly      # без npx skills add
```

## Алгоритм агента

1. Прочитай `manifest.json` и `~/.config/ai/environments.json`
2. При «добавил скилл / mcp / поменял opencode» — определи компонент
3. Для MCP → `sync-mcp.ps1 -Action Sync`
4. Для своего скилла → положи в `skills/custom/<name>/`, `sync-skills.ps1 -CustomOnly`, commit в git
5. Для внешнего скилла → добавь в `external.manifest.json`, `sync-skills.ps1`
6. Для OpenCode orchestration → правь `opencode/`, `install.ps1`
7. Отчёт: что синхронизировано, что требует Orca / .env

## Не в git

- `~/.config/ai/.env` — секреты
- `~/.config/ai/environments.json` — runtime-снимок
- `~/.orca/agent-hooks/` — ставится Orca
- `~/.grok/skills/` — встроенные скиллы Grok (docx, pptx…)