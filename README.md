# DeepSeek Harness — настройки (deepseting)

Переносимые настройки DeepSeek Harness (DSH) между компьютерами.

## Что здесь лежит

- `AGENTS.md` — глобальные правила разработки (DSH монтирует их в каждую сессию из `~/.dsh/AGENTS.md`).
- `settings.yaml` — основные настройки DSH (`~/.dsh/settings.yaml`): пресет по умолчанию, права доступа, тема, модель по умолчанию.
- `install.ps1` — скрипт развёртывания настроек в `~/.dsh`.

## Перенос на другой компьютер

### Быстро (рекомендуется)

```powershell
git clone https://github.com/yshan20/deepseting.git
cd deepseting
pwsh -File install.ps1
```

Скрипт скопирует `AGENTS.md` и `settings.yaml` в `~/.dsh/` и предложит ввести API-ключ.

### Вручную

1. Склонируй репозиторий.
2. Скопируй файлы в каталог `~/.dsh/` (Windows: `C:\Users\<user>\.dsh\`):
   - `AGENTS.md` → `~/.dsh/AGENTS.md`
   - `settings.yaml` → `~/.dsh/settings.yaml`
3. Восстанови API-ключ вручную (он **не** хранится в репозитории) — создай `~/.dsh/.credentials.yaml`:

   ```yaml
   DEEPSEEK_API_KEY: <твой-ключ>
   ```

## Безопасность

Репозиторий не содержит секретов. API-ключ (`~/.dsh/.credentials.yaml`), идентификатор пользователя и данные сессий исключены через `.gitignore`.
