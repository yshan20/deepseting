# Integration cases, loaded by run-tests.ps1 with its isolated fixtures/helpers.
. (Join-Path $repo 'bin/project-orchestration.ps1')

Write-Host '-- orchestration router and initialization'
$conflicting = @('docs/SPEC.md', 'docs/features', 'docs/plan.md', 'PROGRESS.md', '.githooks')
$cases = @(
    @{ Name = 'standard'; Marker = ''; Sentinel = $false; Mode = 'STANDARD_DEEPSETING' },
    @{ Name = 'explicit'; Marker = 'PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'; Sentinel = $false; Mode = 'GAME_MASTER_PLAN' },
    @{ Name = 'fallback'; Marker = ''; Sentinel = $true; Mode = 'GAME_MASTER_PLAN' },
    @{ Name = 'override'; Marker = 'PROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING'; Sentinel = $true; Mode = 'STANDARD_DEEPSETING' },
    @{ Name = 'whitespace'; Marker = "`tPROJECT_ORCHESTRATION_MODE:  GAME_MASTER_PLAN `t`r`n"; Sentinel = $true; Mode = 'GAME_MASTER_PLAN' },
    @{ Name = 'inline-example'; Marker = 'Example: PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'; Sentinel = $false; Mode = 'STANDARD_DEEPSETING' }
)
foreach ($case in $cases) {
    $fixture = Join-Path $tmpRoot "router-$($case.Name)"
    New-Item -ItemType Directory -Force -Path $fixture | Out-Null
    Invoke-Git $fixture @('init', '-q') | Out-Null
    if ($case.Marker) { Set-Text (Join-Path $fixture 'CLAUDE.md') $case.Marker }
    if ($case.Sentinel) { Set-Text (Join-Path $fixture 'specs/master/ACTIVE_STAGE.md') 'stage-1' }
    Check "router $($case.Name)" ((Get-ProjectOrchestrationMode $fixture) -eq $case.Mode)
    # Use the installed generator too: catches missing router dependencies.
    & (Join-Path $cfgFresh 'bin/new-project.ps1') -Path $fixture -Feature example | Out-Null
    if ($case.Mode -eq 'GAME_MASTER_PLAN') {
        foreach ($rel in $conflicting) {
            Check "$($case.Name): no $rel" (-not (Test-Path -LiteralPath (Join-Path $fixture $rel)))
        }
        if ($case.Sentinel) {
            Check "$($case.Name): master preserved" ([IO.File]::ReadAllText((Join-Path $fixture 'specs/master/ACTIVE_STAGE.md')) -eq 'stage-1')
        }
    } else {
        Check "$($case.Name): standard workflow available" (Test-Path -LiteralPath (Join-Path $fixture 'docs/features/example.md'))
    }
}

# Existing game state, engineering tools and hook configuration must survive.
$game = Join-Path $tmpRoot 'game-existing'
Set-Text (Join-Path $game 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'
Set-Text (Join-Path $game 'specs/master/HANDOFF.md') 'next allowed lab task'
Set-Text (Join-Path $game 'specs/labs/player/PROGRESS.md') 'approved task'
foreach ($rel in @('docs/SPEC.md', 'docs/features/existing.md', 'docs/plan.md', 'PROGRESS.md', '.githooks/pre-commit', 'README.md')) {
    Set-Text (Join-Path $game $rel) "preserve $rel"
}
Invoke-Git $game @('init', '-q') | Out-Null
Invoke-Git $game @('config', 'core.hooksPath', 'custom-hooks') | Out-Null
$before = @(Get-ChildItem -LiteralPath $game -Recurse -File | ForEach-Object { "$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName).Hash)" })
New-Item -ItemType Directory -Force -Path (Join-Path $game 'src/nested') | Out-Null
& $generator -Path (Join-Path $game 'src/nested') -Feature forbidden | Out-Null
$after = @(Get-ChildItem -LiteralPath $game -Recurse -File | ForEach-Object { "$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName).Hash)" })
Check 'nested game initialization preserves every existing file' (@(Compare-Object $before $after).Count -eq 0)
Check 'game hook configuration preserved' ((Invoke-Git $game @('config', 'core.hooksPath')).Out.Trim() -eq 'custom-hooks')
Check 'nested invocation creates no parallel docs' (-not (Test-Path -LiteralPath (Join-Path $game 'src/nested/docs')))

# Invalid declarations fail before writes; they must not silently select standard.
foreach ($marker in @('PROJECT_ORCHESTRATION_MODE: TYPO', "PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN`nPROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING")) {
    $invalid = Join-Path $tmpRoot 'invalid-mode'
    Set-Text (Join-Path $invalid 'CLAUDE.md') $marker
    Invoke-Git $invalid @('init', '-q') | Out-Null
    $rejected = $false
    try { & $generator -Path $invalid | Out-Null } catch { $rejected = $true }
    Check 'invalid declaration rejected' $rejected
    Check 'invalid declaration creates no scaffolding' (-not (Test-Path -LiteralPath (Join-Path $invalid 'docs')))
}

# Standard reinitialization should honor the documented preservation guarantee.
$standardBefore = [IO.File]::ReadAllText((Join-Path $proj 'docs/features/demo.md'))
& $generator -Path $proj -Feature demo | Out-Null
Check 'standard reinitialization preserves approved feature' ([IO.File]::ReadAllText((Join-Path $proj 'docs/features/demo.md')) -eq $standardBefore)

Write-Host '-- mode-aware hooks through real commits'
foreach ($case in $cases) {
    $fixture = Join-Path $tmpRoot "hook-$($case.Name)"
    Set-Text (Join-Path $fixture '.githooks/pre-commit') ([IO.File]::ReadAllText((Join-Path $proj '.githooks/pre-commit')))
    Invoke-Git $fixture @('init', '-q') | Out-Null
    Invoke-Git $fixture @('config', 'user.email', 'tests@example.com') | Out-Null
    Invoke-Git $fixture @('config', 'user.name', 'harness tests') | Out-Null
    Invoke-Git $fixture @('config', 'commit.gpgsign', 'false') | Out-Null
    Invoke-Git $fixture @('config', 'core.hooksPath', '.githooks') | Out-Null
    if ($case.Marker) { Set-Text (Join-Path $fixture 'CLAUDE.md') $case.Marker }
    if ($case.Sentinel) { Set-Text (Join-Path $fixture 'specs/master/ACTIVE_STAGE.md') 'stage-1' }
    Set-Text (Join-Path $fixture 'docs/plan.md') 'legacy plan without root progress'
    Invoke-Git $fixture @('add', '-A') | Out-Null
    Invoke-Git $fixture @('update-index', '--chmod=+x', '.githooks/pre-commit') | Out-Null
    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne 'Win32NT') {
        & chmod +x -- (Join-Path $fixture '.githooks/pre-commit')
    }
    $result = Invoke-Git $fixture @('commit', '-m', 'route staged project')
    Check "hook $($case.Name)" (($result.Code -eq 0) -eq ($case.Mode -eq 'GAME_MASTER_PLAN')) $result.Out
    if ($case.Mode -eq 'GAME_MASTER_PLAN') {
        Check "hook $($case.Name): explicit skip message" ($result.Out -match 'skipping standard specification validation') $result.Out
    } else {
        Check "hook $($case.Name): standard validation ran" ($result.Out -match 'PROGRESS.md') $result.Out
    }
}

