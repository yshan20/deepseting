# new-project.ps1 — генерирует каркас спецификаций в проекте.
#
# Использование:
#   pwsh -File new-project.ps1 [путь]
#   pwsh -File new-project.ps1 [путь] -Feature <имя-функции>

[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$Feature
)

$ErrorActionPreference = 'Stop'

$target = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

# Каталог шаблонов: ~/.dsh/skills/... или рядом с этим скриптом в deepseting
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$tpl = $null
foreach ($candidate in @(
        (Join-Path $dshHome 'skills\project-specifications\templates'),
        (Join-Path $PSScriptRoot 'skill\project-specifications\templates')
    )) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'SPEC.md')) { $tpl = $candidate; break }
}

# Папки
New-Item -ItemType Directory -Force -Path (Join-Path $target 'docs\features') | Out-Null

function Copy-Tpl([string]$name, [string]$dest) {
    $dst = Join-Path $target $dest
    if ($tpl) {
        Copy-Item -LiteralPath (Join-Path $tpl $name) -Destination $dst -Force
    } else {
        Write-Warning "Шаблон не найден ($name) — создаю пустой файл."
        New-Item -ItemType File -Force -Path $dst | Out-Null
    }
    Write-Host "[OK] $dest"
}

# README.md — краткое описание структуры (только если ещё нет)
$readme = Join-Path $target 'README.md'
if (Test-Path -LiteralPath $readme) {
    Write-Host "[i]  README.md уже существует — пропущен"
} else {
    $leaf = Split-Path $target -Leaf
    # Здесь-строка одинарная: в интерполирующей PowerShell съедает обратные кавычки
    # markdown как escape-символ. Имя проекта подставляется после.
    $content = @'
# __PROJECT__

Краткое описание структуры проекта.

## Структура

- `docs/SPEC.md` — центральная спецификация (система, границы, ключевые решения).
- `docs/features/` — спецификации отдельных функций.
- `docs/plan.md` — план реализации текущей функции.
- `PROGRESS.md` — прогресс (сделано / заблокировано / пропущено / решения без указания).

## Спецификации и проверки

- Критерии готовности в `docs/features/*.md` — таблица с обязательной колонкой «Чем проверяется».
- Критерии готовности утверждает человек до начала работы над планом.
- Git pre-commit хук в `.githooks/pre-commit` (подключён через `core.hooksPath`) проверяет содержимое индекса — то, что уйдёт в коммит, а не файлы в рабочем дереве.

Хук отклоняет коммит, если в критериях готовности есть строка с пустой колонкой «Чем проверяется» или без этой колонки вообще, если в разделе «Критерии готовности» нет таблицы с такой колонкой, или если изменён `docs/plan.md` без изменения `PROGRESS.md`. Архив `docs/features/done/` не проверяется. В тексте ошибки — имя файла и номер строки.

## Запуск / сборка / тесты

<!-- как запускать, собирать и тестировать проект -->
'@
    $content = $content.Replace('__PROJECT__', $leaf)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($readme, $content, $utf8)
    Write-Host "[OK] README.md"
}

Copy-Tpl 'SPEC.md' 'docs\SPEC.md'
Copy-Tpl 'plan.md' 'docs\plan.md'
Copy-Tpl 'progress.md' 'PROGRESS.md'

# Опционально: заготовка функции
if ($Feature) {
    $safe = ($Feature.Trim() -replace '[\\/:*?"<>|]', '-')
    Copy-Tpl 'feature.md' "docs\features\$safe.md"
}

# Git pre-commit hook
$hooksDir = Join-Path $target '.githooks'
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
$hookPath = Join-Path $hooksDir 'pre-commit'
if (Test-Path -LiteralPath $hookPath) {
    Write-Host "[i]  .githooks/pre-commit уже существует — пропущен"
} else {
    $hook = @'
#!/bin/sh
# pre-commit: проверяет спецификации проекта перед коммитом.
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || exit 1

fail=0

# Проверяется содержимое индекса (то, что реально уйдёт в коммит), а не рабочее дерево.
# :(glob) — чтобы * не заходил в подкаталоги: архив docs/features/done/ не проверяем.
features=$(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR -- ':(glob)docs/features/*.md')

old_ifs=$IFS
IFS='
'
set -f
for f in $features; do
  [ -n "$f" ] || continue
  git show ":$f" | awk -F'|' -v fname="$f" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

    # Колонка ищется по заголовку таблицы, а не по фиксированному номеру:
    # проверка не зависит от числа колонок и их порядка в конкретном файле.
    BEGIN { bad = 0; col = 0; found = 0; seen = 0; seen_line = 0 }

    /^[[:space:]]*##[[:space:]]*Критерии готовности/ {
      seen = 1; seen_line = NR; col = 0; next
    }

    /^[[:space:]]*\|/ {
      # Ячейки лежат в полях 2..n+1; завершающий разделитель даёт пустое поле.
      n = NF - 1
      if (trim($NF) == "") n = NF - 2

      hdr = 0
      for (i = 1; i <= n; i++)
        if (trim($(i + 1)) == "Чем проверяется") { col = i; found = 1; hdr = 1 }
      if (hdr) next

      if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]*$/) next
      if (col == 0) next

      if (n < col) {
        printf "%s:%d: ошибка: в строке критерия нет колонки «Чем проверяется»\n", fname, NR
        bad = 1
        next
      }
      if (trim($(col + 1)) == "") {
        printf "%s:%d: ошибка: пустая колонка «Чем проверяется» в критерии готовности\n", fname, NR
        bad = 1
      }
      next
    }

    { col = 0 }

    END {
      if (seen && !found) {
        printf "%s:%d: ошибка: в разделе «Критерии готовности» нет таблицы с колонкой «Чем проверяется»\n", fname, seen_line
        bad = 1
      }
      exit bad
    }
  ' || fail=1
done
set +f
IFS=$old_ifs

staged=$(git diff --cached --name-only --)
if printf '%s\n' "$staged" | grep -qx 'docs/plan.md'; then
  if ! printf '%s\n' "$staged" | grep -qx 'PROGRESS.md'; then
    echo "ошибка: изменён docs/plan.md, но PROGRESS.md не изменён — обнови прогресс перед коммитом"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "коммит отклонён: исправь замечания выше"
  exit 1
fi

exit 0
'@
    # LF-переводы строк: с CRLF шебанг ломается на Linux/macOS.
    $hook = $hook -replace "`r`n", "`n"
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($hookPath, $hook, $utf8)
    Write-Host "[OK] .githooks/pre-commit"
}

# Признак исполняемости: без него git молча пропускает хук на Linux/macOS.
if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne 'Win32NT') {
    & chmod +x -- $hookPath
}

# Подключить хук, если это git-репозиторий
$null = git -C "$target" rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0) {
    $hooksAbs = (Join-Path $target '.githooks').Replace('\', '/')
    git -C "$target" config core.hooksPath "$hooksAbs"
    Write-Host "[OK] core.hooksPath = $hooksAbs"

    # Режим 100755 в индексе — иначе после клона на Linux/macOS хук не запустится.
    $ErrorActionPreference = 'Continue'
    git -C "$target" add --chmod=+x -- '.githooks/pre-commit'
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] .githooks/pre-commit добавлен в индекс с признаком исполняемости"
    } else {
        Write-Host "[i]  не удалось выставить признак исполняемости: выполни 'git add --chmod=+x .githooks/pre-commit'"
    }
} else {
    Write-Host "[i]  не git-репозиторий: после git init выполни 'git config core.hooksPath .githooks'"
}

Write-Host ""
Write-Host "Готово. Каркас спецификаций создан в $target"
