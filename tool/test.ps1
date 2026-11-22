param(
    [string]$Flutter = 'flutter',
    [string]$SqliteLibrary
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
$manifest = Join-Path $repoRoot 'pubspec.yaml'
$original = [IO.File]::ReadAllText($manifest)
try {
    if ($SqliteLibrary) {
        # Optional offline desktop-test path; never changes the mobile database.
        $library = ([Uri](Resolve-Path -LiteralPath $SqliteLibrary).Path).AbsoluteUri.Replace("'", "''")
        if ($original -match '(?m)^hooks:') { throw 'Existing hooks configuration must be preserved. Run flutter test directly.' }
        $configuration = "`nhooks:`n  user_defines:`n    sqlite3:`n      source: system`n      name: '$library'`n"
        [IO.File]::WriteAllText($manifest, $original + $configuration)
    }
    & $Flutter --suppress-analytics test --no-pub
    if ($LASTEXITCODE -ne 0) { throw "Tests failed (exit $LASTEXITCODE)." }
} finally {
    if ($SqliteLibrary) { [IO.File]::WriteAllText($manifest, $original) }
    Pop-Location
}
