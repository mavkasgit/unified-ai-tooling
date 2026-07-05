# unified-mcp

Единая система MCP для **OpenCode**, **Grok**, **Cursor**, **Antigravity** и **Gemini CLI**.

Один канонический конфиг → синхронизация во все среды. Pull подхватывает новые серверы, если вы добавили их в одном инструменте.

## Быстрый старт

```powershell
git clone https://github.com/mavkasgit/unified-mcp.git
cd unified-mcp
pwsh scripts/install.ps1
# отредактируйте ~/.config/ai/.env
pwsh ~/.config/ai/sync-mcp.ps1 -Action Sync
```

## Структура

```
unified-mcp/
├── config/mcp-servers.template.json   # шаблон без секретов
├── scripts/
│   ├── install.ps1                    # установка в ~/.agents и ~/.config/ai
│   └── sync-mcp.ps1                   # Pull / Push / Sync / Status
├── skill/SKILL.md                       # скилл для AI-агентов
└── .env.example
```

После установки:

| Файл | Назначение |
|---|---|
| `~/.config/ai/mcp-servers.json` | Канон (источник правды) |
| `~/.config/ai/environments.json` | Снимок состояния по средам (генерируется) |
| `~/.config/ai/.env` | Секреты и локальные пути (не в git) |
| `~/.agents/skills/unified-mcp/` | Скилл для агентов |

## Куда синхронизируется

| Среда | Путь |
|---|---|
| Cursor | `~/.cursor/mcp.json` |
| Grok | `~/.cursor/mcp.json` (compat) + `~/.grok/config.toml` |
| OpenCode | `~/.config/opencode/opencode.json` |
| Antigravity | `~/.gemini/config/mcp_config.json` |
| Gemini CLI | `~/.gemini/settings.json` |

## Команды

```powershell
pwsh ~/.config/ai/sync-mcp.ps1                  # Sync (pull + push)
pwsh ~/.config/ai/sync-mcp.ps1 -Action Status   # диагностика
pwsh ~/.config/ai/sync-mcp.ps1 -Action Pull     # подтянуть из сред
pwsh ~/.config/ai/sync-mcp.ps1 -Action Push     # раздать canonical
```

## MCP по умолчанию

- `chrome-devtools` — браузерная автоматизация
- `context7` — документация библиотек
- `exa` / `websearch` — веб-поиск
- `gh_grep` — поиск по GitHub
- `postgres` — локальная БД (URL из `.env`)
- `codegraph` — индекс кода (требует `@colbymchenry/codegraph`)

## Обновление с GitHub

```powershell
cd unified-mcp
git pull
pwsh scripts/install.ps1   # обновит скилл и скрипты
pwsh ~/.config/ai/sync-mcp.ps1 -Action Sync
```

`mcp-servers.json` и `.env` при install не перезаписываются, если уже существуют.

## Безопасность

- **Не коммитьте** `~/.config/ai/.env` и `mcp-servers.json` с реальными паролями
- В репозитории только `mcp-servers.template.json` с плейсхолдерами
- `environments.json` — локальный runtime-файл, в gitignore

## Скилл для агентов

После `install.ps1` агенты (Grok, Cursor, OpenCode) подхватывают скилл `unified-mcp` из `~/.agents/skills/`.

Триггеры: «синхронизируй mcp», `/unified-mcp`, «добавил mcp сервер».