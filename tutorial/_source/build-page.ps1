# Injects tutorial/README.md into the page template.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$md = [IO.File]::ReadAllText((Join-Path (Split-Path -Parent $here) "README.md"))
if ($md -match '</script') { throw "markdown contains </script" }
$tpl = [IO.File]::ReadAllText((Join-Path $here "page.template.html"))
$html = $tpl.Replace("%%MARKDOWN%%", $md)
$out = Join-Path (Split-Path -Parent $here) "learn-love.html"
[IO.File]::WriteAllText($out, $html)
Write-Output ("wrote {0} ({1:N0} KB)" -f $out, ((Get-Item $out).Length / 1KB))
