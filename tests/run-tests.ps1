# run-tests.ps1 — проверяет установщик, генератор проектов и pre-commit хук.
#
# Запуск:
#   pwsh -File tests/run-tests.ps1
#   pwsh -File tests/run-tests.ps1 -Keep   # не удалять tests/.tmp после прогона
#
# Совместим с Windows PowerShell 5.1 и PowerShell 7+. Нужны git и sh (Git for Windows подходит).

[CmdletBinding()]
param(
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$install = Join-Path $repo 'install.ps1'
$generator = Join-Path $repo 'bin\new-project.ps1'
$tmpRoot = Join-Path $PSScriptRoot '.tmp'

if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$script:passed = 0
$script:failed = 0

function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) {
        $script:passed++
        Write-Host "[ OK ] $Name"
    } else {
        $script:failed++
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "       $Detail" -ForegroundColor Red }
    }
}

function Set-Text([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8)
}

# Native-команды не должны срывать выполнение через $ErrorActionPreference = 'Stop'.
function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git -C $Dir @GitArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    return [pscustomobject]@{ Code = $code; Out = $out }
}

function Read-Json([string]$Path) {
    return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Get-BackupCount([string]$Dir, [string]$Name) {
    return @(Get-ChildItem -LiteralPath $Dir -Filter "$Name.bak-*" -ErrorAction SilentlyContinue).Count
}

Write-Host "== Тесты обвязки Claude Code =="
Write-Host "Репозиторий : $repo"
Write-Host "Временно в  : $tmpRoot"
Write-Host ""

# --- 1. Установка в пустой каталог -------------------------------------------
Write-Host "-- установка с нуля"
$cfgFresh = Join-Path $tmpRoot 'config-fresh'
& $install -ConfigDir $cfgFresh | Out-Null

Check 'CLAUDE.md установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'CLAUDE.md'))
Check 'SKILL.md установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills\project-specifications\SKILL.md'))
Check 'шаблоны установлены' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills\project-specifications\templates\feature.md'))
Check 'генератор установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'bin\new-project.ps1'))

$fresh = Read-Json (Join-Path $cfgFresh 'settings.json')
Check 'модель перенесена' ($fresh.model -eq 'opus') "получено: $($fresh.model)"
Check 'режим прав перенесён' ($fresh.permissions.defaultMode -eq 'auto') "получено: $($fresh.permissions.defaultMode)"

# --- 2. Слияние с существующими настройками ----------------------------------
Write-Host "-- слияние настроек"
$cfgMerge = Join-Path $tmpRoot 'config-merge'
New-Item -ItemType Directory -Force -Path $cfgMerge | Out-Null
Set-Text (Join-Path $cfgMerge 'settings.json') @'
{
  "permissions": { "defaultMode": "plan", "allow": ["Bash(ls:*)"] },
  "statusLine": { "type": "command", "command": "echo hi" }
}
'@
& $install -ConfigDir $cfgMerge | Out-Null
$merged = Read-Json (Join-Path $cfgMerge 'settings.json')

Check 'чужие ключи сохранены' ($merged.statusLine.command -eq 'echo hi')
Check 'вложенные чужие ключи сохранены' (@($merged.permissions.allow) -contains 'Bash(ls:*)')
Check 'ключи репозитория побеждают' ($merged.permissions.defaultMode -eq 'auto') "получено: $($merged.permissions.defaultMode)"
Check 'новые ключи добавлены' ($merged.model -eq 'opus')
Check 'сделана резервная копия' ((Get-BackupCount $cfgMerge 'settings.json') -eq 1) "копий: $(Get-BackupCount $cfgMerge 'settings.json')"

# --- 3. Повторный запуск идемпотентен ----------------------------------------
Write-Host "-- повторная установка"
& $install -ConfigDir $cfgMerge | Out-Null
$again = Read-Json (Join-Path $cfgMerge 'settings.json')
Check 'повторная установка не портит настройки' ($again.statusLine.command -eq 'echo hi' -and $again.model -eq 'opus')
Check 'лишних резервных копий нет' ((Get-BackupCount $cfgMerge 'settings.json') -eq 1) "копий: $(Get-BackupCount $cfgMerge 'settings.json')"

# --- 4. Каркас нового проекта -------------------------------------------------
Write-Host "-- каркас проекта"
$proj = Join-Path $tmpRoot 'project'
New-Item -ItemType Directory -Force -Path $proj | Out-Null
Invoke-Git $proj @('init', '-q') | Out-Null
Invoke-Git $proj @('config', 'user.email', 'tests@example.com') | Out-Null
Invoke-Git $proj @('config', 'user.name', 'harness tests') | Out-Null
Invoke-Git $proj @('config', 'commit.gpgsign', 'false') | Out-Null

