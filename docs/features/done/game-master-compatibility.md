# Совместимость с Game Master Plan

Реализация и проверки завершены; свидетельства — в корневом PROGRESS.md.

## Цель и область

Выполнить DEEPSETING_GAME_MASTER_COMPATIBILITY_TASK.md, переданный пользователем:
маршрутизация, правила, генератор/hooks, документация, тесты, глобальная установка, commit/push.
Критерии уже заданы и разрешены пользователем; новый цикл согласования не требуется.

## Критерии готовности

| Состояние | Чем проверяется |
| --- | --- |
| A: Без сигналов сохраняется STANDARD_DEEPSETING | tests/run-tests.ps1, standard fixtures и прежние hook tests |
| B/C: Явный marker и fallback выбирают GAME_MASTER_PLAN | tests/orchestration-tests.ps1, router fixtures |
| D: Инициализация не создаёт параллельные спецификации и не меняет состояние | Installed generator fixtures, сравнение хешей, nested invocation |
| E: Game hook не требует standard specs; standard checks сохранены | Реальные git commit, staged/unstaged marker/sentinel и переход обратно |
| F: Continue восстанавливает работу из Master Plan | Ревью глобальных правил, SKILL.md и reference |
| G: Активная утверждённая Lab task без повторного approval; продукт/ломающие контракты с approval | Ревью пяти условий допуска и уровней 0–3 |
| Durable memory, выборочная загрузка и инженерные правила сохранены | Ревью reference и глобальных правил |
| Обновление установлено глобально, изменения отправлены в remote | Сравнение установленных файлов, git status/log/remote, результат push |

## Связь со SPEC

Детерминированное определение режима и приоритет явных правил проекта из docs/SPEC.md.
