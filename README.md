# DeepSeek Harness — настройки (deepseting)

Переносимые настройки DeepSeek Harness (DSH) между компьютерами.

## Что здесь лежит

- `AGENTS.md` — глобальные правила разработки (DSH монтирует их в каждую сессию из `~/.dsh/AGENTS.md`).
- `settings.yaml` — основные настройки DSH (`~/.dsh/settings.yaml`).
- `skill/project-specifications/` — скилл ведения спецификаций проекта (+ шаблоны).
- `new-project.ps1` — генератор каркаса спецификаций в новом проекте.
- `install.ps1` — скрипт развёртывания всего выше в `~/.dsh`.

## Перенос на другой компьютер

```powershell
git clone https://github.com/yshan20/deepseting.git
cd deepseting
pwsh -File install.ps1
```

Скрипт скопирует настройки и скилл в `~/.dsh/` и предложит ввести API-ключ.

## Новый проект

```powershell
pwsh ~\.dsh\bin\new-project.ps1 <путь-к-проекту>

# или сразу с заготовкой функции:
pwsh ~\.dsh\bin\new-project.ps1 <путь-к-проекту> -Feature <имя-функции>
```

Создаёт `README.md`, `docs/SPEC.md`, `docs/plan.md`, `PROGRESS.md` и папку `docs/features/`.

## Безопасность

Репозиторий не содержит секретов. API-ключ (`~/.dsh/.credentials.yaml`), идентификатор пользователя и данные сессий исключены через `.gitignore`.
