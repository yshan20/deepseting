# Explicitly initializes minimal optional project documentation.
# Usage: pwsh -File new-project.ps1 [path] [-Feature <name>]

[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$Feature
)

$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

# A nested invocation targets the Git root. Directories without Git are used as-is.
$oldPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$gitOutput = & git -C $target rev-parse --show-toplevel 2>&1
$gitCode = $LASTEXITCODE
$ErrorActionPreference = $oldPreference
if ($gitCode -eq 0) {
    $target = ($gitOutput | Out-String).Trim()
} elseif (($gitOutput | Out-String) -notmatch 'not a git repository') {
    throw "Cannot determine repository root: $gitOutput"
}

. (Join-Path $PSScriptRoot 'project-orchestration.ps1')
$mode = Get-ProjectOrchestrationMode $target
Write-Host "[i] PROJECT_ORCHESTRATION_MODE: $mode"
if ($mode -eq 'GAME_MASTER_PLAN') {
    Write-Warning 'Game Master Plan detected. No parallel documentation was created.'
    return
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$safe = $null
if ($Feature) {
    $safe = $Feature.Trim().ToLowerInvariant()
    $safe = [regex]::Replace($safe, '[^\p{L}\p{Nd}._-]+', '-')
    $safe = $safe.Trim('.', '-', '_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        throw 'Feature name must contain at least one letter or digit.'
    }
}

function Write-NewFile([string]$Destination, [string]$Content) {
    if (Test-Path -LiteralPath $Destination) {
        Write-Host "[i] $Destination already exists - skipped"
        return $false
    }
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($Destination, ($Content -replace "`r`n", "`n"), $utf8)
    Write-Host "[OK] $Destination"
    return $true
}

$projectName = Split-Path $target -Leaf
$readmeText = @'
# __PROJECT__

<!-- Кратко: назначение проекта, запуск и проверки. -->
'@.Replace('__PROJECT__', $projectName)
Write-NewFile (Join-Path $target 'README.md') $readmeText | Out-Null

if ($Feature) {
    $configDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    $template = $null
    foreach ($candidate in @(
            (Join-Path $PSScriptRoot '..\codex\skills\project-specifications\templates\feature-brief.md'),
            (Join-Path $PSScriptRoot '..\skills\project-specifications\templates\feature-brief.md'),
            (Join-Path $configDir 'skills\project-specifications\templates\feature-brief.md')
        )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $template = $candidate; break }
    }
    if (-not $template) { throw 'Feature brief template was not found.' }

    $brief = [System.IO.File]::ReadAllText($template).Replace('__FEATURE__', $Feature.Trim())
    Write-NewFile (Join-Path $target "docs\specs\$safe.md") $brief | Out-Null
}

Write-Host "Ready: minimal documentation initialized in $target"
