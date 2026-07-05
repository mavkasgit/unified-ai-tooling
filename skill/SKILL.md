---
name: unified-mcp
description: >
  Единая система MCP для OpenCode, Grok, Cursor и Antigravity. Синхронизирует
  mcp-servers.json между всеми средами, подтягивает новые серверы если пользователь
  добавил их в одном инструменте, и ведёт актуальный реестр environments.json.
  Триггеры: unified mcp, синхронизировать mcp, обновить mcp, добавил mcp,
  /unified-mcp, sync mcp, mcp servers setup.
---

# unified-mcp

Единый MCP-стек для всех AI-инструментов пользователя.

## Репозиторий

GitHub: `https://github.com/mavkasgit/unified-mcp`

```powershell
git clone https://github.com/mavkasgit/unified-mcp.git
pwsh unified-mcp/scripts/install.ps1
```

## Файлы

| Файл | Назначение |
|---|---|
| `~/.config/ai/mcp-servers.json` | **Канонический** список MCP (источник правды) |
| `~/.config/ai/environments.json` | Актуальное состояние по каждой среде (генерируется скриптом) |
| `~/.config/ai/.env` | Секреты (POSTGRES_MCP_URL, WORKSPACE_FOLDER) — не в git |
| `~/.agents/skills/unified-mcp/scripts/sync-mcp.ps1` | Pull / Push / Sync / Status |

## Куда синхронизируется

| Среда | Путь | Формат |
|---|---|---|
| Cursor | `~/.cursor/mcp.json` | `mcpServers` |
| Grok | `~/.cursor/mcp.json` | через `[compat.cursor] mcps = true` в `~/.grok/config.toml` |
| OpenCode | `~/.config/opencode/opencode.json` | секция `mcp` (`local` / `remote`) |
| Antigravity IDE | `~/.gemini/config/mcp_config.json` | `mcpServers` |
| Gemini CLI | `~/.gemini/settings.json` | `mcpServers` (остальные поля сохраняются) |

Перед работой **прочитай** `~/.config/ai/environments.json` — там последний снимок: какие серверы в каждой среде, что missing/extra, `inSync`.

## Когда вызывать

1. Пользователь **добавил MCP** в любом инструменте (OpenCode `/mcps`, Cursor settings, Antigravity, вручную в json).
2. Пользователь просит **синхронизировать / обновить / унифицировать** MCP.
3. Пользователь спрашивает **какие MCP сейчас настроены** — сначала `Status`, потом покажи `environments.json`.
4. После правки `mcp-servers.json` вручную — запусти `Push` или `Sync`.

## Алгоритм агента

### 1. Диагностика

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" -Action Status
```

Прочитай `~/.config/ai/environments.json` и кратко доложи: canonical servers, расхождения по средам.

### 2. Синхронизация (по умолчанию)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" -Action Sync
```

`Sync` = **Pull** (собрать новые/изменённые серверы из всех сред → canonical) + **Push** (раздать canonical во все среды).

### 3. Только подтянуть из сред (пользователь добавил где-то новый MCP)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" -Action Pull
```

Затем предложи или выполни `Push`, если пользователь хочет разнести на все инструменты.

### 4. Только раздать canonical (пользователь правил mcp-servers.json)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" -Action Push
```

### 5. Другой проект для codegraph (Antigravity)

```powershell
$env:WORKSPACE_FOLDER = "C:\path\to\project"
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\unified-mcp\scripts\sync-mcp.ps1" -Action Push
```

В canonical для Cursor/Grok/OpenCode остаётся `${workspaceFolder}`; в Antigravity подставляется реальный путь.

## Добавление нового MCP вручную

Предпочтительный путь — правка канона, затем Push:

1. Отредактировать `~/.config/ai/mcp-servers.json` (секция `mcpServers`).
2. Запустить `Sync` или `Push`.
3. Проверить `environments.json` — все среды `inSync: true`.

Формат записи (Cursor-совместимый):

```json
"my-server": {
  "url": "https://mcp.example.com/mcp"
}
```

или stdio:

```json
"my-server": {
  "command": "npx",
  "args": ["-y", "@scope/mcp-server"]
}
```

Если пользователь добавил сервер **только в одном UI** — достаточно `Sync`; Pull подхватит имя и конфиг в canonical.

## OpenCode: встроенные MCP плагина

`oh-my-opencode-slim` также внедряет `context7`, `gh_grep`, `websearch` (те же URL). Явные записи в `opencode.json` нужны для единообразия и работы без плагина. Дубликатов по имени быть не должно.

## Проверка Grok

```powershell
grok inspect --json | python -c "import sys,json; d=json.load(sys.stdin); print(*(s['name'] for s in d.get('mcpServers',[])))"
```

## Отчёт пользователю

После синхронизации выдай:

- список серверов в canonical;
- таблицу сред: path, serverCount, inSync, missing/extra;
- напоминание: перезапуск инструментов или `r` в `/mcps`.

## Не делать

- Не хранить API-токены в ответах пользователю; в конфиге — только если уже были.
- Не удалять MCP из canonical автоматически, если они есть лишь в одной среде (`extraHere`) — сначала спроси.
- Не править `%APPDATA%\orca\opencode-hooks\shared\opencode.json` — MCP там не живут.