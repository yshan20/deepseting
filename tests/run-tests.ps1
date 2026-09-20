# Integration tests for the Codex installer, initializer and skill patcher.
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$install = Join-Path $repo 'install.ps1'
$generator = Join-Path $repo 'bin\new-project.ps1'
$patcher = Join-Path $repo 'bin\update-skill-guidance.ps1'
$tmpRoot = Join-Path $PSScriptRoot '.tmp'
$expectedTmp = [IO.Path]::GetFullPath((Join-Path $repo 'tests/.tmp'))

if ([IO.Path]::GetFullPath($tmpRoot) -ne $expectedTmp) { throw 'Unexpected cleanup path.' }
if (Test-Path -LiteralPath $tmpRoot) {
    $item = Get-Item -LiteralPath $tmpRoot -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clean a linked test directory.' }
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}
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
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8)
}

function Read-Text([string]$Path) { return [IO.File]::ReadAllText($Path) }
function Backup-Count([string]$Dir, [string]$Pattern) {
    return @(Get-ChildItem -LiteralPath $Dir -Filter $Pattern -ErrorAction SilentlyContinue).Count
}
function Invoke-Git([string]$Dir, [string[]]$Arguments) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git -C $Dir @Arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    return [pscustomobject]@{ Code = $code; Output = $output }
}
function New-GitFixture([string]$Name) {
    $path = Join-Path $tmpRoot $Name
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    $result = Invoke-Git $path @('init', '-q')
    if ($result.Code -ne 0) { throw "git init failed: $($result.Output)" }
    return $path
}
function Snapshot([string]$Path) {
    $entries = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })) {
        $relative = $file.FullName.Substring($Path.Length).TrimStart('\', '/')
        $entries += "$relative=$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
    }
    return @($entries | Sort-Object)
}

Write-Host '== deepseting Codex tests =='

Write-Host '-- fresh install'
$cfgFresh = Join-Path $tmpRoot 'config-fresh'
& $install -ConfigDir $cfgFresh | Out-Null
foreach ($relative in @('AGENTS.md', 'config.toml', 'skills/project-specifications/SKILL.md', 'skills/project-specifications/templates/feature-brief.md', 'skills/project-specifications/references/game-master-plan.md', 'bin/new-project.ps1', 'bin/project-orchestration.ps1')) {
    Check "installed $relative" (Test-Path -LiteralPath (Join-Path $cfgFresh $relative) -PathType Leaf)
}
$templates = @(Get-ChildItem -LiteralPath (Join-Path $cfgFresh 'skills/project-specifications/templates') -File)
Check 'only one lean template is installed' ($templates.Count -eq 1 -and $templates[0].Name -eq 'feature-brief.md') ($templates.Name -join ', ')
$freshConfig = Read-Text (Join-Path $cfgFresh 'config.toml')
Check 'model installed' ($freshConfig -match '(?m)^model = "gpt-5\.6-sol"$')
Check 'sandbox mode installed' ($freshConfig -match '(?m)^sandbox_mode = "workspace-write"$')
Check 'managed config block is unique' (([regex]::Matches($freshConfig, 'deepseting managed defaults >>>')).Count -eq 1)
& $install -ConfigDir $cfgFresh -ApplySkillPatches | Out-Null
Check 'ApplySkillPatches remains callable' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills/project-specifications/SKILL.md'))

Write-Host '-- marked config merge and idempotence'
$cfgMerge = Join-Path $tmpRoot 'config-merge'
New-Item -ItemType Directory -Force -Path $cfgMerge | Out-Null
Set-Text (Join-Path $cfgMerge 'config.toml') @'
[mcp_servers.example]
command = "example-server"

[projects.'D:\work']
trust_level = "trusted"
'@
& $install -ConfigDir $cfgMerge | Out-Null
$merged = Read-Text (Join-Path $cfgMerge 'config.toml')
Check 'local MCP section survives merge' ($merged -match '\[mcp_servers\.example\]')
Check 'trusted project survives merge' ($merged -match "\[projects\.'D:\\work'\]")
Check 'managed values are added' ($merged -match '(?m)^model = "gpt-5\.6-sol"$')
Check 'changed config receives one backup' ((Backup-Count $cfgMerge 'config.toml.bak-*') -eq 1)
$mergedHash = (Get-FileHash -LiteralPath (Join-Path $cfgMerge 'config.toml') -Algorithm SHA256).Hash
& $install -ConfigDir $cfgMerge | Out-Null
Check 'repeat install keeps merged config stable' ((Get-FileHash -LiteralPath (Join-Path $cfgMerge 'config.toml') -Algorithm SHA256).Hash -eq $mergedHash)
Check 'repeat install creates no config backup' ((Backup-Count $cfgMerge 'config.toml.bak-*') -eq 1)

