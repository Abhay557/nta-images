$ErrorActionPreference = "Continue"
$folder = "2"
$log = "F:\nta\batch_2.log"
function Log($m) { Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }

Set-Content -Path $log -Value ("=== chunked run {0} ===" -f (Get-Date -Format "HH:mm:ss"))
Set-Content -Path "F:\nta\.gitignore" -Value "6/`n12/`n20/`n"
if (Test-Path "F:\nta\.git\index.lock") { Remove-Item "F:\nta\.git\index.lock" -Force; Log "removed stale lock" }
& git commit -q -m "flush staged" 2>$null | Out-Null
& git push -q 2>&1 | Out-Null

$subdirs = @(Get-ChildItem "F:\nta\$folder" -Directory | Select-Object -ExpandProperty Name | Sort-Object { [int]$_ })
$trackedSet = @{}
foreach ($t in @(git ls-files "$folder/")) { $p = $t.Split("/"); if ($p.Count -gt 1) { $trackedSet[$p[1]] = $true } }
$todo = @()
foreach ($s in $subdirs) { if (-not $trackedSet.ContainsKey($s)) { $todo += $s } }
Log ("Remaining subdirs: {0}" -f $todo.Count)

$chunks = [Math]::Max(1, [int][Math]::Ceiling($todo.Count / 12.0))
$part = 5
for ($i = 0; $i -lt $todo.Count; $i += $chunks) {
    $slice = $todo[$i..([Math]::Min($i + $chunks - 1, $todo.Count - 1))]
    if (-not $slice) { break }
    if (Test-Path "F:\nta\.git\index.lock") { Remove-Item "F:\nta\.git\index.lock" -Force; Log "removed lock before part $part" }
    $paths = @($slice | ForEach-Object { "$folder/$_/" })
    Log ("part {0}: staging {1} subdirs..." -f $part, $paths.Count)
    & git add $paths 2>&1 | Out-Null
    $staged = (git diff --cached --name-only 2>$null | Measure-Object -Line).Lines
    if ($staged -gt 0) {
        Log ("part {0}: committing {1} files..." -f $part, $staged)
        & git commit -q -m "Add $folder (part $part)"
        & git push -q 2>&1 | Out-Null
        Log ("part {0}: pushed. folder2 tracked: {1}" -f $part, (git ls-files "$folder/" | Measure-Object).Count)
        $part++
    } else {
        Log ("part {0}: nothing new to stage." -f $part)
    }
}

$staged = (git diff --cached --name-only 2>$null | Measure-Object -Line).Lines
if ($staged -gt 0) {
    & git commit -q -m "Add $folder (part $part)"
    & git push -q 2>&1 | Out-Null
    Log "final flush pushed."
}

& git add "$folder/" 2>&1 | Out-Null
$staged = (git diff --cached --name-only 2>$null | Measure-Object -Line).Lines
if ($staged -gt 0) {
    & git commit -q -m "Add remaining files in $folder"
    & git push -q 2>&1 | Out-Null
    Log "root files pushed."
}

Set-Content -Path "F:\nta\.gitignore" -Value ""
Log ("ALL DONE. folder2 tracked: {0}" -f (git ls-files "$folder/" | Measure-Object).Count)
