---
name: ai-setup-audit
description: >
  Аудит и сравнение AI-стека по каждому инструменту: MCP, скиллы, OpenCode,
  Grok compat, hooks. Показывает что установлено, что расходится с каноном/репо.
  Триггеры: аудит ai, сравни настройки, что настроено, проверь mcp и скиллы,
  /ai-audit, audit setup, drift, расхождения конфигов.
---

# ai-setup-audit

Скилл для **диагностики без изменений**. Сначала аудит, потом — по запросу — синхронизация через `unified-ai-tooling`.

## Отчёт

После аудита читай:

**`~/.config/ai/audit-report.json`**

Там по каждому компоненту: `inSync`, `missingHere`, `extraHere`, `issues`.

Для только MCP также есть **`~/.config/ai/environments.json`** (после `sync-mcp.ps1 -Action Status`).

## Команда аудита

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\ai\audit-setup.ps1"
```

(Копируется при `install.ps1`. Из репо: `scripts/audit-setup.ps1`.)

JSON для агента:

```powershell
pwsh ~/.config/ai/audit-setup.ps1 -Json
```

## Что сравнивается

| Компонент | Канон / эталон | Инструменты |
|---|---|---|
| **MCP** | `~/.config/ai/mcp-servers.json` | Cursor, Grok (→Cursor), OpenCode, Antigravity, Gemini CLI |
| **Скиллы (свои)** | `skills/custom/` в репо | `~/.agents/skills/` |
| **Скиллы (внешние)** | `skills/external.manifest.json` | установленные в `~/.agents/skills/` |
| **OpenCode** | `opencode/*.json` в репо | `%APPDATA%/orca/opencode-hooks/shared/` |
| **Grok** | `[compat.cursor]` в шаблоне | `~/.grok/config.toml` |
| **Hooks** | Orca agent-hooks | `~/.orca/agent-hooks/`, cursor/grok hooks json |

## Алгоритм агента

### 1. Запусти аудит

```powershell
pwsh "$env:USERPROFILE\.config\ai\audit-setup.ps1"
```

Если скрипта нет — `git clone https://github.com/mavkasgit/unified-ai-tooling.git` и `pwsh scripts/install.ps1`.

### 2. Прочитай `audit-report.json`

Структура отчёта:

```json
{
  "overallInSync": false,
  "issues": ["mcp/opencode: out of sync", "skills: missing external: ..."],
  "components": {
    "mcp": { "canonical": [...], "tools": { "cursor": { "inSync": true, ... } } },
    "skills": { "missingCustom": [], "missingExternal": [], "extraInstalled": [] },
    "opencode": { "oh-my-opencode-slim.json": { "inSync": true, "preset": "opencode-go" } },
    "grok": { "inSync": true },
    "hooks": { "inSync": true }
  }
}
```

### 3. Доложи пользователю таблицей

Для каждого инструмента (Cursor, Grok, OpenCode, Antigravity, Gemini CLI):

- MCP: список серверов, ✅/❌ vs canonical
- Скиллы: только для общей папки `~/.agents/skills` (Grok/Cursor читают оттуда)
- OpenCode: preset, drift от репо
- Hooks: есть ли Orca

### 4. Исправление — только по запросу

| Проблема | Действие |
|---|---|
| MCP drift | `sync-mcp.ps1 -Action Sync` |
| Скиллы missing | `sync-skills.ps1` или `sync-skills.ps1 -CustomOnly` |
| OpenCode drift | `install.ps1` или копия `opencode/` |
| Grok compat | дописать `[compat.cursor]` из `grok/config.template.toml` |
| Hooks | установить/запустить Orca |

Не запускай Sync/Install без явного запроса пользователя после аудита.

## Дополнительно: Grok live inspect

```powershell
grok inspect --json | python -c "import sys,json;d=json.load(sys.stdin);print('MCP:',[s['name'] for s in d.get('mcpServers',[])]);print('SKILLS:',[s.get('name') for s in d.get('skills',[])][:15])"
```

Сравни с `audit-report.json` — inspect показывает runtime, audit — файлы на диске.

## Связанные скиллы

- `unified-ai-tooling` — установка и синхронизация
- `unified-mcp` — только MCP
- `opencode-go-orchestration-setup` — детали агентов OpenCode