# install.ps1 — разворачивает настройки DeepSeek Harness (DSH) в ~/.dsh
#
# Запуск:
#   pwsh -File install.ps1
#   (или: правый клик по файлу -> "Run with PowerShell")

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

# Создать каталог при необходимости
New-Item -ItemType Directory -Force -Path $dshHome | Out-Null

# 1. Скопировать переносимые файлы настроек
$files = @('AGENTS.md', 'settings.yaml')
foreach ($name in $files) {
    $src = Join-Path $repo $name
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "Пропущен (нет в репозитории): $name"
        continue
    }
    $dst = Join-Path $dshHome $name
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host "[OK] $name -> $dst"
}

# 2. API-ключ (секрет) — только по желанию, в репозиторий не попадает
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
