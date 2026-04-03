@echo off
echo.
echo ================================================================
echo          NANO NODE WINDOWS INSTALLER
echo ================================================================
echo.
echo Downloading installer, please wait...
echo.
powershell.exe -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/Nano-Node.ps1' -OutFile '%TEMP%\Nano-Node.ps1' -UseBasicParsing"
echo.
echo Launching installer...
powershell.exe -ExecutionPolicy Bypass -File "%TEMP%\Nano-Node.ps1"
