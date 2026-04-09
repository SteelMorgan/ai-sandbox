<#
.SYNOPSIS
    Installs and configures VcXsrv X11 server on Windows for clipboard
    sharing with Docker devcontainers.

.DESCRIPTION
    CLI tools inside the container (Claude CLI, Codex CLI) need X11 to
    access the clipboard for image paste.  This script:
      1. Installs VcXsrv via winget (if not present)
      2. Creates a .xlaunch config with clipboard enabled
      3. Adds the config to Windows Startup so VcXsrv auto-starts
      4. Adds a Windows Firewall inbound rule for VcXsrv
      5. Starts VcXsrv immediately

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-xserver.ps1
#>

$ErrorActionPreference = 'Stop'

$VcXsrvExe   = "C:\Program Files\VcXsrv\vcxsrv.exe"
$StartupDir   = [Environment]::GetFolderPath('Startup')
$XLaunchFile  = Join-Path $StartupDir 'vcxsrv-clipboard.xlaunch'

# ── 1. Install VcXsrv ──────────────────────────────────────────────
if (-not (Test-Path $VcXsrvExe)) {
    Write-Host "[1/5] Installing VcXsrv via winget..." -ForegroundColor Cyan
    winget install --id marha.VcXsrv -e --accept-package-agreements --accept-source-agreements
    if (-not (Test-Path $VcXsrvExe)) {
        Write-Error "VcXsrv installation failed — vcxsrv.exe not found."
        exit 1
    }
    Write-Host "      VcXsrv installed." -ForegroundColor Green
} else {
    Write-Host "[1/5] VcXsrv already installed." -ForegroundColor Green
}

# ── 2. Create .xlaunch config ──────────────────────────────────────
Write-Host "[2/5] Writing XLaunch config to Startup folder..." -ForegroundColor Cyan

$xlaunchXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<XLaunch WindowMode="MultiWindow" ClientMode="NoClient" LocalClient="False"
         Display="0" LocalProgram="xcalc" RemoteProgram="xterm"
         RemotePassword="" PrivateKey="" RemoteHost="" RemoteUser=""
         XDMCPHost="" XDMCPBroadcast="False" XDMCPIndirect="False"
         Clipboard="True" ClipboardPrimary="True"
         ExtraParams="" Wgl="True" DisableAC="True" XDMCPTerminate="False"/>
'@

Set-Content -Path $XLaunchFile -Value $xlaunchXml -Encoding UTF8
Write-Host "      Saved: $XLaunchFile" -ForegroundColor Green

# ── 3. Confirm Startup entry ───────────────────────────────────────
Write-Host "[3/5] VcXsrv will auto-start on login (Startup folder)." -ForegroundColor Green

# ── 4. Firewall rule ───────────────────────────────────────────────
Write-Host "[4/5] Ensuring Windows Firewall rule..." -ForegroundColor Cyan

$ruleName = 'VcXsrv X11 Server'
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Program $VcXsrvExe `
        -Action Allow `
        -Profile Private, Domain `
        -Description 'Allow inbound X11 connections from Docker containers' | Out-Null
    Write-Host "      Firewall rule created." -ForegroundColor Green
} else {
    Write-Host "      Firewall rule already exists." -ForegroundColor Green
}

# ── 5. Start VcXsrv now ───────────────────────────────────────────
Write-Host "[5/5] Starting VcXsrv..." -ForegroundColor Cyan

$running = Get-Process vcxsrv -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "      VcXsrv already running (PID $($running.Id))." -ForegroundColor Green
} else {
    Start-Process -FilePath $VcXsrvExe -ArgumentList ':0', '-multiwindow', '-clipboard', '-primary', '-ac', '-wgl'
    Start-Sleep -Seconds 2
    $proc = Get-Process vcxsrv -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "      VcXsrv started (PID $($proc.Id))." -ForegroundColor Green
    } else {
        Write-Warning "      VcXsrv may not have started. Check manually."
    }
}

Write-Host ""
Write-Host "Done. X11 clipboard is ready for Docker containers." -ForegroundColor Green
Write-Host "Container must have DISPLAY=host.docker.internal:0.0 (already set in docker-compose.yml)." -ForegroundColor DarkGray
