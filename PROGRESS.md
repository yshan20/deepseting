# Прогресс

## Сделано

- План 1: прочитаны README, global rules, skill/templates, generator/installer/tests и Git history.
- План 2–3: добавлены detector, compatibility guard/reference, защита generator и mode-aware hook.
- Добавлены integration fixtures и сохранение локальных изменений навыка при установке.
- План 4: `tests/run-tests.ps1 -Keep` в Windows PowerShell 5.1 — 82 PASS, 0 FAIL.
  Запуск: `$env:PATH = 'C:\Program Files\Git\usr\bin;' + $env:PATH; powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1 -Keep`.
- Валидатор: `$env:PYTHONUTF8 = '1'; py -3 C:\Users\User\.codex\skills\.system\skill-creator\scripts\quick_validate.py claude/skills/project-specifications` — `Skill is valid!`.
- Acceptance F/G проверены ревью: continue восстанавливает работу; все пять условий pre-approval,
  уровни 0–3, cross-Lab ограничения и checkpoint protocol присутствуют.
- План 5: `powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -ConfigDir C:\Users\User\.claude`
  выполнен успешно. Все 9 установленных файлов правил/навыка/скриптов совпадают по SHA-256 с исходниками.
  Прежние правила, settings, skill и generator сохранены в резервные копии установщика.
- `git diff --check` — PASS; remote проверен: origin = https://github.com/yshan20/deepseting.git, branch = main.
  Изменения подготовлены к commit/push; результат отправки сообщается отдельно после ответа remote.

### Чистка обвязки (docs/features/harness-cleanup.md)

- Шаг 1: обвязка сверена с `code.claude.com/docs` (settings, settings-reference, memory, setup,
  fullscreen). Подтверждено: ключи `effortLevel` и `modelSettings` существуют; `autoUpdatesChannel`
  по умолчанию равен `latest`; `tui` — валидный ключ (research preview); `auto` и `bypassPermissions`
  в `permissions.defaultMode` действуют только из user/managed настроек.
- Шаг 2: правила разложены на `claude/rules/orchestration.md`, `specifications.md`,
  `architecture.md`; `claude/CLAUDE.md` сокращён с 81 до 20 строк.
- Шаг 3: в `settings.json` добавлен `"effortLevel": "high"`, удалён `autoUpdatesChannel: latest`.
- Шаг 4: нормативное описание режима собрано в разделе «Определение режима» reference;
  дубли убраны из `SKILL.md` и `README.md`, в `claude/rules/orchestration.md` остался
  короткий список для маршрутизации.
- Шаг 5: установщик ставит `claude/rules/*.md` в `<config>/rules/` без очистки каталога;
  README и `tests/README.md` обновлены. `tests/run-tests.ps1` в Windows PowerShell 5.1 —
  90 PASS, 0 FAIL (было 82; добавлено 8 проверок).
- Шаг 6: резервные копии перенесены в `<config>/backups/deepseting/` с сохранением относительного пути.
  Обнаружено на живой установке: копии навыка в `skills/` Claude Code грузил как отдельные скиллы —
  в списке доступных навыков было два почти одинаковых `project-specifications`.
  `tests/run-tests.ps1` — 93 PASS, 0 FAIL (добавлено 3 проверки, включая регрессию на этот дефект).

## Заблокировано

- Активных блокеров нет. Первый прогон не находил awk из-за sandbox; запуск вне sandbox прошёл.
  В промежуточной проверке исправлены кодировка установленного PS 5.1 генератора и Git-изоляция fixtures.

## Пропущено

- Нет.

## Решения без указания

- Явный STANDARD_DEEPSETING имеет приоритет над sentinel; неизвестные/повторные объявления отклоняются.
- Hook читает режим из индекса; generator — из рабочего дерева.
- Версия оформлена как Unreleased в CHANGELOG: существующей нумерации/тегов нет.
- Исправлена перезапись существующих specs при повторном запуске согласно обещанию README.
- `~/.claude/rules/` при установке не очищается, в отличие от каталога навыка: рядом могут лежать
  личные правила пользователя. Плата за это — правило, удалённое из репозитория, остаётся
  установленным и требует ручного удаления.
- Правила установлены без frontmatter `paths:`, то есть грузятся всегда. Разделение даёт
  модульность, а не экономию контекста; экономия появится, если позже часть правил ограничить путями.
- Работа велась в отдельном git worktree, потому что рабочее дерево `main` параллельно переписывал
  другой процесс. Коммит лёг в существующую ветку `feat/claude-code-harness` перемоткой:
  она стояла на влитом PR #1, то есть была предком `main`, и force-push не потребовался.
- Резервные копии складываются в `<config>/backups/deepseting/`, а не рядом с оригиналом: рядом они
  попадали в `skills/` и становились активными скиллами. Каталог не чистится автоматически —
  чистка остаётся ручной операцией пользователя.
