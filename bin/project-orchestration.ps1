# Read-only router. Path must be the repository root; no network or global state.
function Get-ProjectOrchestrationMode([string]$Path) {
    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $rules = Join-Path $root 'CLAUDE.md'
    if (Test-Path -LiteralPath $rules -PathType Leaf) {
        $text = [System.IO.File]::ReadAllText($rules)
        $markers = [regex]::Matches($text, '(?m)^[\t ]*PROJECT_ORCHESTRATION_MODE:[\t ]*([^\r\n]*)')
        if ($markers.Count -gt 1) { throw 'Multiple PROJECT_ORCHESTRATION_MODE declarations in root CLAUDE.md.' }
        if ($markers.Count -eq 1) {
            $mode = $markers[0].Groups[1].Value.Trim()
            if ($mode -cnotin @('GAME_MASTER_PLAN', 'STANDARD_DEEPSETING')) {
                throw "Unknown PROJECT_ORCHESTRATION_MODE: $mode"
            }
            return $mode
        }
    }
    if (Test-Path -LiteralPath (Join-Path $root 'specs/master/ACTIVE_STAGE.md') -PathType Leaf) {
        return 'GAME_MASTER_PLAN'
    }
    return 'STANDARD_DEEPSETING'
}
