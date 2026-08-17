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
- `PROGRESS.md` — прогресс (сделано / заблокировано / пропущено).

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

Write-Host ""
Write-Host "Готово. Каркас спецификаций создан в $target"