Write-Host '-- skill tree replacement and external backup'
$installedSkill = Join-Path $cfgMerge 'skills/project-specifications'
Set-Text (Join-Path $installedSkill 'local-notes.md') 'user notes'
Set-Text (Join-Path $installedSkill 'templates/obsolete.md') 'old template'
Set-Text (Join-Path $installedSkill 'SKILL.md') 'user previous instructions'
& $install -ConfigDir $cfgMerge | Out-Null
$skillBackupRoot = Join-Path $cfgMerge 'backups/skills'
$skillBackups = @(Get-ChildItem -LiteralPath $skillBackupRoot -Directory -Filter 'project-specifications-*')
Check 'changed skill tree gets one external backup' ($skillBackups.Count -eq 1)
Check 'skill backup is outside discovery tree' ($skillBackups[0].FullName -notlike "$installedSkill*")
Check 'skill backup preserves local files' ((Read-Text (Join-Path $skillBackups[0].FullName 'local-notes.md')) -eq 'user notes')
Check 'stale skill files are removed from installation' (-not (Test-Path -LiteralPath (Join-Path $installedSkill 'local-notes.md')) -and -not (Test-Path -LiteralPath (Join-Path $installedSkill 'templates/obsolete.md')))
Check 'installed skill matches payload' ((Get-FileHash -LiteralPath (Join-Path $installedSkill 'SKILL.md')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $repo 'codex/skills/project-specifications/SKILL.md')).Hash)
& $install -ConfigDir $cfgMerge | Out-Null
Check 'repeat skill install creates no extra backup' (@(Get-ChildItem -LiteralPath $skillBackupRoot -Directory -Filter 'project-specifications-*').Count -eq 1)

Write-Host '-- minimal initializer'
$project = New-GitFixture 'project'
Invoke-Git $project @('config', 'core.hooksPath', 'custom-hooks') | Out-Null
$nested = Join-Path $project 'src/nested'
New-Item -ItemType Directory -Force -Path $nested | Out-Null
& $generator -Path $nested -Feature '../Danger Name?' | Out-Null
Check 'nested invocation creates root README' (Test-Path -LiteralPath (Join-Path $project 'README.md') -PathType Leaf)
Check 'feature name is normalized safely' (Test-Path -LiteralPath (Join-Path $project 'docs/specs/danger-name.md') -PathType Leaf)
Check 'feature brief contains original title' ((Read-Text (Join-Path $project 'docs/specs/danger-name.md')) -match '# \.\./Danger Name\?')
foreach ($relative in @('docs/SPEC.md', 'docs/plan.md', 'PROGRESS.md', 'docs/features', '.githooks')) {
    Check "initializer omits $relative" (-not (Test-Path -LiteralPath (Join-Path $project $relative)))
}
Check 'initializer preserves core.hooksPath' ((Invoke-Git $project @('config', 'core.hooksPath')).Output.Trim() -eq 'custom-hooks')
Set-Text (Join-Path $project 'README.md') 'custom readme'
Set-Text (Join-Path $project 'docs/specs/danger-name.md') 'approved brief'
& $generator -Path $project -Feature '../Danger Name?' | Out-Null
Check 'existing README is not overwritten' ((Read-Text (Join-Path $project 'README.md')) -eq 'custom readme')
Check 'existing brief is not overwritten' ((Read-Text (Join-Path $project 'docs/specs/danger-name.md')) -eq 'approved brief')

$invalidFeature = New-GitFixture 'invalid-feature'
$rejected = $false
try { & $generator -Path $invalidFeature -Feature '...___' | Out-Null } catch { $rejected = $true }
Check 'empty normalized feature name is rejected' $rejected
Check 'invalid feature writes nothing' (@(Get-ChildItem -LiteralPath $invalidFeature -Force | Where-Object { $_.Name -ne '.git' }).Count -eq 0)

Write-Host '-- orchestration routing'
. (Join-Path $repo 'bin/project-orchestration.ps1')
$cases = @(
    @{ Name = 'default'; Marker = ''; Sentinel = $false; Mode = 'STANDARD_DEEPSETING'; Writes = $true },
    @{ Name = 'explicit-standard'; Marker = 'PROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING'; Sentinel = $true; Mode = 'STANDARD_DEEPSETING'; Writes = $true },
    @{ Name = 'explicit-game'; Marker = 'PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'; Sentinel = $false; Mode = 'GAME_MASTER_PLAN'; Writes = $false },
    @{ Name = 'sentinel'; Marker = ''; Sentinel = $true; Mode = 'GAME_MASTER_PLAN'; Writes = $false },
    @{ Name = 'inline-example'; Marker = 'Example: PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'; Sentinel = $false; Mode = 'STANDARD_DEEPSETING'; Writes = $true }
)
foreach ($case in $cases) {
    $fixture = New-GitFixture "route-$($case.Name)"
    if ($case.Marker) { Set-Text (Join-Path $fixture 'CLAUDE.md') $case.Marker }
    if ($case.Sentinel) { Set-Text (Join-Path $fixture 'specs/master/ACTIVE_STAGE.md') 'stage-1' }
    Check "$($case.Name) mode" ((Get-ProjectOrchestrationMode $fixture) -eq $case.Mode)
    $before = @(Snapshot $fixture)
    & (Join-Path $cfgFresh 'bin/new-project.ps1') -Path $fixture -Feature example | Out-Null
    if ($case.Writes) {
        Check "$($case.Name) initializes minimal docs" ((Test-Path -LiteralPath (Join-Path $fixture 'README.md')) -and (Test-Path -LiteralPath (Join-Path $fixture 'docs/specs/example.md')))
    } else {
        $after = @(Snapshot $fixture)
        Check "$($case.Name) preserves every project file" (@(Compare-Object $before $after).Count -eq 0)
    }
}

