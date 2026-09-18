# Builds tutorial/README.md from the part files, expanding
#   @@include <path relative to tutorial/> [| startRegex | endRegex [| nth]]@@
# into fenced code copied from the real (tested) checkpoint files.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tutorial = Split-Path -Parent $here

$parts = Get-ChildItem $here -Filter "0*.md" | Sort-Object Name
$text = ($parts | ForEach-Object { [IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n").TrimEnd() }) -join "`n`n"

$pattern = '@@include ([^|@]+?)(?:\s*\|\s*(.+?)\s*\|\s*(.+?)(?:\s*\|\s*(\d+))?)?\s*@@'
$script:failures = @()
$evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    $rel = $m.Groups[1].Value.Trim()
    $path = [IO.Path]::GetFullPath((Join-Path $tutorial $rel))
    if (-not (Test-Path $path)) { $script:failures += "missing file: $rel"; return $m.Value }
    $lines = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").TrimEnd("`n") -split "`n"
    if ($m.Groups[2].Success) {
        $start = $m.Groups[2].Value; $endRe = $m.Groups[3].Value
        $nth = 1; if ($m.Groups[4].Success) { $nth = [int]$m.Groups[4].Value }
        $s = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $start) { $s = $i; break } }
        if ($s -lt 0) { $script:failures += "start not found: $($m.Value)"; return $m.Value }
        $e = -1; $count = 0
        for ($i = $s + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $endRe) { $count++; if ($count -eq $nth) { $e = $i; break } }
        }
        if ($e -lt 0) { $script:failures += "end not found: $($m.Value)"; return $m.Value }
        $lines = $lines[$s..$e]
        $label = "$rel"
    } else {
        $label = "$rel"
    }
    $lang = switch ([IO.Path]::GetExtension($path)) { ".lua" { "lua" } ".json" { "json" } default { "" } }
    $fileLabel = $rel -replace '^\.\./', '' -replace '^\d\d-[a-z-]+/', ''
    $checkpoint = if ($rel -match '^(\d\d-[a-z-]+)/') { $Matches[1] } else { "finished game" }
    "<div class=`"codefile`">$fileLabel <span>$checkpoint</span></div>`n`n" + '```' + $lang + "`n" + ($lines -join "`n") + "`n" + '```'
}
$out = [regex]::Replace($text, $pattern, $evaluator)
if ($script:failures.Count -gt 0) { $script:failures | ForEach-Object { Write-Output "FAIL $_" }; exit 1 }
[IO.File]::WriteAllText((Join-Path $tutorial "README.md"), $out + "`n")
$words = ($text -split '\s+' | Where-Object { $_ -ne '' }).Count
$codeLines = ([regex]::Matches($out, "`n")).Count
Write-Output "built README.md: $([regex]::Matches($text, '@@include').Count) includes, ~$words words of prose, $codeLines lines total"
