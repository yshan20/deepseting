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
    $content = @"
# $leaf

Краткое описание структуры проекта.

## Структура

- `docs/SPEC.md` — центральная спецификация (система, границы, ключевые решения).
- `docs/features/` — спецификации отдельных функций.
- `docs/plan.md` — план реализации текущей функции.
- `PROGRESS.md` — прогресс (сделано / заблокировано / пропущено / решения без указания).

## Спецификации и проверки

- Критерии готовности в `docs/features/*.md` — таблица с обязательной колонкой «Чем проверяется».
- Критерии готовности утверждает человек до начала работы над планом.
- Git pre-commit хук в `.githooks/pre-commit` (подключён через `core.hooksPath`) отклоняет коммит, если в критериях есть пустая колонка «Чем проверяется» или изменён `docs/plan.md` без изменения `PROGRESS.md`.

## Запуск / сборка / тесты

<!-- как запускать, собирать и тестировать проект -->
"@
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

for f in docs/features/*.md; do
  [ -e "$f" ] || continue
  awk -F'|' '
    BEGIN { bad = 0 }
    /^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      check = $NF
      if (check ~ /^[[:space:]]*$/) check = $(NF - 1)
      if (check ~ /^[[:space:]]*$/) {
        printf "%s:%d: ошибка: пустая колонка «Чем проверяется» в критерии готовности\n", FILENAME, NR
        bad = 1
      }
    }
    END { exit bad }
  ' "$f" || fail=1
done

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
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($hookPath, $hook, $utf8)
    Write-Host "[OK] .githooks/pre-commit"
}

# Подключить хук, если это git-репозиторий
$null = git -C "$target" rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0) {
    $hooksAbs = (Join-Path $target '.githooks').Replace('\', '/')
    git -C "$target" config core.hooksPath "$hooksAbs"
    Write-Host "[OK] core.hooksPath = $hooksAbs"
} else {
    Write-Host "[i]  не git-репозиторий: после git init выполни 'git config core.hooksPath .githooks'"
}

Write-Host ""
Write-Host "Готово. Каркас спецификаций создан в $target"
