# install.ps1 — installs the portable Codex harness into ~/.codex.
[CmdletBinding()]
param([string]$ConfigDir, [switch]$ApplySkillPatches, [string]$AgentSkillsDir)

$ErrorActionPreference = 'Stop'
$configDir = if ($ConfigDir) { $ConfigDir } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$repo = $PSScriptRoot
$payload = Join-Path $repo 'codex'
$startMarker = '# >>> deepseting managed defaults >>>'
$endMarker = '# <<< deepseting managed defaults <<<'

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8)
}

function Backup-IfDifferent([string]$Path, [string]$NewText) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $current = [System.IO.File]::ReadAllText($Path)
    if ($current -eq $NewText) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
}

Write-Host '== Codex: установка обвязки =='
Write-Host "Каталог настроек : $configDir"
if (-not (Test-Path -LiteralPath $payload)) { throw "Не найден каталог настроек: $payload" }
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

$rulesSrc = Join-Path $payload 'AGENTS.md'
$rulesDst = Join-Path $configDir 'AGENTS.md'
$rulesText = [System.IO.File]::ReadAllText($rulesSrc)
Backup-IfDifferent $rulesDst $rulesText
Write-Utf8NoBom $rulesDst $rulesText
Write-Host "[OK] AGENTS.md -> $rulesDst"

# Replace only our marked block; preserve local plugins, MCP servers and projects.
$settingsSrc = Join-Path $payload 'config.toml'
$settingsDst = Join-Path $configDir 'config.toml'
$managed = [System.IO.File]::ReadAllText($settingsSrc).Trim()
$existing = if (Test-Path -LiteralPath $settingsDst) { [System.IO.File]::ReadAllText($settingsDst) } else { '' }
$pattern = '(?ms)^' + [regex]::Escape($startMarker) + '.*?^' + [regex]::Escape($endMarker) + '\s*'
$preserved = [regex]::Replace($existing, $pattern, '').Trim()
$settingsText = "$startMarker`n$managed`n$endMarker"
if ($preserved) { $settingsText += "`n`n$preserved" }
$settingsText += "`n"
Backup-IfDifferent $settingsDst $settingsText
Write-Utf8NoBom $settingsDst $settingsText
Write-Host "[OK] config.toml -> $settingsDst"

$skillSrc = Join-Path $payload 'skills\project-specifications'
$skillDst = Join-Path $configDir 'skills\project-specifications'
foreach ($file in Get-ChildItem -LiteralPath $skillSrc -Recurse -File) {
    $relative = $file.FullName.Substring($skillSrc.Length).TrimStart('\', '/')
    $destination = Join-Path $skillDst $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $skillText = [IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")
    Backup-IfDifferent $destination $skillText
    Write-Utf8NoBom $destination $skillText
}
Write-Host "[OK] skill project-specifications -> $skillDst"

$binDir = Join-Path $configDir 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'bin\new-project.ps1') -Destination (Join-Path $binDir 'new-project.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repo 'bin\project-orchestration.ps1') -Destination (Join-Path $binDir 'project-orchestration.ps1') -Force
Write-Host "[OK] new-project.ps1 -> $(Join-Path $binDir 'new-project.ps1')"
if ($ApplySkillPatches) {
    & (Join-Path $repo 'bin\update-skill-guidance.ps1') -ConfigDir $configDir -AgentSkillsDir $AgentSkillsDir
}
Write-Host 'Готово. Перезапусти Codex, чтобы настройки подхватились.'
Write-Host 'Вход в аккаунт: codex login (секреты в репозитории не хранятся).'
