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
$expectedTmp = [IO.Path]::GetFullPath((Join-Path $repo 'tests\.tmp'))
if ([IO.Path]::GetFullPath($tmpRoot) -ne $expectedTmp) { throw 'Test cleanup path escaped tests/.tmp' }
if ((Test-Path -LiteralPath $tmpRoot) -and (Get-Item -LiteralPath $tmpRoot -Force).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw 'Refusing test cleanup through a link' }

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

Write-Host "== Тесты обвязки Codex =="
Write-Host "Репозиторий : $repo"
Write-Host "Временно в  : $tmpRoot"
Write-Host ""

# --- 1. Установка в пустой каталог -------------------------------------------
Write-Host "-- установка с нуля"
$cfgFresh = Join-Path $tmpRoot 'config-fresh'
& $install -ConfigDir $cfgFresh | Out-Null

Check 'AGENTS.md установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'AGENTS.md'))
Check 'SKILL.md установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills\project-specifications\SKILL.md'))
Check 'шаблоны установлены' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills\project-specifications\templates\feature.md'))
Check 'генератор установлен' (Test-Path -LiteralPath (Join-Path $cfgFresh 'bin\new-project.ps1'))

$fresh = [System.IO.File]::ReadAllText((Join-Path $cfgFresh 'config.toml'))
Check 'модель перенесена' ($fresh -match '(?m)^model = "gpt-5\.6-sol"$')
Check 'режим песочницы перенесён' ($fresh -match '(?m)^sandbox_mode = "workspace-write"$')

# --- 2. Слияние с существующими настройками ----------------------------------
Write-Host "-- слияние настроек"
$cfgMerge = Join-Path $tmpRoot 'config-merge'
New-Item -ItemType Directory -Force -Path $cfgMerge | Out-Null
Set-Text (Join-Path $cfgMerge 'config.toml') @'
[mcp_servers.example]
command = "example-server"
'@
& $install -ConfigDir $cfgMerge | Out-Null
$merged = [System.IO.File]::ReadAllText((Join-Path $cfgMerge 'config.toml'))

Check 'локальная секция сохранена' ($merged -match '\[mcp_servers\.example\]')
Check 'локальное значение сохранено' ($merged -match 'command = "example-server"')
Check 'ключи репозитория добавлены' ($merged -match '(?m)^model = "gpt-5\.6-sol"$')
Check 'управляемый блок единственный' (([regex]::Matches($merged, 'deepseting managed defaults >>>')).Count -eq 1)
Check 'сделана резервная копия' ((Get-BackupCount $cfgMerge 'config.toml') -eq 1) "копий: $(Get-BackupCount $cfgMerge 'config.toml')"

# --- 3. Повторный запуск идемпотентен ----------------------------------------
Write-Host "-- повторная установка"
& $install -ConfigDir $cfgMerge | Out-Null
$again = [System.IO.File]::ReadAllText((Join-Path $cfgMerge 'config.toml'))
Check 'повторная установка не портит настройки' ($again -match 'command = "example-server"' -and ([regex]::Matches($again, 'deepseting managed defaults >>>')).Count -eq 1)
Check 'лишних резервных копий нет' ((Get-BackupCount $cfgMerge 'config.toml') -eq 1) "копий: $(Get-BackupCount $cfgMerge 'config.toml')"

$installedSkill = Join-Path $cfgMerge 'skills/project-specifications'
Set-Text (Join-Path $installedSkill 'local-notes.md') 'user notes'
Set-Text (Join-Path $installedSkill 'SKILL.md') 'user previous instructions'
& $install -ConfigDir $cfgMerge | Out-Null
Check 'локальные файлы навыка сохраняются' ([IO.File]::ReadAllText((Join-Path $installedSkill 'local-notes.md')) -eq 'user notes')
Check 'изменённый skill сохранён в backup' ((Get-BackupCount $installedSkill 'SKILL.md') -eq 1)
& $install -ConfigDir $cfgMerge | Out-Null
Check 'повторная установка skill не плодит backup' ((Get-BackupCount $installedSkill 'SKILL.md') -eq 1)

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