foreach ($entry in @(
        @{ Name = 'unknown'; Text = 'PROJECT_ORCHESTRATION_MODE: TYPO' },
        @{ Name = 'duplicate'; Text = "PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN`nPROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING" }
    )) {
    $fixture = New-GitFixture "route-invalid-$($entry.Name)"
    Set-Text (Join-Path $fixture 'CLAUDE.md') $entry.Text
    $rejected = $false
    try { & $generator -Path $fixture -Feature example | Out-Null } catch { $rejected = $true }
    Check "$($entry.Name) declaration rejected" $rejected
    Check "$($entry.Name) declaration writes no docs" (-not (Test-Path -LiteralPath (Join-Path $fixture 'README.md')) -and -not (Test-Path -LiteralPath (Join-Path $fixture 'docs')))
}

Write-Host '-- audit patch workflow'
$patchCfg = Join-Path $tmpRoot 'patch-config'
$patchManifest = Join-Path $tmpRoot 'patches.json'
$patchFile = Join-Path $patchCfg 'skills/example/SKILL.md'
Set-Text $patchFile 'prefix old guidance suffix'
Set-Text $patchManifest '[{"scope":"Codex","path":"skills/example/SKILL.md","replacements":[{"before":"old guidance","after":"new guidance"}]}]'
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest -CheckOnly | Out-Null
Check 'CheckOnly does not modify a skill' ((Read-Text $patchFile) -eq 'prefix old guidance suffix')
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null
Check 'patch preserves surrounding text' ((Read-Text $patchFile) -eq 'prefix new guidance suffix')
Check 'patch creates one adjacent backup' ((Backup-Count (Split-Path -Parent $patchFile) 'SKILL.md.bak-*') -eq 1)
& $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null
Check 'repeat patch creates no extra backup' ((Backup-Count (Split-Path -Parent $patchFile) 'SKILL.md.bak-*') -eq 1)

Set-Text $patchFile 'prefix old guidance suffix'
$conflictFile = Join-Path $patchCfg 'skills/changed/SKILL.md'
Set-Text $conflictFile 'unrecognized version'
Set-Text $patchManifest '[{"scope":"Codex","path":"skills/example/SKILL.md","replacements":[{"before":"old guidance","after":"new guidance"}]},{"scope":"Codex","path":"skills/changed/SKILL.md","replacements":[{"before":"expected version","after":"updated version"}]}]'
$rejected = $false
try { & $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null } catch { $rejected = $true }
Check 'conflict prevents writes to every target' ($rejected -and (Read-Text $patchFile) -eq 'prefix old guidance suffix')
Set-Text $patchManifest '[{"scope":"Codex","path":"../outside.md","replacements":[{"before":"old","after":"new"}]}]'
$rejected = $false
try { & $patcher -ConfigDir $patchCfg -ManifestPath $patchManifest | Out-Null } catch { $rejected = $true }
Check 'patch cannot escape selected root' $rejected

Write-Host '-- removed ceremony regression'
$generatorText = Read-Text $generator
$skillText = Read-Text (Join-Path $repo 'codex/skills/project-specifications/SKILL.md')
Check 'generator contains no hook implementation' ($generatorText -notmatch 'pre-commit|core\.hooksPath')
Check 'skill does not mandate four-document workflow' ($skillText -notmatch 'Проект ведётся по четырём документам|Остановись и покажи критерии|после каждого шага обновляй')
foreach ($relative in @('PROGRESS.md', 'codex/skills/project-specifications/templates/SPEC.md', 'codex/skills/project-specifications/templates/plan.md', 'codex/skills/project-specifications/templates/progress.md', 'codex/skills/project-specifications/templates/feature.md')) {
    Check "obsolete artifact removed: $relative" (-not (Test-Path -LiteralPath (Join-Path $repo $relative)))
}
Check 'Codex audit patch manifest preserved' (Test-Path -LiteralPath (Join-Path $repo 'codex/skill-patches.json') -PathType Leaf)
Check 'skill guidance patcher preserved' (Test-Path -LiteralPath $patcher -PathType Leaf)

Write-Host "`nPassed: $($script:passed), failed: $($script:failed)"
if (-not $Keep) {
    Get-ChildItem -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}
if ($script:failed -gt 0) { exit 1 }
exit 0
