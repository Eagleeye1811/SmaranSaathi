# Reads frontend/.env and launches `flutter run` with --dart-define flags
# Usage: .\run_dev.ps1 [-Device emulator-5554]

param(
    [string]$Device
)

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "frontend/.env not found. Copy .env.example to .env and fill in real values first."
    exit 1
}

$vars = @{}
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line.Split("=", 2)
    if ($parts.Count -eq 2) { $vars[$parts[0].Trim()] = $parts[1].Trim() }
}

$defines = @()
foreach ($key in $vars.Keys) {
    if ($vars[$key] -ne "") { $defines += "--dart-define=$key=$($vars[$key])" }
}

$args = @()
if ($Device) { $args += @("-d", $Device) }
$args += $defines

Write-Host "flutter run $($args -join ' ')" -ForegroundColor Cyan
flutter run @args
