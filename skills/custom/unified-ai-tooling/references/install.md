# Установка и обновление (подмодуль)

Репозиторий: https://github.com/mavkasgit/unified-ai-tooling

## Полная установка

```powershell
git clone https://github.com/mavkasgit/unified-ai-tooling.git
cd unified-ai-tooling
pwsh scripts/install.ps1
```

Обновление: `git pull && pwsh scripts/install.ps1`

## Что делает install.ps1

1. Копирует скилл `unified-ai-tooling` → `~/.agents/skills/unified-ai-tooling/`
2. Скрипты аудита/MCP → `~/.config/ai/` (обёртки)
3. MCP template → `~/.config/ai/mcp-servers.json` (если нет)
4. OpenCode configs → `%APPDATA%/orca/opencode-hooks/shared/`
5. Grok `[compat.cursor]` → `~/.grok/config.toml`
6. Внешние скиллы → `npx skills add` из `skills/external.manifest.json`

Флаги: `-SkipExternalSkills`, `-SkipMcp`

## Свои скиллы (кроме unified-ai-tooling)

Другие custom-скиллы в репо (`orchestrator-hands`, `pytest-writer`…) копируются в `~/.agents/skills/` через `sync-skills.ps1`.

Добавить свой:
1. `skills/custom/my-skill/SKILL.md` в репо
2. `pwsh scripts/sync-skills.ps1 -CustomOnly`

## Внешние скиллы

Правь `skills/external.manifest.json`, затем:

```powershell
pwsh scripts/sync-skills.ps1
```

## Не в git

- `~/.config/ai/.env`
- `~/.config/ai/environments.json`, `audit-report.json`
- `~/.orca/agent-hooks/`