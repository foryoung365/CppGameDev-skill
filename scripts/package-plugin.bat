@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
	"$ErrorActionPreference = 'Stop';" ^
	"$repo = (Resolve-Path '%REPO_ROOT%').Path;" ^
	"$pluginJson = Join-Path $repo '.claude-plugin\plugin.json';" ^
	"if (-not (Test-Path -LiteralPath $pluginJson)) { throw 'Missing plugin manifest: ' + $pluginJson };" ^
	"$plugin = Get-Content -Raw -LiteralPath $pluginJson | ConvertFrom-Json;" ^
	"$dist = Join-Path $repo 'dist';" ^
	"$stage = Join-Path $dist $plugin.name;" ^
	"$zip = Join-Path $dist ($plugin.name + '-' + $plugin.version + '.zip');" ^
	"$paths = @('.claude-plugin','agents','commands','skills','docs\operator','docs\workflow','docs\gameplay','docs\svn');" ^
	"Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;" ^
	"Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue;" ^
	"New-Item -ItemType Directory -Force -Path $stage | Out-Null;" ^
	"foreach ($relative in $paths) {" ^
	"  $source = Join-Path $repo $relative;" ^
	"  if (-not (Test-Path -LiteralPath $source)) { throw 'Missing source path: ' + $source };" ^
	"  $destination = Join-Path $stage $relative;" ^
	"  $parent = Split-Path -Path $destination -Parent;" ^
	"  New-Item -ItemType Directory -Force -Path $parent | Out-Null;" ^
	"  Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force;" ^
	"}" ^
	"Copy-Item -LiteralPath (Join-Path $repo 'README.md') -Destination (Join-Path $stage 'README.md') -Force;" ^
	"Copy-Item -LiteralPath (Join-Path $repo 'settings.json') -Destination (Join-Path $stage 'settings.json') -Force;" ^
	"Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force;" ^
	"if (Test-Path -LiteralPath $stage) { [System.IO.Directory]::Delete($stage, $true) };" ^
	"Write-Host '[OK] Package created:' $zip"

if errorlevel 1 exit /b %errorlevel%
exit /b 0