& $generator -Path $proj -Feature demo | Out-Null

foreach ($rel in @('README.md', 'docs\SPEC.md', 'docs\plan.md', 'PROGRESS.md', 'docs\features\demo.md', '.githooks\pre-commit')) {
    Check "создан $rel" (Test-Path -LiteralPath (Join-Path $proj $rel))
}
$hooksPath = (Invoke-Git $proj @('config', 'core.hooksPath')).Out.Trim()
Check 'хук подключён через core.hooksPath' ($hooksPath -like '*.githooks') "получено: $hooksPath"

# --- 5. Хук отклоняет пустую колонку «Чем проверяется» ------------------------
Write-Host "-- хук: пустой критерий"
Invoke-Git $proj @('add', '-A') | Out-Null
$commitEmpty = Invoke-Git $proj @('commit', '-m', 'scaffold')
Check 'коммит с пустым критерием отклонён' ($commitEmpty.Code -ne 0) "код: $($commitEmpty.Code)"
Check 'в ошибке указан файл критерия' ($commitEmpty.Out -match 'docs/features/demo.md') $commitEmpty.Out

# --- 6. Заполненные критерии проходят ----------------------------------------
Write-Host "-- хук: заполненный критерий"
Set-Text (Join-Path $proj 'docs\features\demo.md') @'
# Демо-функция

## Цель

Проверить хук.

## Критерии готовности

| # | Что должно стать правдой | Чем проверяется |
|---|--------------------------|-----------------|
| 1 | Хук пропускает заполненные критерии | tests/run-tests.ps1 |
'@
Invoke-Git $proj @('add', '-A') | Out-Null
$commitOk = Invoke-Git $proj @('commit', '-m', 'scaffold')
Check 'коммит с заполненным критерием принят' ($commitOk.Code -eq 0) $commitOk.Out

# --- 7. Раздел без нужной колонки отклоняется --------------------------------
Write-Host "-- хук: критерии без колонки"
Set-Text (Join-Path $proj 'docs\features\nocol.md') @'
# Функция без колонки

## Критерии готовности

| # | Что должно стать правдой |
|---|--------------------------|
| 1 | Что-то работает |
'@
Invoke-Git $proj @('add', '-A') | Out-Null
$commitNoCol = Invoke-Git $proj @('commit', '-m', 'no column')
Check 'коммит без колонки «Чем проверяется» отклонён' ($commitNoCol.Code -ne 0) "код: $($commitNoCol.Code)"
Invoke-Git $proj @('reset', '-q') | Out-Null
Remove-Item -LiteralPath (Join-Path $proj 'docs\features\nocol.md') -Force

# --- 8. Архив docs/features/done/ не проверяется ------------------------------
Write-Host "-- хук: архив done/"
Set-Text (Join-Path $proj 'docs\features\done\old.md') @'
# Завершённая функция

## Критерии готовности

| # | Что должно стать правдой | Чем проверяется |
|---|--------------------------|-----------------|
| 1 | Уже неважно |                 |
'@
Invoke-Git $proj @('add', '-A') | Out-Null
$commitDone = Invoke-Git $proj @('commit', '-m', 'archive')
Check 'архив done/ не проверяется' ($commitDone.Code -eq 0) $commitDone.Out

# --- 9. plan.md без PROGRESS.md ----------------------------------------------
Write-Host "-- хук: план без прогресса"
Add-Content -LiteralPath (Join-Path $proj 'docs\plan.md') -Value '| 3 | Ещё пункт | Готово | tests |'
Invoke-Git $proj @('add', 'docs/plan.md') | Out-Null
$commitPlan = Invoke-Git $proj @('commit', '-m', 'plan only')
Check 'план без прогресса отклонён' ($commitPlan.Code -ne 0) "код: $($commitPlan.Code)"

Add-Content -LiteralPath (Join-Path $proj 'PROGRESS.md') -Value '- Пункт 3 сделан.'
Invoke-Git $proj @('add', 'PROGRESS.md') | Out-Null
$commitBoth = Invoke-Git $proj @('commit', '-m', 'plan and progress')
Check 'план вместе с прогрессом принят' ($commitBoth.Code -eq 0) $commitBoth.Out

# --- Итог --------------------------------------------------------------------
Write-Host ""
Write-Host "Пройдено: $($script:passed), провалено: $($script:failed)"

if (-not $Keep) {
    # Файлы внутри .git помечены только для чтения — снимаем атрибут перед удалением.
    Get-ChildItem -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:failed -gt 0) { exit 1 }
exit 0
