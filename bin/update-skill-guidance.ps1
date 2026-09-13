# Apply reviewed instruction changes to existing skills; never install dependencies.
[CmdletBinding()]
param(
    [string]$ConfigDir,
    [string]$AgentSkillsDir,
    [string]$WorkshopDir,
    [string]$ManifestPath,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
if (-not $ManifestPath) { $ManifestPath = Join-Path $PSScriptRoot '..\codex\skill-patches.json' }
$codexRoot = if ($ConfigDir) { $ConfigDir } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$roots = @{ Codex = [IO.Path]::GetFullPath($codexRoot) }
# Shared skill directories require an explicit target, rather than silently changing another agent's skills.
if ($AgentSkillsDir) { $roots.AgentSkills = [IO.Path]::GetFullPath($AgentSkillsDir) }
if ($WorkshopDir) { $roots.Workshop = [IO.Path]::GetFullPath($WorkshopDir) }
$manifest = [IO.File]::ReadAllText($ManifestPath) | ConvertFrom-Json
$pending = @()
foreach ($entry in $manifest) {
    if ($entry.scope -notin @('Codex', 'AgentSkills', 'Workshop')) { throw "Unknown skill scope: $($entry.scope)" }
    if (-not $roots.ContainsKey($entry.scope)) {
        Write-Host "[SKIP] $($entry.scope)/$($entry.path): scope not selected"
        continue
    }
    $root = $roots[$entry.scope].TrimEnd('\', '/')
    if ([IO.Path]::IsPathRooted($entry.path)) { throw "Absolute manifest path: $($entry.path)" }
    $path = [IO.Path]::GetFullPath((Join-Path $root $entry.path))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Skill path escapes selected root: $($entry.path)"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "[SKIP] $($entry.scope)/$($entry.path): not installed"
        continue
    }
    $original = [IO.File]::ReadAllText($path)
    $text = $original.Replace("`r`n", "`n")
    foreach ($replacement in $entry.replacements) {
        if (-not $replacement.before -or -not $replacement.after) { throw "Empty replacement: $path" }
        $beforeCount = [regex]::Matches($text, [regex]::Escape($replacement.before)).Count
        $afterCount = [regex]::Matches($text, [regex]::Escape($replacement.after)).Count
        if ($beforeCount -eq 1 -and $afterCount -eq 0) {
            $text = $text.Replace($replacement.before, $replacement.after)
        } elseif ($beforeCount -eq 0 -and $afterCount -eq 1) {
            # Already applied: no backup or write required.
        } else {
            throw "Skill differs from the reviewed version; no files written. Inspect: $path"
        }
    }
    if ($text -ne $original.Replace("`r`n", "`n")) {
        $pending += [pscustomobject]@{ Path = $path; Text = $text; Original = $original }
    } else { Write-Host "[OK] already current: $path" }
}
# All installed targets are checked before the first write.
foreach ($item in $pending) {
    if ($CheckOnly) { Write-Host "[CHECK] would update: $($item.Path)"; continue }
    if ([IO.File]::ReadAllText($item.Path) -cne $item.Original) { throw "File changed during patching: $($item.Path)" }
    $backup = $item.Path + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fffffff')
    Copy-Item -LiteralPath $item.Path -Destination $backup
    [IO.File]::WriteAllText($item.Path, $item.Text, (New-Object Text.UTF8Encoding($false)))
    Write-Host "[OK] updated: $($item.Path)"
}
Write-Host "Skill files requiring changes: $($pending.Count)"
