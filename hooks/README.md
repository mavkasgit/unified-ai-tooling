# Hooks (Orca)

Хуки для Cursor, Grok, Antigravity и других агентов **уже унифицированы через Orca**:

| Путь | Назначение |
|---|---|
| `~/.orca/agent-hooks/*.cmd` | Обёртки для каждого агента (grok, cursor, antigravity, claude…) |
| `~/.cursor/hooks.json` | Cursor → `cursor-hook.cmd` |
| `~/.grok/hooks/orca-status.json` | Grok lifecycle hooks |
| `~/.gemini/settings.json` → `hooks` | Antigravity / Gemini CLI |

Хуки зависят от **запущенного Orca** (`ORCA_AGENT_HOOK_PORT`, токены). Их не копируют в этот репозиторий — они ставятся вместе с Orca.

При `install.ps1` проверяется наличие `~/.orca/agent-hooks/` и выводится предупреждение, если Orca не установлен.