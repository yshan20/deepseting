# install.ps1 — разворачивает настройки DeepSeek Harness (DSH) в ~/.dsh
#
# Запуск:
#   pwsh -File install.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Каталог настроек DSH: $env:DSH_HOME или ~/.dsh
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$repo = $PSScriptRoot

Write-Host "== DeepSeek Harness: установка настроек =="
Write-Host "DSH home    : $dshHome"
Write-Host "Репозиторий : $repo"
Write-Host ""

New-Item -ItemType Directory -Force -Path $dshHome | Out-Null

# 1. Переносимые файлы настроек
$files = @('AGENTS.md', 'settings.yaml')
foreach ($name in $files) {
    $src = Join-Path $repo $name
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "Пропущен (нет в репозитории): $name"
        continue
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $dshHome $name) -Force
    Write-Host "[OK] $name -> $(Join-Path $dshHome $name)"
}

# 2. Скилл спецификаций -> ~/.dsh/skills/project-specifications
$skillSrc = Join-Path $repo 'skill\project-specifications'
$skillDst = Join-Path $dshHome 'skills\project-specifications'
if (Test-Path -LiteralPath $skillSrc) {
    New-Item -ItemType Directory -Force -Path $skillDst | Out-Null
    Copy-Item -Path (Join-Path $skillSrc '*') -Destination $skillDst -Recurse -Force
    Write-Host "[OK] skill -> $skillDst"
} else {
    Write-Warning "Скилл не найден: $skillSrc"
}

# 3. Генератор -> ~/.dsh/bin/new-project.ps1
$genSrc = Join-Path $repo 'new-project.ps1'
if (Test-Path -LiteralPath $genSrc) {
    $binDir = Join-Path $dshHome 'bin'
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    Copy-Item -LiteralPath $genSrc -Destination (Join-Path $binDir 'new-project.ps1') -Force
    Write-Host "[OK] new-project.ps1 -> $(Join-Path $binDir 'new-project.ps1')"
} else {
    Write-Warning "Генератор не найден: $genSrc"
}

# 4. API-ключ (секрет) — по желанию, в репозиторий не попадает
$credFile = Join-Path $dshHome '.credentials.yaml'
$key = (Read-Host "Вставь DEEPSEEK_API_KEY (или Enter, чтобы пропустить)").Trim()
if ($key -ne '') {
    Set-Content -LiteralPath $credFile -Value "DEEPSEEK_API_KEY: $key" -Encoding ascii
    Write-Host "[OK] создан $credFile"
} elseif (Test-Path -LiteralPath $credFile) {
    Write-Host "[i]  $credFile уже существует — оставлен без изменений"
} else {
    Write-Host "[i]  ключ пропущен. Создай $credFile вручную: DEEPSEEK_API_KEY: <ключ>"
}

Write-Host ""
Write-Host "Готово. Перезапусти DSH, чтобы настройки подхватились."
Write-Host "Новый проект: pwsh $(Join-Path $dshHome 'bin\new-project.ps1') <путь>"
