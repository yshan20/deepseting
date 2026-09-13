# Скрипты обвязки

- `new-project.ps1` создаёт недостающие стандартные документы и specification hook.
  Существующие документы сохраняются. В Game Master Plan ничего не создаётся.
- `project-orchestration.ps1` определяет режим по корневому CLAUDE.md и sentinel.
- `update-skill-guidance.ps1` проверяет и применяет адресные патчи к установленным Skills.

## Проверить патчи без записи

`powershell -ExecutionPolicy Bypass -File bin/update-skill-guidance.ps1 -ConfigDir "$HOME/.codex" -AgentSkillsDir "$HOME/.agents/skills" -CheckOnly`

## Применить патчи

`powershell -ExecutionPolicy Bypass -File bin/update-skill-guidance.ps1 -ConfigDir "$HOME/.codex" -AgentSkillsDir "$HOME/.agents/skills"`

Без AgentSkillsDir изменяются только найденные системные/плагинные Skills в каталоге Codex.
Каждый изменяемый файл сохраняется рядом как `*.bak-<дата>`. Повторное применение
не меняет уже исправленные файлы и не создаёт новые копии. Патчи сначала проверяются
для всех найденных целей: незнакомый текст приводит к ошибке до начала записи.
Для восстановления скопируй выбранный backup поверх соответствующего SKILL.md.

Если используется общая мастерская, параметр `-WorkshopDir <каталог-creation-patterns>`
синхронизирует исходный game-creation-patterns и его README. Без этого параметра
мастерская не изменяется. Указывай этот каталог отдельно, чтобы переустановка
навыка из его исходника не вернула старое правило обязательного поиска.

Запуск тестов из корня: `powershell -ExecutionPolicy Bypass -File tests/run-tests.ps1`.