# Working-tree markers cannot exempt a standard index; staged markers remain
# authoritative even if the working copy has changed again.
$fixture = Join-Path $tmpRoot 'hook-standard'
Set-Text (Join-Path $fixture 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'
$result = Invoke-Git $fixture @('commit', '-m', 'unstaged marker')
Check 'unstaged marker cannot bypass hook' ($result.Code -ne 0 -and $result.Out -match 'PROGRESS.md') $result.Out
Set-Text (Join-Path $fixture 'specs/master/ACTIVE_STAGE.md') 'stage-1'
Remove-Item -LiteralPath (Join-Path $fixture 'CLAUDE.md')
$result = Invoke-Git $fixture @('commit', '-m', 'unstaged sentinel')
Check 'unstaged sentinel cannot bypass hook' ($result.Code -ne 0 -and $result.Out -match 'PROGRESS.md') $result.Out
Set-Text (Join-Path $fixture 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: GAME_MASTER_PLAN'
Invoke-Git $fixture @('add', 'CLAUDE.md') | Out-Null
Set-Text (Join-Path $fixture 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: STANDARD_DEEPSETING'
$result = Invoke-Git $fixture @('commit', '-m', 'staged game marker')
Check 'staged marker wins over working tree' ($result.Code -eq 0) $result.Out

# Invalid indexed declarations and a removed sentinel route safely too.
Set-Text (Join-Path $fixture 'CLAUDE.md') 'PROJECT_ORCHESTRATION_MODE: TYPO'
Invoke-Git $fixture @('add', 'CLAUDE.md') | Out-Null
$result = Invoke-Git $fixture @('commit', '-m', 'invalid mode')
Check 'invalid staged marker rejected' ($result.Code -ne 0 -and $result.Out -match 'Invalid PROJECT_ORCHESTRATION_MODE') $result.Out
$fixture = Join-Path $tmpRoot 'hook-fallback'
Invoke-Git $fixture @('rm', 'specs/master/ACTIVE_STAGE.md') | Out-Null
Set-Text (Join-Path $fixture 'docs/plan.md') 'back to standard'
Invoke-Git $fixture @('add', 'docs/plan.md') | Out-Null
$result = Invoke-Git $fixture @('commit', '-m', 'remove sentinel')
Check 'staged sentinel removal restores standard validation' ($result.Code -ne 0 -and $result.Out -match 'PROGRESS.md') $result.Out

Write-Host '-- installed compatibility resources and local backups'
Check 'router installed' (Test-Path -LiteralPath (Join-Path $cfgFresh 'bin/project-orchestration.ps1'))
Check 'game reference installed' (Test-Path -LiteralPath (Join-Path $cfgFresh 'skills/project-specifications/references/game-master-plan.md'))
Set-Text (Join-Path $cfgMerge 'skills/project-specifications/local.md') 'local customization'
& $install -ConfigDir $cfgMerge | Out-Null
# Копия навыка лежит в backups/skills, а не в skills: внутри skills Claude Code
# подхватил бы её как ещё один скилл с почти тем же описанием.
$skillBackupDir = Join-Path $cfgMerge 'backups/skills'
$backups = @(Get-ChildItem -LiteralPath $skillBackupDir -Directory -Filter 'project-specifications.bak-*' -ErrorAction SilentlyContinue)
Check 'local skill edits backed up' ($backups.Count -eq 1 -and [IO.File]::ReadAllText((Join-Path $backups[0].FullName 'local.md')) -eq 'local customization')
Check 'skill backup is not installed as a skill' (@(Get-ChildItem -LiteralPath (Join-Path $cfgMerge 'skills') -Directory -Filter '*.bak-*' -ErrorAction SilentlyContinue).Count -eq 0)
& $install -ConfigDir $cfgMerge | Out-Null
Check 'identical skill reinstall creates no extra backup' (@(Get-ChildItem -LiteralPath $skillBackupDir -Directory -Filter 'project-specifications.bak-*' -ErrorAction SilentlyContinue).Count -eq 1)
