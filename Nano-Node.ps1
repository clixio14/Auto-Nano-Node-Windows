# ================================================================
#              NANO NODE WINDOWS INSTALLER
#              Automated setup for Nano Node on Windows
# ================================================================

$ErrorActionPreference = "Stop"

# Step 1 -- Ensure script is running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ----------------------------------------------------------------
# Step 2 -- Create folder structure
# ----------------------------------------------------------------
Write-Host "Creating folder structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "C:\nano-node" | Out-Null
New-Item -ItemType Directory -Force -Path "C:\nano-node\Nano" | Out-Null
Write-Host "Folders created successfully." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 3 -- Download and install 7-Zip if not already present
# ----------------------------------------------------------------
Write-Host "Checking for 7-Zip..." -ForegroundColor Cyan
$7zipPath = "C:\Program Files\7-Zip\7z.exe"

if (-Not (Test-Path $7zipPath)) {
    Write-Host "7-Zip not found. Downloading..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://www.7-zip.org/a/7z2409-x64.exe" -OutFile "$env:TEMP\7zip-installer.exe"
    Start-Process "$env:TEMP\7zip-installer.exe" -ArgumentList "/S" -Wait
    Write-Host "7-Zip installed successfully." -ForegroundColor Green
} else {
    Write-Host "7-Zip already installed. Skipping." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 4 -- Download aria2 if not already present
# ----------------------------------------------------------------
Write-Host "Checking for aria2..." -ForegroundColor Cyan
$aria2Path = "C:\nano-node\aria2c.exe"

if (-Not (Test-Path $aria2Path)) {
    Write-Host "aria2 not found. Downloading..." -ForegroundColor Yellow
    $aria2Release = Invoke-RestMethod -Uri "https://api.github.com/repos/aria2/aria2/releases/latest"
    $aria2Url = $aria2Release.assets | Where-Object { $_.name -like "*win-64*" } | Select-Object -ExpandProperty browser_download_url
    Invoke-WebRequest -Uri $aria2Url -OutFile "$env:TEMP\aria2.zip"
    Expand-Archive -Path "$env:TEMP\aria2.zip" -DestinationPath "$env:TEMP\aria2-extracted" -Force
    $aria2Exe = Get-ChildItem -Path "$env:TEMP\aria2-extracted" -Recurse -Filter "aria2c.exe" | Select-Object -First 1
    Copy-Item $aria2Exe.FullName -Destination $aria2Path
    Write-Host "aria2 downloaded successfully." -ForegroundColor Green
} else {
    Write-Host "aria2 already present. Skipping." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 5 & 6 -- Download and extract ledger snapshot
# ----------------------------------------------------------------
$odometerTaskExists = Get-ScheduledTask -TaskName "NanoNodeOdometer" -ErrorAction SilentlyContinue

if ($odometerTaskExists) {
    Write-Host "Previous installation detected. Skipping ledger download." -ForegroundColor Green
} else {
    # Step 5 -- Detect and download latest ledger snapshot
    Write-Host "Detecting latest ledger snapshot URL..." -ForegroundColor Cyan
    $snapshotUrl = ([System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest -Uri "https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest" -UseBasicParsing).Content)).Trim()
    Write-Host "Snapshot URL detected: $snapshotUrl" -ForegroundColor Gray
    Write-Host "Downloading ledger snapshot (this may take a while)..." -ForegroundColor Cyan
    & $aria2Path -x 16 -s 16 -o "Nano_Snapshot.7z" -d "C:\nano-node\Nano\" $snapshotUrl
    Write-Host "Ledger snapshot downloaded successfully." -ForegroundColor Green

    # Step 6 -- Extract ledger snapshot
    Write-Host "Extracting ledger snapshot..." -ForegroundColor Cyan
    & $7zipPath x "C:\nano-node\Nano\Nano_Snapshot.7z" -o"C:\nano-node\Nano\" -y
    Write-Host "Ledger snapshot extracted successfully." -ForegroundColor Green
    Remove-Item "C:\nano-node\Nano\Nano_Snapshot.7z" -Force
    Write-Host "Cleaned up snapshot zip file." -ForegroundColor Gray
}

# ----------------------------------------------------------------
# Step 7 -- Download config files
# ----------------------------------------------------------------
Write-Host "Downloading config files..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://pastebin.com/raw/8ibFAd3F" -OutFile "C:\nano-node\Nano\config-node.toml" -UseBasicParsing
Write-Host "config-node.toml downloaded." -ForegroundColor Gray
Invoke-WebRequest -Uri "https://pastebin.com/raw/pTyMw7mF" -OutFile "C:\nano-node\Nano\config-rpc.toml" -UseBasicParsing
Write-Host "config-rpc.toml downloaded." -ForegroundColor Gray
Write-Host "Config files ready." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 8 -- Download latest Nano Node from GitHub releases
# ----------------------------------------------------------------
Write-Host "Detecting latest Nano Node release..." -ForegroundColor Cyan
$nanoRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/nanocurrency/nano-node/releases/latest"
$nanoAsset = $nanoRelease.assets | Where-Object { $_.name -like "*win64*.zip" } | Select-Object -First 1
$nanoUrl = $nanoAsset.browser_download_url
Write-Host "Latest release detected: $($nanoRelease.tag_name)" -ForegroundColor Gray
# Stop service if running before copying files
$runningService = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue
if ($runningService -and $runningService.Status -eq "Running") {
    Write-Host "Stopping Nano Node service temporarily..." -ForegroundColor Yellow
    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "stop" -Wait -NoNewWindow
    Write-Host "Service stopped." -ForegroundColor Gray
}

Write-Host "Downloading Nano Node..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $nanoUrl -OutFile "$env:TEMP\nano-node.zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\nano-node.zip" -DestinationPath "$env:TEMP\nano-extracted" -Force
$extractedFolder = Get-ChildItem -Path "$env:TEMP\nano-extracted" -Directory | Select-Object -First 1
Copy-Item "$($extractedFolder.FullName)\*" -Destination "C:\nano-node\" -Recurse -Force
Write-Host "Nano Node files copied." -ForegroundColor Gray

# Step 8d -- Install Visual C++ Redistributable if not already installed
$vcInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
if (-Not $vcInstalled) {
    Write-Host "Installing Visual C++ Redistributable..." -ForegroundColor Cyan
    Start-Process "C:\nano-node\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -Wait
    Write-Host "Visual C++ Redistributable installed." -ForegroundColor Green
} else {
    Write-Host "Visual C++ Redistributable already installed. Skipping." -ForegroundColor Green
}

# Cleanup
Remove-Item "$env:TEMP\nano-node.zip" -Force
Remove-Item "$env:TEMP\nano-extracted" -Recurse -Force
Write-Host "Cleaned up temporary files." -ForegroundColor Gray

# ----------------------------------------------------------------
# Step 9 -- Download WinSW, rename, and create XML config
# ----------------------------------------------------------------
Write-Host "Downloading WinSW..." -ForegroundColor Cyan
$winswRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/winsw/winsw/releases/latest"
$winswAsset = $winswRelease.assets | Where-Object { $_.name -like "*x64.exe" } | Select-Object -First 1
Invoke-WebRequest -Uri $winswAsset.browser_download_url -OutFile "C:\nano-node\nano-node-service.exe" -UseBasicParsing
Write-Host "WinSW downloaded and renamed to nano-node-service.exe." -ForegroundColor Gray

Write-Host "Creating WinSW XML config..." -ForegroundColor Cyan
$winswXml = @"
<service>
  <id>nano-node</id>
  <name>Nano Node</name>
  <description>Nano cryptocurrency node running as a Windows service</description>
  <executable>C:\nano-node\nano_node.exe</executable>
  <arguments>--daemon --data_path C:\nano-node\Nano\</arguments>
  <workingdirectory>C:\nano-node</workingdirectory>
  <logpath>C:\nano-node\logs</logpath>
  <log mode="roll"></log>
  <onfailure action="restart" delay="10 sec"/>
</service>
"@
$winswXml | Out-File -FilePath "C:\nano-node\nano-node-service.xml" -Encoding UTF8
Write-Host "WinSW XML config created." -ForegroundColor Green

# Restart service if it was running before
if ($runningService -and $runningService.Status -eq "Running") {
    Write-Host "Restarting Nano Node service..." -ForegroundColor Yellow
    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "start" -Wait -NoNewWindow
    Write-Host "Service restarted." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 10 -- Register and start the Nano Node service
# ----------------------------------------------------------------
Write-Host "Checking if Nano Node service already exists..." -ForegroundColor Cyan
$existingService = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue

if ($existingService) {
    $serviceStatus = $existingService.Status
    Write-Host "Nano Node service is already installed. Current status: $serviceStatus. Skipping." -ForegroundColor Green
} else {
    Write-Host "Registering Nano Node as a Windows service..." -ForegroundColor Cyan
    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "install" -Wait -NoNewWindow
    Write-Host "Service registered." -ForegroundColor Gray

    Write-Host "Starting Nano Node daemon..." -ForegroundColor Cyan
    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "start" -Wait -NoNewWindow
    Write-Host "Nano Node is now running as a background service." -ForegroundColor Green

    # Write install date ONCE (never overwritten)
    if (-Not (Test-Path "C:\nano-node\install_date.txt")) {
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Out-File "C:\nano-node\install_date.txt"
        Write-Host "Install date recorded." -ForegroundColor Gray
    }

    Write-Host "Waiting 45 seconds for node to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 45
    Write-Host "Node initialized." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 11 -- Set up odometer via Task Scheduler
# ----------------------------------------------------------------
Write-Host "Setting up odometer..." -ForegroundColor Cyan

if (-Not (Test-Path "C:\nano-node\uptime_minutes.txt")) {
    New-Item -ItemType File -Path "C:\nano-node\uptime_minutes.txt" | Out-Null
    Write-Host "Odometer file created." -ForegroundColor Gray
}

$odometerScript = @'
$service = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Add-Content -Path "C:\nano-node\uptime_minutes.txt" -Value "1"
}
'@
$odometerScript | Out-File -FilePath "C:\nano-node\odometer.ps1" -Encoding UTF8
Write-Host "Odometer script created." -ForegroundColor Gray

$existingTask = Get-ScheduledTask -TaskName "NanoNodeOdometer" -ErrorAction SilentlyContinue
if (-Not $existingTask) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\nano-node\odometer.ps1"
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 1) -Once -At (Get-Date)
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    Register-ScheduledTask -TaskName "NanoNodeOdometer" -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Write-Host "Odometer task registered." -ForegroundColor Green
} else {
    Write-Host "Odometer task already exists. Skipping." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Step 12 -- Add to PATH, set ExecutionPolicy, create dashboard.bat
# ----------------------------------------------------------------
Write-Host "Checking system PATH..." -ForegroundColor Cyan
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*C:\nano-node*") {
    [Environment]::SetEnvironmentVariable("Path", $currentPath + ";C:\nano-node", "Machine")
    Write-Host "C:\nano-node added to system PATH." -ForegroundColor Green
} else {
    Write-Host "C:\nano-node already in PATH. Skipping." -ForegroundColor Green
}

