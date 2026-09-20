# История изменений

## Unreleased

- `AGENTS.md` сокращён до переносимой маршрутизации, формата ответа и правил игровых ассетов.
- Навык спецификаций теперь срабатывает только для явных spec/ADR/roadmap/handoff задач, существующего spec-процесса или большой многоэтапной координации.
- Удалены обязательные четыре документа, approval-паузы, progress logging и specification hook.
- `new-project.ps1` создаёт только отсутствующий `README.md` и опциональный brief в `docs/specs/`.
- Удалены старые шаблоны и корневой `PROGRESS.md`.
- Установщик полностью заменяет project-specifications и хранит его backup вне discovery tree в `backups/skills`.
- Сохранены marked merge `config.toml`, `ApplySkillPatches` и адресный Codex audit patch workflow.
- Тесты больше не зависят от `sh`, `awk` или `grep`.
