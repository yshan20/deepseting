# Режим проекта

Определи режим до создания любых процессных документов:

1. Отдельная строка `PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN` в корневом `CLAUDE.md` включает `GAME_MASTER_PLAN`.
2. Отдельная строка `PROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING` выбирает стандартный режим даже при sentinel.
3. Без объявления наличие файла `specs/master/ACTIVE_STAGE.md` включает `GAME_MASTER_PLAN`.
4. Иначе — `STANDARD_DEEPSETING`.

Полные правила определения режима, границы автономности, уровни решений 0–3, durable memory
и загрузка контекста — в `~/.claude/skills/project-specifications/references/game-master-plan.md`.
Прочитай этот документ в режиме `GAME_MASTER_PLAN` до существенных изменений.

## В режиме `GAME_MASTER_PLAN`

- `specs/master/` определяет, КОГДА разрешена работа; `specs/labs/<lab>/` — КАК реализуется подсистема.
- Не создавай и не поддерживай параллельные `docs/SPEC.md`, `docs/features/`, `docs/plan.md`,
  корневой `PROGRESS.md`, если сам Master Plan явно не требует их.
- Не запускай `new-project.ps1` автоматически и не ставь конфликтующий specification hook.
- «continue», «go on», «next», «дальше», «продолжай», «давай» — восстанови
  `ACTIVE_STAGE → активный Stage → активная Wave → HANDOFF → Lab PROGRESS/TODO → задача`
  и продолжай самый ранний незавершённый разрешённый milestone. Не спрашивай заново, какой Lab выбрать.
- Условия, при которых повторное подтверждение не требуется, — раздел «Утверждённая работа» в reference.

## В обоих режимах

Доменная архитектура, явные границы, обобщаемые решения, поддерживаемость, Git hygiene
и фиксация принятых решений действуют одинаково.
