# ================================================================
#              NANO NODE MINI-DASHBOARD
#              Version 1.0
# ================================================================

$currentVersion = "1.0"
$versionUrl     = "https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/version.txt"
$dashboardUrl   = "https://raw.githubusercontent.com/clixio14/Auto-Nano-Node-Windows/main/dashboard.ps1"

# ----------------------------------------------------------------
# Version Check
# ----------------------------------------------------------------
try {
    $latestVersion = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -TimeoutSec 5).Content.Trim()

    if ($latestVersion -ne $currentVersion) {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "  Update Available!" -ForegroundColor Yellow
        Write-Host "  Current Version : $currentVersion" -ForegroundColor Gray
        Write-Host "  Latest Version  : $latestVersion" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        $updateChoice = Read-Host "  Would you like to update now? (Y/N)"

        if ($updateChoice -eq "Y" -or $updateChoice -eq "y") {
            Write-Host ""
            Write-Host "  Downloading latest dashboard..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $dashboardUrl -OutFile "C:\nano-node\dashboard.ps1" -UseBasicParsing
            Write-Host "  Update complete. Restarting dashboard..." -ForegroundColor Green
            Start-Sleep -Seconds 2
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\nano-node\dashboard.ps1`""
            exit
        } else {
            Write-Host ""
            Write-Host "  Continuing with current version..." -ForegroundColor Gray
            Start-Sleep -Seconds 1
        }
    }
} catch {
    # No internet or version check failed -- skip silently and continue
}

# ----------------------------------------------------------------
# Dashboard Function
# ----------------------------------------------------------------
function Show-Dashboard {
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "                 NANO NODE MINI-DASHBOARD" -ForegroundColor White
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host " Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan

    # Service Status, Created Since, Concurrent Uptime
    $service = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue
    $status = if ($service.Status -eq "Running") { "Running" } else { "Stopped" }

    $installDate = Get-Date (Get-Content "C:\nano-node\install_date.txt")
    $createdSince = (Get-Date) - $installDate
    $createdSinceStr = "$($createdSince.Days)d $($createdSince.Hours)h $($createdSince.Minutes)m"

    $process = Get-Process -Name "nano_node" -ErrorAction SilentlyContinue
    if ($process) {
        $concurrent = (Get-Date) - $process.StartTime
        $concurrentStr = "$($concurrent.Days)d $($concurrent.Hours)h $($concurrent.Minutes)m"
    } else {
        $concurrentStr = "Not Running"
    }

    Write-Host ("Service Status    | " + $status)
    Write-Host ("Created Since     | " + $createdSinceStr)
    Write-Host ("Concurrent Uptime | " + $concurrentStr)

    # Cumulative Uptime and Active Uptime %
    $totalMinutes = (Get-Content "C:\nano-node\uptime_minutes.txt" | Measure-Object -Line).Lines
    $cumulativeStr = "$([math]::Floor($totalMinutes / 1440))d $([math]::Floor(($totalMinutes % 1440) / 60))h $($totalMinutes % 60)m"
    $totalPossibleMinutes = [math]::Floor(((Get-Date) - $installDate).TotalMinutes)
    $activePercent = [math]::Round(($totalMinutes / $totalPossibleMinutes) * 100, 2)

    Write-Host ("Cumulative Uptime | " + $cumulativeStr)
    Write-Host ("Active Uptime %   | " + $activePercent + "%")

    # CPU Core Usage and Threads
    $cpuCounter1 = (Get-Counter "\Process(nano_node)\% Processor Time").CounterSamples.CookedValue
    Start-Sleep -Seconds 1
    $cpuCounter2 = (Get-Counter "\Process(nano_node)\% Processor Time").CounterSamples.CookedValue

    $logicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    $physicalCores = (Get-CimInstance Win32_Processor).NumberOfCores
    $cpuPercent = ($cpuCounter1 + $cpuCounter2) / 2 / $logicalProcessors
    $coresUsed = [math]::Round($cpuPercent / 100 * $physicalCores, 2)
    if ($coresUsed -eq 0) { $coresUsed = 0.5 }

    $threads = (Get-Process -Name "nano_node").Threads.Count

    Write-Host ("CPU Core Usage    | " + $coresUsed + " core / " + $physicalCores + " cores")
    Write-Host ("CPU Threads       | " + $threads + " threads")

    # Node RAM and LMDB Memory Map
    $nanoRamBytes = (Get-Process -Name "nano_node").WorkingSet64
    $nanoRamMB = [math]::Round($nanoRamBytes / 1MB, 0)
    $nanoRamDisplay = if ($nanoRamMB -ge 1024) { "$([math]::Round($nanoRamMB / 1024, 2)) GB" } else { "$nanoRamMB MB" }

    $lmdbRamBytes = (Get-Process -Name "nano-node-service").WorkingSet64
    $lmdbRamMB = [math]::Round($lmdbRamBytes / 1MB, 0)
    $lmdbRamDisplay = if ($lmdbRamMB -ge 1024) { "$([math]::Round($lmdbRamMB / 1024, 2)) GB" } else { "$lmdbRamMB MB" }

    Write-Host ("Node RAM Usage    | " + $nanoRamDisplay)
    Write-Host ("LMDB Memory Map   | " + $lmdbRamDisplay + "  (Ledger mapped into RAM by LMDB)")

    # Network Speed via RPC stats
    $rpcUrl = "http://localhost:7076"
    $body   = '{"action":"stats","type":"counters"}'

    $s1  = Invoke-RestMethod -Uri $rpcUrl -Method Post -Body $body -ContentType "application/json"
    $rx1 = [long]($s1.entries | Where-Object { $_.type -eq "traffic_tcp" -and $_.detail -eq "all" -and $_.dir -eq "in" }).value
    $tx1 = [long]($s1.entries | Where-Object { $_.type -eq "traffic_tcp" -and $_.detail -eq "all" -and $_.dir -eq "out" }).value

    Start-Sleep -Seconds 1

    $s2  = Invoke-RestMethod -Uri $rpcUrl -Method Post -Body $body -ContentType "application/json"
    $rx2 = [long]($s2.entries | Where-Object { $_.type -eq "traffic_tcp" -and $_.detail -eq "all" -and $_.dir -eq "in" }).value
    $tx2 = [long]($s2.entries | Where-Object { $_.type -eq "traffic_tcp" -and $_.detail -eq "all" -and $_.dir -eq "out" }).value

    $downMbps = [math]::Round(($rx2 - $rx1) * 8 / 1MB, 2)
    $upMbps   = [math]::Round(($tx2 - $tx1) * 8 / 1MB, 2)

    Write-Host ("Internet Usage    | " + $downMbps + " Mbps Down / " + $upMbps + " Mbps Up")

    # Node stats from telemetry
    $tel = Invoke-RestMethod -Uri $rpcUrl -Method Post -Body '{"action":"telemetry"}' -ContentType "application/json"

    $blockCount  = $tel.block_count
    $peerCount   = $tel.peer_count
    $nodeVersion = "$($tel.major_version).$($tel.minor_version).$($tel.patch_version)"
    $bandwidthMB = [math]::Round([long]$tel.bandwidth_cap / 1MB, 0)
    $nodeId      = $tel.node_id

    Write-Host ("Block Count       | " + $blockCount)
    Write-Host ("Peer Count        | " + $peerCount)
    Write-Host ("Node Version      | V" + $nodeVersion)
    Write-Host ("Bandwidth Cap     | " + $bandwidthMB + " MB/s")
    Write-Host ("Node ID           | " + $nodeId)

    # Power Consumption Estimate
    $cpuTDP         = (Get-CimInstance Win32_Processor).NumberOfCores * 5
    $cpuWatts       = $cpuTDP * ($cpuPercent / 100)
    $nanoRamGB      = $nanoRamBytes / 1GB
    $lmdbRamGB      = $lmdbRamBytes / 1GB
    $ramWatts       = ($nanoRamGB + $lmdbRamGB) * 1.5
    $threadOverhead = $threads * 0.05
    $totalWatts     = [math]::Round($cpuWatts + $ramWatts + $threadOverhead)

    Write-Host "Power Consumption (Est.) | " -NoNewline
    Write-Host "$totalWatts Watts" -ForegroundColor Cyan -NoNewline
    Write-Host "  (Incl. LMDB Overhead)"

    # Footer
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Auto-refreshing every 30 seconds. Press [CTRL+C] to stop." -ForegroundColor Gray
    Write-Host " Your Nano node will keep running even if you stop the dashboard." -ForegroundColor Gray
    Write-Host " To check dashboard again open a new PowerShell terminal and type: " -ForegroundColor Gray -NoNewline
    Write-Host "dashboard" -ForegroundColor Magenta
    Write-Host "===============================================================" -ForegroundColor Cyan
}

# ----------------------------------------------------------------
# 30 Second Refresh Loop
# ----------------------------------------------------------------
while ($true) {
    Show-Dashboard
    Start-Sleep -Seconds 30
}