Write-Host "Setting PowerShell ExecutionPolicy..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
} catch {
    # Policy already set or overridden at higher scope - this is fine
}
Write-Host "ExecutionPolicy configured." -ForegroundColor Green

Write-Host "Creating dashboard launcher..." -ForegroundColor Cyan
$batContent = '@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\nano-node\dashboard.ps1"'
$batContent | Out-File -FilePath "C:\nano-node\dashboard.bat" -Encoding ASCII
Write-Host "dashboard.bat created." -ForegroundColor Green

# ----------------------------------------------------------------
# Step 13 -- Final Summary and Dashboard Prompt
# ----------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           NANO NODE SETUP COMPLETE" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [OK] Nano Node is running as a background service" -ForegroundColor White
Write-Host "  [OK] Ledger snapshot loaded  (you saved 90+ hours of sync time)" -ForegroundColor White
Write-Host "  [OK] Odometer is active and counting uptime every minute" -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Download a Live Dashboard Tool for your Node:" -ForegroundColor White
Write-Host ""
Write-Host "  Benefits:" -ForegroundColor White
Write-Host "  1. Monitor Node Stats (Block Count, Sync% etc.)" -ForegroundColor Gray
Write-Host "  2. See Live System Usage of Node" -ForegroundColor Gray
Write-Host "  3. See Power Consumption of the Node" -ForegroundColor Gray
Write-Host ""
Write-Host "  Future Implementations:" -ForegroundColor White
Write-Host "  - One click Node control on your browser" -ForegroundColor Gray
Write-Host "  - Create Representative Node with 1 click" -ForegroundColor Gray
Write-Host "  - Edit Config Files with 1 click" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
$choice = Read-Host "  Would you like to install the Dashboard Tool? (Y/N)"

if ($choice -eq "Y" -or $choice -eq "y") {
    Write-Host ""
    Write-Host "  Downloading and installing Nano Dashboard..." -ForegroundColor Cyan
    $dashboardInstallerUrl = "https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/dashboard-installer.ps1"
    Invoke-WebRequest -Uri $dashboardInstallerUrl -OutFile "$env:TEMP\dashboard-installer.ps1" -UseBasicParsing
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$env:TEMP\dashboard-installer.ps1`"" -Verb RunAs
} else {
    Write-Host ""
    Write-Host "  If you change your mind, you can manually download the dashboard from:" -ForegroundColor Gray
    Write-Host "  https://github.com/clixio14/Auto-Nano-Node-Windows/releases" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    # Keep terminal open silently
    cmd /c pause > nul
}
