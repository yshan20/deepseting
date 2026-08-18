# install.ps1 — разворачивает обвязку Claude Code в каталог настроек (~/.claude).
#
# Запуск:
#   pwsh -File install.ps1                     # в ~/.claude (или $env:CLAUDE_CONFIG_DIR)
#   pwsh -File install.ps1 -ConfigDir <путь>   # в произвольный каталог
#
# Скрипт неинтерактивен: ничего не спрашивает и годится для CI.
# Существующие файлы, которые отличаются от новых, сохраняются рядом как *.bak-<дата>.

[CmdletBinding()]
param(
    [string]$ConfigDir
)

$ErrorActionPreference = 'Stop'

# Каталог настроек: -ConfigDir, иначе $env:CLAUDE_CONFIG_DIR, иначе ~/.claude
$configDir = if ($ConfigDir) {
    $ConfigDir
} elseif ($env:CLAUDE_CONFIG_DIR) {
    $env:CLAUDE_CONFIG_DIR
} else {
    Join-Path $HOME '.claude'
}
$repo = $PSScriptRoot
$payload = Join-Path $repo 'claude'

Write-Host "== Claude Code: установка обвязки =="
Write-Host "Каталог настроек : $configDir"
Write-Host "Репозиторий      : $repo"
Write-Host ""

if (-not (Test-Path -LiteralPath $payload)) {
    throw "Не найден каталог с настройками: $payload"
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

# UTF-8 без BOM: файлы читают и Claude Code, и git, и sh.
function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Копия существующего файла, если его содержимое отличается от нового.
function Backup-IfDifferent([string]$Path, [string]$NewText) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $current = [System.IO.File]::ReadAllText($Path)
    if ($current -eq $NewText) { return $false }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$Path.bak-$stamp"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    Write-Host "[i]  прежняя версия сохранена: $bak"
    return $true
}

# Рекурсивное слияние JSON-объектов: значения из $Overlay побеждают,
# вложенные объекты сливаются по ключам, массивы заменяются целиком.
function Merge-JsonObject($Base, $Overlay) {
    if ($null -eq $Base) { return $Overlay }
    if ($Overlay -isnot [pscustomobject]) { return $Overlay }
    if ($Base -isnot [pscustomobject]) { return $Overlay }
    foreach ($prop in $Overlay.PSObject.Properties) {
        $name = $prop.Name
        if ($Base.PSObject.Properties.Name -contains $name) {
            $Base.$name = Merge-JsonObject $Base.$name $prop.Value
        } else {
            $Base | Add-Member -NotePropertyName $name -NotePropertyValue $prop.Value
        }
    }
    return $Base
}

# 1. Глобальные правила -> <config>/CLAUDE.md
$rulesSrc = Join-Path $payload 'CLAUDE.md'
$rulesDst = Join-Path $configDir 'CLAUDE.md'
$rulesText = [System.IO.File]::ReadAllText($rulesSrc)
Backup-IfDifferent $rulesDst $rulesText | Out-Null
Write-Utf8NoBom $rulesDst $rulesText
Write-Host "[OK] CLAUDE.md -> $rulesDst"

# 2. Настройки -> <config>/settings.json (слияние, а не перезапись:
#    в файле уже могут быть плагины, хуки и права, добавленные на этой машине).
$settingsSrc = Join-Path $payload 'settings.json'
$settingsDst = Join-Path $configDir 'settings.json'
$overlay = [System.IO.File]::ReadAllText($settingsSrc) | ConvertFrom-Json
$merged = $overlay
if (Test-Path -LiteralPath $settingsDst) {
    $existingText = [System.IO.File]::ReadAllText($settingsDst)
    try {
        $existing = $existingText | ConvertFrom-Json
        $merged = Merge-JsonObject $existing $overlay
    } catch {
        Write-Warning "settings.json на диске — не валидный JSON, он будет сохранён в резервную копию и заменён."
    }
}
$mergedText = ($merged | ConvertTo-Json -Depth 20)
Backup-IfDifferent $settingsDst $mergedText | Out-Null
Write-Utf8NoBom $settingsDst $mergedText
Write-Host "[OK] settings.json -> $settingsDst"

# 3. Скилл -> <config>/skills/project-specifications
#    Каталог назначения очищается: иначе в нём остаются шаблоны, удалённые из репозитория.
$skillSrc = Join-Path $payload 'skills\project-specifications'
$skillDst = Join-Path $configDir 'skills\project-specifications'
if (Test-Path -LiteralPath $skillDst) { Remove-Item -LiteralPath $skillDst -Recurse -Force }
New-Item -ItemType Directory -Force -Path $skillDst | Out-Null
Copy-Item -Path (Join-Path $skillSrc '*') -Destination $skillDst -Recurse -Force
Write-Host "[OK] skill project-specifications -> $skillDst"

# 4. Генератор проектов -> <config>/bin/new-project.ps1
$genSrc = Join-Path $repo 'bin\new-project.ps1'
$binDir = Join-Path $configDir 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Copy-Item -LiteralPath $genSrc -Destination (Join-Path $binDir 'new-project.ps1') -Force
Write-Host "[OK] new-project.ps1 -> $(Join-Path $binDir 'new-project.ps1')"

Write-Host ""
Write-Host "Готово. Перезапусти Claude Code, чтобы настройки подхватились."
Write-Host "Вход в аккаунт   : claude  ->  /login   (ключ API в репозитории не хранится)"
Write-Host "Новый проект     : pwsh -File $(Join-Path $binDir 'new-project.ps1') <путь-к-проекту>"