# --- 10. Повторный scaffolding сохраняет документы --------------------------
Set-Text (Join-Path $proj 'PROGRESS.md') 'existing progress'
& $generator -Path $proj -Feature another | Out-Null
Check 'генератор сохраняет существующий прогресс' ([IO.File]::ReadAllText((Join-Path $proj 'PROGRESS.md')) -eq 'existing progress')
Check 'новая функция добавлена' (Test-Path -LiteralPath (Join-Path $proj 'docs/features/another.md'))

# --- 11. Game Master Plan, включая установленный генератор ------------------
$game = Join-Path $tmpRoot 'game'
Set-Text (Join-Path $game 'specs/master/ACTIVE_STAGE.md') 'stage one'
Invoke-Git $game @('init', '-q') | Out-Null
& (Join-Path $cfgFresh 'bin/new-project.ps1') -Path $game | Out-Null
Check 'Game Master Plan не получает стандартные документы' (-not (Test-Path -LiteralPath (Join-Path $game 'docs')) -and -not (Test-Path -LiteralPath (Join-Path $game '.githooks')))
Set-Text (Join-Path $game 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING'
& $generator -Path $game | Out-Null
Check 'явный STANDARD имеет приоритет над sentinel' (Test-Path -LiteralPath (Join-Path $game 'docs/SPEC.md'))
$invalid = Join-Path $tmpRoot 'invalid-mode'
Set-Text (Join-Path $invalid 'CLAUDE.md') "PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN`nPROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING"
Invoke-Git $invalid @('init', '-q') | Out-Null
$rejected = $false
try { & $generator -Path $invalid | Out-Null } catch { $rejected = $true }
Check 'несколько режимов отклонены до scaffolding' ($rejected -and -not (Test-Path -LiteralPath (Join-Path $invalid 'docs')))

# --- 12. Патчи Skills: реальные файлы, повторный запуск, конфликт ------------
$patcher = Join-Path $repo 'bin/update-skill-guidance.ps1'
$patchCfg = Join-Path $tmpRoot 'patch-config'
$patchManifest = Join-Path $tmpRoot 'patches.json'
$patchFile = Join-Path $patchCfg 'skills/example/SKILL.md'
Set-Text $patchFile 'prefix old guidance suffix'
Set-Text $patchManifest '[{"scope":"Codex","path":"skills/example/SKILL.md","replacements":[{"before":"old guidance","after":"new guidance"}]}]'
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest -CheckOnly | Out-Null
Check 'CheckOnly не меняет skill' ([IO.File]::ReadAllText($patchFile) -eq 'prefix old guidance suffix')
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null
Check 'патч сохраняет окружающий текст' ([IO.File]::ReadAllText($patchFile) -eq 'prefix new guidance suffix')
$backupDir = Split-Path -Parent $patchFile
Check 'патч сохраняет backup' ((Get-BackupCount $backupDir 'SKILL.md') -eq 1)
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null
Check 'повторный патч не плодит backup' ((Get-BackupCount $backupDir 'SKILL.md') -eq 1)
Set-Text $patchFile 'prefix old guidance suffix'
Set-Text (Join-Path $patchCfg 'skills/changed/SKILL.md') 'unrecognized version'
Set-Text $patchManifest '[{"scope":"Codex","path":"skills/example/SKILL.md","replacements":[{"before":"old guidance","after":"new guidance"}]},{"scope":"Codex","path":"skills/changed/SKILL.md","replacements":[{"before":"expected version","after":"updated version"}]}]'
$rejected = $false
try { & $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null } catch { $rejected = $true }
Check 'конфликт второго файла предотвращает запись первого' ($rejected -and [IO.File]::ReadAllText($patchFile) -eq 'prefix old guidance suffix')
Set-Text $patchManifest '[{"scope":"Codex","path":"../outside.md","replacements":[{"before":"old","after":"new"}]}]'
$rejected = $false
try { & $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null } catch { $rejected = $true }
Check 'патч не выходит за выбранный каталог' $rejected

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
