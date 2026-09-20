# deepseting для Codex

Переносимые настройки Codex, лёгкая поддержка долговечной проектной документации и адресные исправления сторонних Skills. Обычным задачам не навязывается отдельный spec-процесс: агент следует соглашениям конкретного проекта.

## Состав

| Путь | Назначение |
| --- | --- |
| `codex/AGENTS.md` | Небольшой глобальный router и пользовательские правила Codex |
| `codex/config.toml` | Управляемые настройки модели, sandbox и поиска |
| `codex/skills/project-specifications/` | Опциональный навык для spec, ADR, roadmap и handoff |
| `bin/new-project.ps1` | Явно вызываемый минимальный инициализатор документации |
| `bin/project-orchestration.ps1` | Детектор обычного режима и Game Master Plan |
| `codex/skill-patches.json` | Адресные исправления Skills после аудита |
| `bin/update-skill-guidance.ps1` | Проверка и применение audit patches |
| `install.ps1` | Безопасный установщик в каталог Codex |
| `tests/` | Изолированные PowerShell-тесты |

## Установка

```powershell
git clone --branch feat/codex-harness https://github.com/yshan20/deepseting.git
cd deepseting
pwsh -File install.ps1
```

Каталог назначения выбирается через `-ConfigDir`, затем `CODEX_HOME`, затем `~/.codex`. Установщик:

- заменяет `AGENTS.md`, сохраняя отличающуюся версию как backup;
- заменяет только блок `deepseting managed defaults` в `config.toml`, сохраняя локальные MCP, плагины и проекты;
- полностью заменяет дерево `skills/project-specifications`, чтобы удалённые шаблоны не оставались установленными;
- сохраняет изменённое дерево навыка вне discovery tree в `backups/skills/project-specifications-<дата>`;
- устанавливает PowerShell-скрипты и при повторном запуске не создаёт лишних skill-backup.

Настройки по умолчанию:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
web_search = "live"
personality = "friendly"
```

## Опциональная инициализация документации

```powershell
pwsh -File ~/.codex/bin/new-project.ps1 <путь-к-проекту>
pwsh -File ~/.codex/bin/new-project.ps1 <путь-к-проекту> -Feature <имя>
```

Первый вариант создаёт только отсутствующий `README.md`. `-Feature` дополнительно создаёт один `docs/specs/<безопасное-имя>.md`. Существующие файлы не перезаписываются. При запуске из подпапки Git-проекта используется его корень.

Скрипт не создаёт `docs/SPEC.md`, `docs/plan.md`, `PROGRESS.md`, `docs/features/` или hooks и не меняет `core.hooksPath`. В Game Master Plan он ничего не пишет.

## Game Master Plan

Отдельная строка `PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN` в корневом `CLAUDE.md` включает внешний режим. Явный `STANDARD_DEEPSETING` имеет приоритет над sentinel `specs/master/ACTIVE_STAGE.md`. Неизвестные и повторные объявления отклоняются до записи файлов.

В Game Master Plan используются существующие Stage/Wave/Lab документы без параллельного spec/progress дерева. Подробности находятся в `codex/skills/project-specifications/references/game-master-plan.md`.

## Audit patches для Skills

Обычная установка не изменяет сторонние Skills. Для явного применения проверенных адресных исправлений:

```powershell
pwsh -File install.ps1 -ApplySkillPatches -AgentSkillsDir "$HOME/.agents/skills"
```

Только проверить или применить patches можно через `bin/update-skill-guidance.ps1`. Механизм сначала валидирует все цели, сохраняет изменяемые файлы в backup и не заменяет Skills целиком. Подробности — в [codex/README.md](codex/README.md) и [bin/README.md](bin/README.md).

## Тесты

```powershell
pwsh -File tests/run-tests.ps1
```

Нужны PowerShell 5.1+ и Git. `sh`, `awk` и `grep` не используются.
