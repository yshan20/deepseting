# План: Game Master Plan compatibility

| Шаг | Критерий готовности | Чем проверяется |
| --- | --- | --- |
| 1. Исследовать обвязку и текущие тесты | Все места standard workflow найдены | README, rg, git status/log |
| 2. Добавить router, guard, правила и reference | Режимы и уровни решений описаны и реализованы | Ревью diff |
| 3. Обновить генератор, hook и installer | Безопасная инициализация и установка detector | Интеграционные тесты |
| 4. Проверить оба режима и документацию | Все acceptance criteria проверены | tests/run-tests.ps1, skill validator, ручное ревью F/G |
| 5. Установить глобально, commit/push | Установленные файлы совпадают, remote обновлён | Хеши файлов, git status/log/push |
