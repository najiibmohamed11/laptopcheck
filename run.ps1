# Laptop Check - one-line launcher. Usage on any Windows PC (PowerShell):
#   irm https://raw.githubusercontent.com/najiibmohamed11/laptopcheck/main/run.ps1 | iex
# Downloads the tool to a temp folder, runs it as admin, opens the report,
# then deletes everything when you press Enter. Nothing is installed.

$ErrorActionPreference = 'Stop'
$ScriptUrl = 'https://raw.githubusercontent.com/najiibmohamed11/laptopcheck/main/run.ps1'                  # where this file is hosted
$ZipUrl    = 'https://raw.githubusercontent.com/najiibmohamed11/laptopcheck/main/LaptopCheck-1.0.0.zip'      # where the zip is hosted
$ZipSha256 = '31f810d5ea059bb335021e8be1f224e08b60f6c99f557d237dba40006c31b976'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Relaunch elevated (one UAC prompt) so all checks have full access.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Requesting administrator access...' -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$ScriptUrl' | iex`""
        return
    } catch {
        Write-Host "Admin not granted ($($_.Exception.Message)) - running with limited checks." -ForegroundColor Yellow
        Write-Host 'Tip: for full checks, open PowerShell with right-click > Run as administrator.' -ForegroundColor Yellow
    }
}

$work = Join-Path $env:TEMP ('LaptopCheck-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $zip = Join-Path $work 'lc.zip'
    Write-Host 'Downloading Laptop Check...' -ForegroundColor Cyan
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $ZipSha256) { throw 'Download corrupted or tampered (hash mismatch). Aborting.' }
    Expand-Archive -Path $zip -DestinationPath $work -Force
    $tool = Join-Path $work 'LaptopCheck'
    $reports = Join-Path $work 'Reports'

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tool 'LaptopCheck.ps1') -OutputDirectory $reports

    $html = Get-ChildItem $reports -Recurse -Filter inspection.html | Select-Object -First 1
    if ($html) {
        Start-Process $html.FullName
        Write-Host "`nReport opened in your browser." -ForegroundColor Cyan
        Start-Sleep -Seconds 5   # let the browser finish loading before anything is deleted
    }

    function Clear-Keys { try { $Host.UI.RawUI.FlushInputBuffer() } catch {} }
    Clear-Keys   # ignore keys pressed while the inspection was running
    Write-Host ''
    Write-Host 'Read the report in the browser. Keep this window open until you are done.' -ForegroundColor Cyan
    while ($true) {
        $keep = Read-Host 'Type a USB/folder path to save a copy (e.g. E:\), or type DONE to delete everything'
        if ($keep -match '^\s*done\s*$') { break }
        if ($keep -and $html -and (Test-Path $keep)) {
            Copy-Item -Path (Split-Path $html.FullName) -Destination $keep -Recurse -Force
            Write-Host "Saved to $keep" -ForegroundColor Green
            break
        }
        if ($keep) { Write-Host "Path '$keep' not found - plug in the USB and try again." -ForegroundColor Yellow }
    }
} finally {
    Set-Location $env:TEMP
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Temporary files removed. Nothing left on this PC.' -ForegroundColor Green
    try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
    Read-Host 'Press Enter to close'
}
