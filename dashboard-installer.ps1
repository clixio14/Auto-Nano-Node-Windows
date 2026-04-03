# ================================================================
#              NANO DASHBOARD INSTALLER
#              Automated setup for Nano Node Dashboard
# ================================================================

$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------
# Step 1 — Ensure script is running as Administrator
# ----------------------------------------------------------------
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ----------------------------------------------------------------
# Step 2 — Download dashboard.ps1 from GitHub
# ----------------------------------------------------------------
Write-Host "Downloading Nano Dashboard..." -ForegroundColor Cyan
$dashboardUrl = "https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/dashboard.ps1"
Invoke-WebRequest -Uri $dashboardUrl -OutFile "C:\nano-node\dashboard.ps1" -UseBasicParsing
Write-Host "Dashboard downloaded successfully." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 3 — Create dashboard.bat launcher in C:\nano-node\
# ----------------------------------------------------------------
Write-Host "Creating dashboard launcher..." -ForegroundColor Cyan
$batContent = '@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\nano-node\dashboard.ps1"'
$batContent | Out-File -FilePath "C:\nano-node\dashboard.bat" -Encoding ASCII
Write-Host "dashboard.bat created." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 4 — Add C:\nano-node\ to system PATH if not already there
# ----------------------------------------------------------------
Write-Host "Checking system PATH..." -ForegroundColor Cyan
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*C:\nano-node*") {
    [Environment]::SetEnvironmentVariable("Path", $currentPath + ";C:\nano-node", "Machine")
    Write-Host "C:\nano-node added to system PATH." -ForegroundColor Green
} else {
    Write-Host "C:\nano-node already in PATH. Skipping." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 5 — Set ExecutionPolicy
# ----------------------------------------------------------------
Write-Host "Setting PowerShell ExecutionPolicy..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
    Write-Host "ExecutionPolicy set system-wide." -ForegroundColor Green
} catch {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "ExecutionPolicy set for current user only." -ForegroundColor Yellow
}

# ----------------------------------------------------------------
# Step 6 — Create Desktop shortcut
# ----------------------------------------------------------------
Write-Host "Creating Desktop shortcut..." -ForegroundColor Cyan
$desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut("$desktopPath\Nano Dashboard.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"C:\nano-node\dashboard.ps1`""
$shortcut.WorkingDirectory = "C:\nano-node"
$shortcut.Description = "Nano Node Live Dashboard"
$shortcut.Save()
Write-Host "Desktop shortcut created." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 7 — Create Start Menu shortcut
# ----------------------------------------------------------------
Write-Host "Creating Start Menu shortcut..." -ForegroundColor Cyan
$startMenuPath = [Environment]::GetFolderPath("CommonPrograms")
$shortcut2 = $WshShell.CreateShortcut("$startMenuPath\Nano Dashboard.lnk")
$shortcut2.TargetPath = "powershell.exe"
$shortcut2.Arguments = "-ExecutionPolicy Bypass -File `"C:\nano-node\dashboard.ps1`""
$shortcut2.WorkingDirectory = "C:\nano-node"
$shortcut2.Description = "Nano Node Live Dashboard"
$shortcut2.Save()
Write-Host "Start Menu shortcut created." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 8 — Launch dashboard in new window and close installer
# ----------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "         NANO DASHBOARD INSTALLED SUCCESSFULLY" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✓ Dashboard downloaded and ready" -ForegroundColor White
Write-Host "  ✓ Desktop shortcut created  (Nano Dashboard)" -ForegroundColor White
Write-Host "  ✓ Start Menu shortcut created  (Nano Dashboard)" -ForegroundColor White
Write-Host ""
Write-Host "  Launching dashboard now..." -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 2

# Launch dashboard in new window
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\nano-node\dashboard.ps1`""

# Close installer window
exit
