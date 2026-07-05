---
name: opencode-go-orchestration-setup
description: opencode-go + oh-my-opencode-slim orchestration setup - agent models, config paths, tuning, diagnostics.
---

# opencode-go-orchestration-setup

Current opencode-go orchestration config for oh-my-opencode-slim plugin.

## Актуальная конфигурация

Конфиг: `%APPDATA%\orca\opencode-hooks\shared\oh-my-opencode-slim.json`

| Агент | Модель | Роль |
|---|---|---|
| orchestrator | `opencode-go/minimax-m3` | Планирование, делегирование, ревью |
| oracle | `opencode-go/minimax-m3` | Архитектура, code review, отладка |
| council | `opencode-go/qwen3.7-max` | Консенсус нескольких моделей |
| fixer | `opencode/deepseek-v4-flash-free` | Написание кода |
| explorer | `opencode/deepseek-v4-flash-free` | Поиск по коду |
| librarian | `opencode/deepseek-v4-flash-free` | Поиск документации |
| designer | `opencode/deepseek-v4-flash-free` | UI/UX |
| observer | `opencode/mimo-v2.5-free` | Анализ изображений |

Пресет: `opencode-go` (активен). Пресет `openai` есть в конфиге, но не используется.

## Где лежат конфиги

| Путь | Назначение |
|---|---|
| `%APPDATA%\orca\opencode-hooks\shared\opencode.json` | OpenCode core: плагины, провайдеры |
| `%APPDATA%\orca\opencode-hooks\shared\oh-my-opencode-slim.json` | Плагин: агенты, модели, пресеты |
| `~/.config/opencode/opencode.json` | MCP-серверы (postgres, chrome-devtools, exa) |
| `.opencode/opencode.json` (проект) | Проектные оверрайды (удалён для ktm2000) |

### Prompt-оверрайды для агентов

Можно добавить инструкции агенту без правки конфига. Файлы в `~/.config/opencode/oh-my-opencode-slim/`:

```
{agent}.md          — полная замена промпта
{agent}_append.md   — добавить в конец промпта
{preset}/{agent}.md — замена для конкретного пресета
{preset}/{agent}_append.md — добавка для конкретного пресета
```

Имена файлов: `orchestrator`, `oracle`, `fixer`, `explorer`, `librarian`, `designer`, `observer`, `council`.

Пример `orchestrator_append.md`:

```markdown
## Project Rule
- Always read AGENTS.md before starting any task.
- Prefer async operations for database calls.
```

## Доступные модели

### Бесплатные
- `opencode/deepseek-v4-flash-free` — быстрый кодер
- `opencode/mimo-v2.5-free` — мультимодальный (картинки, видео)

### Платные (opencode-go)
- `opencode-go/glm-5.2` — сильный reasoning
- `opencode-go/deepseek-v4-pro` / `deekseek-v4-flash` — кодеры
- `opencode-go/minimax-m3` — balanced (428B, 1M ctx)
- `opencode-go/kimi-k2.6` / `kimi-k2.7-code` — мультимодальный
- `opencode-go/qwen3.7-max` / `qwen3.7-plus` — reasoning
- `opencode-go/mimo-v2.5` / `mimo-v2.5-pro` — агентные

## Как менять модель

В пресете `opencode-go` поменять `model` у нужного агента:

```jsonc
"fixer": {
  "model": "opencode/deepseek-v4-flash-free"  // новая модель
}
```

Поля агента: `model`, `variant` (low/medium/high/max), `skills` (массив), `mcps` (массив), `temperature`.

## Разрешения MCP и скиллы

```jsonc
"explorer": {
  "skills": ["*"],           // все скиллы
  "mcps": ["*", "!context7"] // все MCP кроме context7
}
```

- `"*"` — все
- `"!name"` — исключение
- `[]` — ничего

## Отключение агента

```jsonc
"disabled_agents": ["observer"]
```

Убрать из массива чтобы включить.

## Переменная окружения

```powershell
$env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"
```

Установлена в PowerShell профиле: `C:\Users\user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

## Проверка

```bash
opencode models --refresh
ping all agents
```
