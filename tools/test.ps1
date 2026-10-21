<#
FX Forge dev test runner (Windows PowerShell 5.1+ / PowerShell 7).

Usage:
  powershell -ExecutionPolicy Bypass -File tools/test.ps1 [unit|gallery|editor|selftest|all] [-Filter name]

  unit      headless unit tests (tests/run_tests.gd)
  gallery   render every built-in preset to tests/output/gallery
  runtime   play every exported scene in res://fx_exports/ (one-shots must free themselves) + demo scene
  editor    copy the project to a temp folder, start the editor headless, check the plugin loads cleanly
  selftest  same copy, run the in-editor export self test (--fxforge-selftest)
  all       everything above

Godot is located via $env:GODOT, then known install paths, then PATH.
On a new machine set:  $env:GODOT = "<path>\Godot_v4.7.x-stable_win64_console.exe"
This file is ASCII-only on purpose (Windows PowerShell 5.1 reads BOM-less files as ANSI).
#>
param(
	[ValidateSet("unit", "gallery", "runtime", "editor", "selftest", "all")]
	[string]$Suite = "unit",
	[string]$Filter = ""
)

$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "tests\output"
$ErrorPatterns = @("SCRIPT ERROR", "Parse Error", "Unable to load addon script", "Failed to load script", "Compile Error")

function Find-Godot {
	if ($env:GODOT -and (Test-Path -LiteralPath $env:GODOT)) { return $env:GODOT }
	$known = @(
		"C:\Tools\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
	)
	foreach ($p in $known) { if (Test-Path -LiteralPath $p) { return $p } }
	foreach ($name in @("godot_console", "godot")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	throw "Godot not found. Set `$env:GODOT to the Godot 4.7 console executable."
}

function Invoke-Godot([string]$ProjectPath, [string[]]$GodotArgs, [string]$LogName) {
	New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
	$log = Join-Path $OutDir $LogName
	if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
	$all = @("--headless", "--path", $ProjectPath, "--log-file", $log) + $GodotArgs
	& $script:Godot @all | Out-Host
	$code = $LASTEXITCODE
	$text = ""
	if (Test-Path -LiteralPath $log) { $text = Get-Content -LiteralPath $log -Raw -Encoding UTF8 }
	$found = @()
	foreach ($pat in $ErrorPatterns) {
		if ($text -and $text.Contains($pat)) { $found += $pat }
	}
	return [pscustomobject]@{ Code = $code; Log = $log; Errors = $found; Text = $text }
}

function Ensure-Imported([string]$ProjectPath) {
	if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath ".godot"))) {
		Write-Host "== First run on this machine: importing project ..."
		Invoke-Godot $ProjectPath @("--import") "import.log" | Out-Null
	}
}

function New-ProjectCopy {
	$dst = Join-Path ([System.IO.Path]::GetTempPath()) ("fxforge_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
	robocopy $Root $dst /E /XD (Join-Path $Root ".git") (Join-Path $Root "tests\output") /NFL /NDL /NJH /NJS /NP | Out-Null
	return $dst
}

function Report([string]$Name, $Result, [bool]$ExtraOk = $true) {
	$ok = ($Result.Code -eq 0) -and ($Result.Errors.Count -eq 0) -and $ExtraOk
	if ($ok) {
		Write-Host "== $Name : PASS" -ForegroundColor Green
	} else {
		Write-Host "== $Name : FAIL (exit $($Result.Code); log $($Result.Log))" -ForegroundColor Red
		foreach ($e in $Result.Errors) { Write-Host "   log contains: $e" -ForegroundColor Red }
	}
	return $ok
}

$script:Godot = Find-Godot
Write-Host "== Godot: $script:Godot"
$allOk = $true

if ($Suite -eq "unit" -or $Suite -eq "all") {
	Ensure-Imported $Root
	$testArgs = @("--script", "res://tests/run_tests.gd")
	if ($Filter) { $testArgs += @("--", $Filter) }
	$allOk = (Report "unit tests" (Invoke-Godot $Root $testArgs "unit.log")) -and $allOk
}

if ($Suite -eq "gallery" -or $Suite -eq "all") {
	Ensure-Imported $Root
	$allOk = (Report "gallery" (Invoke-Godot $Root @("--script", "res://tests/render_gallery.gd") "gallery.log")) -and $allOk
}

if ($Suite -eq "runtime" -or $Suite -eq "all") {
	Ensure-Imported $Root
	$r = Invoke-Godot $Root @("--fixed-fps", "60", "--script", "res://tests/runtime_check.gd") "runtime.log"
	$allOk = (Report "runtime check" $r ($r.Text -and $r.Text.Contains("FXFORGE_RUNTIME: PASS"))) -and $allOk
}

if ($Suite -eq "editor" -or $Suite -eq "all") {
	Ensure-Imported $Root
	$copy = New-ProjectCopy
	try {
		$r = Invoke-Godot $copy @("--editor", "--quit") "editor_smoke.log"
		$cfg = Get-Content -LiteralPath (Join-Path $copy "project.godot") -Raw -Encoding UTF8
		$stillEnabled = $cfg.Contains("res://addons/fx_forge/plugin.cfg")
		if (-not $stillEnabled) { Write-Host "   plugin was removed from project.godot (load failure)" -ForegroundColor Red }
		$allOk = (Report "editor smoke" $r $stillEnabled) -and $allOk
	} finally {
		Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue
	}
}

if ($Suite -eq "selftest" -or $Suite -eq "all") {
	Ensure-Imported $Root
	$copy = New-ProjectCopy
	try {
		$r = Invoke-Godot $copy @("--editor", "--", "--fxforge-selftest") "selftest.log"
		$passed = $r.Text -and $r.Text.Contains("FXFORGE_SELFTEST: PASS")
		$allOk = (Report "editor export selftest" $r $passed) -and $allOk
	} finally {
		Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction SilentlyContinue
	}
}

if ($allOk) { exit 0 } else { exit 1 }
