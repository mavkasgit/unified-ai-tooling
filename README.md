# unified-ai-tooling

Единый стек AI-инструментов: **MCP**, **скиллы**, **OpenCode orchestration**, **Grok compat**.

Один репозиторий → одна команда установки → все среды синхронизированы.

## Быстрый старт

```powershell
git clone https://github.com/mavkasgit/unified-ai-tooling.git
cd unified-ai-tooling
pwsh scripts/install.ps1
# заполните ~/.config/ai/.env
```

## Что уже унифицировано локально

| Компонент | Статус | Где живёт |
|---|---|---|
| MCP | ✅ этот репо | `~/.config/ai/` → все инструменты |
| Свои скиллы | ✅ этот репо | `skills/custom/` → `~/.agents/skills/` |
| Внешние скиллы | 📋 манифест | `npx skills add` из `external.manifest.json` |
| OpenCode agents | ✅ этот репо | `opencode/` → Orca shared config |
| Grok compat | ✅ шаблон | `[compat.cursor]` в `config.toml` |
| Hooks | ⚙️ Orca | `~/.orca/agent-hooks/` (не в git) |
| Grok built-in skills | ❌ не трогаем | `~/.grok/skills/` (docx, pptx…) |

## Структура

```
unified-ai-tooling/
├── manifest.json              # реестр компонентов
├── mcp/                       # (legacy paths: config/, skill/)
├── skills/
│   ├── custom/                # ваши скиллы (orchestrator-hands, pytest-writer…)
│   └── external.manifest.json # внешние скиллы для npx skills
├── opencode/                  # oh-my-opencode-slim + core config
├── grok/                      # config.template.toml
├── hooks/                     # документация (Orca)
└── scripts/
    ├── install.ps1            # всё сразу
    ├── sync-mcp.ps1
    ├── sync-skills.ps1
    └── install-mcp.ps1
```

## Аудит (сравнение по инструментам)

```powershell
pwsh ~/.config/ai/audit-setup.ps1           # отчёт в ~/.config/ai/audit-report.json
```

Скилл для агентов: **`ai-setup-audit`** — сравнивает MCP, скиллы, OpenCode, Grok, hooks без изменений.

## Команды

```powershell
pwsh scripts/install.ps1                    # полная установка
pwsh scripts/install.ps1 -SkipExternalSkills  # без npx skills add
pwsh scripts/sync-mcp.ps1 -Action Status    # статус MCP по средам
pwsh scripts/sync-skills.ps1 -CustomOnly    # только свои скиллы
```

## Добавить свой скилл

1. Создай `skills/custom/my-skill/SKILL.md`
2. `pwsh scripts/sync-skills.ps1 -CustomOnly`
3. `git commit && git push`

## Безопасность

Не коммитьте: `.env`, `mcp-servers.json` с паролями, `environments.json`.

## Скилл для агентов

После install: `unified-ai-tooling` и `unified-mcp` в `~/.agents/skills/`.