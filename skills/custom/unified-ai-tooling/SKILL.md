---
name: unified-ai-tooling
description: >
  Единый глобальный скилл AI-стека: аудит, MCP, установка, OpenCode, Grok compat.
  Один вход — внутри вызывает подмодули (references/audit.md, mcp.md, install.md).
  Триггеры: unified ai, /unified-ai, синхронизировать mcp, аудит ai, /ai-audit,
  ai tooling, обновить ai стек, drift, расхождения конфигов, sync mcp, что настроено.
---

# unified-ai-tooling

**Единственная точка входа** для MCP, аудита и установки AI-стека.

Репозиторий: `https://github.com/mavkasgit/unified-ai-tooling`  
Путь скилла: `~/.agents/skills/unified-ai-tooling/`

## Маршрутизация — что читать и запускать

| Намерение пользователя | Подмодуль | Действие |
|---|---|---|
| Аудит, сравнить, что настроено, drift | [`references/audit.md`](references/audit.md) | `scripts/audit-setup.ps1` — **без изменений** |
| MCP: sync, добавил mcp, обновить mcp | [`references/mcp.md`](references/mcp.md) | `scripts/sync-mcp.ps1` |
| Установка, git pull, первый setup | [`references/install.md`](references/install.md) | `scripts/install.ps1` из репо |
| Полный цикл «проверь и почини» | audit → mcp/install | сначала audit, fix по запросу |

**Алгоритм агента:**

1. Определи намерение по таблице выше.
2. **Прочитай соответствующий файл** в `references/` (полные инструкции там).
3. Запускай скрипты из `~/.agents/skills/unified-ai-tooling/scripts/`.
4. Читай отчёты: `audit-report.json`, `environments.json`.
5. Доложи таблицей по инструментам (Cursor, Grok, OpenCode, Antigravity, Gemini CLI).

## Быстрые команды

```powershell
$Base = "$env:USERPROFILE\.agents\skills\unified-ai-tooling\scripts"

# Аудит (всегда первым при «что настроено»)
pwsh "$Base\audit-setup.ps1"

# MCP sync
pwsh "$Base\sync-mcp.ps1" -Action Sync

# MCP status only
pwsh "$Base\sync-mcp.ps1" -Action Status
```

Обёртки в `~/.config/ai/`: `audit-setup.ps1`, `sync-mcp.ps1`

## Структура скилла

```
unified-ai-tooling/
├── SKILL.md              ← ты здесь (роутер)
├── references/
│   ├── audit.md          ← диагностика
│   ├── mcp.md            ← синхронизация MCP
│   └── install.md        ← установка стека
└── scripts/
    ├── audit-setup.ps1
    ├── sync-mcp.ps1
    └── install-mcp.ps1
```

Отдельных скиллов `unified-mcp` и `ai-setup-audit` **больше нет** — всё через этот.

## Стек (кратко)

| Компонент | Канон | Куда |
|---|---|---|
| MCP | `~/.config/ai/mcp-servers.json` | Cursor, Grok, OpenCode, Antigravity |
| Скиллы (свои) | `skills/custom/` в репо | `~/.agents/skills/` |
| OpenCode | `opencode/*.json` | `%APPDATA%/orca/opencode-hooks/shared/` |
| Grok | `[compat.cursor]` | `~/.grok/config.toml` |
| Hooks | Orca | `~/.orca/agent-hooks/` |

## Правила

- **Аудит** — не меняет файлы; sync/install — только по запросу или явной задаче.
- MCP JSON **не одинаков** для всех инструментов — канон Cursor-like, sync трансформирует (см. `references/mcp.md`).
- Секреты только в `~/.config/ai/.env`, не в ответах пользователю.

## Связанные скиллы (вне этого пакета)

- `opencode-go-orchestration-setup` — детали агентов OpenCode
- `orchestrator-hands` — режим оркестратора