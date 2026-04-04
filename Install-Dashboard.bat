@echo off
echo.
echo ================================================================
echo          NANO DASHBOARD INSTALLER
echo ================================================================
echo.
echo Setting up Nano Dashboard, please wait...
echo.
powershell.exe -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "Write-Host 'Downloading dashboard...' -ForegroundColor Cyan;" ^
    "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/dashboard.ps1' -OutFile 'C:\nano-node\dashboard.ps1' -UseBasicParsing;" ^
    "Write-Host 'Creating dashboard launcher...' -ForegroundColor Cyan;" ^
    "$bat = '@echo off`npowershell.exe -ExecutionPolicy Bypass -File ""C:\nano-node\dashboard.ps1""';" ^
    "$bat | Out-File -FilePath 'C:\nano-node\dashboard.bat' -Encoding ASCII;" ^
    "Write-Host 'Creating Desktop shortcut...' -ForegroundColor Cyan;" ^
    "$ws = New-Object -ComObject WScript.Shell;" ^
    "$sc = $ws.CreateShortcut([Environment]::GetFolderPath('CommonDesktopDirectory') + '\Nano Dashboard.lnk');" ^
    "$sc.TargetPath = 'powershell.exe';" ^
    "$sc.Arguments = '-ExecutionPolicy Bypass -File ""C:\nano-node\dashboard.ps1""';" ^
    "$sc.WorkingDirectory = 'C:\nano-node';" ^
    "$sc.Description = 'Nano Node Live Dashboard';" ^
    "$sc.Save();" ^
    "Write-Host 'Creating Start Menu shortcut...' -ForegroundColor Cyan;" ^
    "$sc2 = $ws.CreateShortcut([Environment]::GetFolderPath('CommonPrograms') + '\Nano Dashboard.lnk');" ^
    "$sc2.TargetPath = 'powershell.exe';" ^
    "$sc2.Arguments = '-ExecutionPolicy Bypass -File ""C:\nano-node\dashboard.ps1""';" ^
    "$sc2.WorkingDirectory = 'C:\nano-node';" ^
    "$sc2.Description = 'Nano Node Live Dashboard';" ^
    "$sc2.Save();" ^
    "Write-Host '' ;" ^
    "Write-Host '================================================================' -ForegroundColor Cyan;" ^
    "Write-Host '       NANO DASHBOARD INSTALLED SUCCESSFULLY' -ForegroundColor White;" ^
    "Write-Host '================================================================' -ForegroundColor Cyan;" ^
    "Write-Host '';" ^
    "Write-Host '  [OK] Dashboard downloaded and ready' -ForegroundColor White;" ^
    "Write-Host '  [OK] Desktop shortcut created  (Nano Dashboard)' -ForegroundColor White;" ^
    "Write-Host '  [OK] Start Menu shortcut created  (Nano Dashboard)' -ForegroundColor White;" ^
    "Write-Host '';" ^
    "Write-Host '  Double-click ' -ForegroundColor White -NoNewline;" ^
    "Write-Host 'Nano Dashboard' -ForegroundColor Magenta -NoNewline;" ^
    "Write-Host ' on your Desktop or Start Menu to get started' -ForegroundColor White;" ^
    "Write-Host '';" ^
    "Write-Host '================================================================' -ForegroundColor Cyan;"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Dashboard installation failed. See above for details.
    pause
    exit /b 1
)
pause
