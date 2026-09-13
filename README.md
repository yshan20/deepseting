# Обвязка Codex (`deepseting`)

Переносимые настройки Codex: глобальные инструкции, безопасные рабочие настройки, навык ведения спецификаций и генератор каркаса проекта.

## Структура

| Путь | Назначение |
| --- | --- |
| `codex/AGENTS.md` | Глобальные инструкции Codex; устанавливаются в `~/.codex/AGENTS.md`. |
| `codex/config.toml` | Управляемые настройки модели, рассуждения, песочницы и поиска. |
| `codex/skills/project-specifications/` | Навык ведения спецификаций и шаблоны документов. |
| `bin/new-project.ps1` | Генератор спецификаций и pre-commit-хука нового проекта. |
| `bin/project-orchestration.ps1` | Выбор STANDARD_DEEPSETING или Game Master Plan без изменения проекта. |
| `codex/skill-patches.json` | Адресные исправления установленных сторонних Skills. |
| `bin/update-skill-guidance.ps1` | Проверка и применение этих исправлений с резервными копиями. |
| `install.ps1` | Установщик в каталог Codex с резервными копиями. |
| `tests/` | Интеграционные тесты установщика, генератора и хука. |

## Установка

```powershell
git clone --branch feat/codex-harness https://github.com/yshan20/deepseting.git
cd deepseting
pwsh -File install.ps1
```

Каталог выбирается в порядке: `-ConfigDir`, переменная `CODEX_HOME`, затем `~/.codex`. Существующие изменяемые файлы сохраняются как `*.bak-<дата>`.

Установщик заменяет только блок между маркерами `deepseting managed defaults` в `config.toml`. Локальные плагины, MCP-серверы и доверенные проекты остаются нетронутыми.

## Настройки по умолчанию

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
web_search = "live"
personality = "friendly"
```

Это профиль для сложной разработки: сильная кодовая модель и высокий уровень рассуждений, запись только в рабочую область, подтверждение рискованных действий и актуальный веб-поиск.

После установки перезапусти Codex. Авторизация выполняется командой `codex login`; токены и локальное состояние в репозитории не хранятся.

## Новый проект

```powershell
pwsh -File ~/.codex/bin/new-project.ps1 <путь-к-проекту>
pwsh -File ~/.codex/bin/new-project.ps1 <путь-к-проекту> -Feature <имя-функции>
```

Генератор создаёт `README.md`, `docs/SPEC.md`, `docs/plan.md`, `PROGRESS.md`, каталог `docs/features/` и pre-commit-хук.
Существующие документы не перезаписываются. В режиме Game Master Plan генератор
сохраняет текущую структуру и не создаёт стандартные документы и hook.

## Исправления Skills после аудита

Обоснование: [Rethinking skills and prompts for GPT-6 Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra).
Список изменений — в `codex/README.md`, команды проверки и применения — в `bin/README.md`.
Обычная установка не трогает сторонние Skills. Для их явного обновления при установке:

```powershell
pwsh -File install.ps1 -ApplySkillPatches -AgentSkillsDir "$HOME/.agents/skills"
```

Для изменения только Skills используй `bin/update-skill-guidance.ps1`: он не меняет
config.toml, модель, MCP и правила AGENTS.md. Машинные дополнения к AGENTS.md нужно
сохранять при переносе глобальных правил; полный install.ps1 заменяет его с backup.

## Тесты

```powershell
pwsh -File tests/run-tests.ps1
```

Нужны PowerShell 5.1+ или PowerShell 7+, `git` и `sh` (в Windows подходит Git for Windows).
