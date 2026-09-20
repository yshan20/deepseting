# Скрипты

- `new-project.ps1` создаёт отсутствующий `README.md` и опциональный lean brief в `docs/specs/`. Существующие файлы сохраняются; в Game Master Plan ничего не создаётся.
- `project-orchestration.ps1` определяет режим по корневому `CLAUDE.md` и sentinel.
- `update-skill-guidance.ps1` проверяет и применяет адресные patches к установленным Skills.

Проверить patches без записи:

```powershell
powershell -ExecutionPolicy Bypass -File bin/update-skill-guidance.ps1 -ConfigDir "$HOME/.codex" -AgentSkillsDir "$HOME/.agents/skills" -CheckOnly
```

Применить patches:

```powershell
powershell -ExecutionPolicy Bypass -File bin/update-skill-guidance.ps1 -ConfigDir "$HOME/.codex" -AgentSkillsDir "$HOME/.agents/skills"
```

Без `AgentSkillsDir` изменяются только найденные системные и plugin Skills в каталоге Codex. Все найденные цели проверяются до первой записи; неизвестная версия останавливает операцию. Каждый изменяемый файл получает backup, а повторный запуск не создаёт новых копий.

Параметр `-WorkshopDir` отдельно синхронизирует исходник `game-creation-patterns`, его README и правило установщика мастерской. Без параметра мастерская не изменяется.
