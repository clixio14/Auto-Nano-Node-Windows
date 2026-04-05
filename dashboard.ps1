# ================================================================
#              NANO NODE MINI-DASHBOARD
#              Version 1.1
# ================================================================

$currentVersion = "1.1"
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
# Helper: Check if node service is running
# ----------------------------------------------------------------
function Is-NodeRunning {
    $svc = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue
    $proc = Get-Process -Name "nano_node" -ErrorAction SilentlyContinue
    return ($svc -and $svc.Status -eq "Running" -and $proc)
}

# ----------------------------------------------------------------
# Helper: Show transition message screen
# ----------------------------------------------------------------
function Show-Message {
    param([string]$msg)
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "                 NANO NODE MINI-DASHBOARD" -ForegroundColor White
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  >>> $msg" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
}

# ----------------------------------------------------------------
# Offline Banner (node is stopped)
# ----------------------------------------------------------------
function Show-OfflineBanner {
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "                 NANO NODE MINI-DASHBOARD" -ForegroundColor White
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host " Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                  *** NODE IS STOPPED ***" -ForegroundColor Red
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " [" -NoNewline; Write-Host "S" -ForegroundColor Red -NoNewline; Write-Host "] Start Node        [" -NoNewline; Write-Host "CTRL+C" -ForegroundColor Red -NoNewline; Write-Host "] Exit Dashboard"
    Write-Host "===============================================================" -ForegroundColor Cyan
}

# ----------------------------------------------------------------
# Helper: Get highest block count from public Nano RPC endpoints
# ----------------------------------------------------------------
function Get-NetworkBlockCount {
    $endpoints = @(
        "https://rpc.nano.to",
        "https://rainstorm.city/api",
        "https://node.somenano.com/proxy",
        "https://app.natrium.io/api",
        "https://nanoslo.1na.no/proxy",
        "https://blocklattice.io/api/rpc"
    )
    # Shuffle the array to spread load
    $endpoints = $endpoints | Sort-Object { Get-Random }
    $highest = 0
    foreach ($ep in $endpoints) {
        try {
            $r = Invoke-RestMethod -Uri $ep -Method Post -Body '{"action":"block_count"}' -ContentType "application/json" -TimeoutSec 5
            $count = [long]$r.count
            if ($count -gt $highest) { $highest = $count }
        } catch {
            # Endpoint failed -- skip silently
        }
    }
    return $highest
}

# ----------------------------------------------------------------
# Main Dashboard (node is running)
# ----------------------------------------------------------------
function Show-Dashboard {
    Clear-Host
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "                 NANO NODE MINI-DASHBOARD" -ForegroundColor White
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host " Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

    # =============================================================
    # System Stats
    # =============================================================
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " System Stats" -ForegroundColor White
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan

    # CPU, RAM, Power (wrapped in try/catch in case process stops mid-refresh)
    try {
        $cpuCounter1 = (Get-Counter "\Process(nano_node)\% Processor Time").CounterSamples.CookedValue
        Start-Sleep -Seconds 1
        $cpuCounter2 = (Get-Counter "\Process(nano_node)\% Processor Time").CounterSamples.CookedValue

        $logicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        $physicalCores     = (Get-CimInstance Win32_Processor).NumberOfCores
        $cpuPercent  = ($cpuCounter1 + $cpuCounter2) / 2 / $logicalProcessors
        $coresUsed   = [math]::Round($cpuPercent / 100 * $physicalCores, 2)
        if ($coresUsed -lt 0.5) { $coresUsed = 0.5 }

        $threads = (Get-Process -Name "nano_node").Threads.Count

        $nanoProcess        = Get-Process -Name "nano_node" -ErrorAction SilentlyContinue
        $serviceProcess     = Get-Process -Name "nano-node-service" -ErrorAction SilentlyContinue

        $nodePrivateBytes   = $nanoProcess.PrivateMemorySize64 + $serviceProcess.PrivateMemorySize64
        $lmdbBytes          = $nanoProcess.WorkingSet64

        $nodePrivateMB      = [math]::Round($nodePrivateBytes / 1MB, 0)
        $lmdbMB             = [math]::Round($lmdbBytes / 1MB, 0)

        $nodeRamDisplay     = if ($nodePrivateMB -ge 1024) { "$([math]::Round($nodePrivateMB / 1024, 2)) GB" } else { "$nodePrivateMB MB" }
        $lmdbRamDisplay     = if ($lmdbMB -ge 1024) { "$([math]::Round($lmdbMB / 1024, 2)) GB" } else { "$lmdbMB MB" }

        $cpuWatts       = $coresUsed * 5
        $nodeRamGB      = $nodePrivateBytes / 1GB
        $lmdbRamGB      = $lmdbBytes / 1GB
        $ramWatts       = ($nodeRamGB + $lmdbRamGB) * 1.5
        $threadOverhead = $threads * 0.05
        $networkWatts   = 0
        $ioOverhead     = 5
        $totalWatts     = [math]::Round($cpuWatts + $ramWatts + $threadOverhead + $networkWatts + $ioOverhead)

        Write-Host ("CPU Core Usage    | " + $coresUsed + " core / " + $physicalCores + " cores")
        Write-Host ("Node RAM Usage    | " + $nodeRamDisplay)
        Write-Host ("LMDB Memory Map   | " + $lmdbRamDisplay + "  (Ledger mapped into RAM by LMDB)")
        Write-Host ("Power Est. (Watts)| " + $totalWatts + " Watts  (Incl. LMDB Overhead and I/O)")
    } catch {
        Write-Host ("CPU Core Usage    | Initializing...") -ForegroundColor Yellow
        Write-Host ("Node RAM Usage    | Initializing...") -ForegroundColor Yellow
        Write-Host ("LMDB Memory Map   | Initializing...") -ForegroundColor Yellow
        Write-Host ("Power Est. (Watts)| Initializing...") -ForegroundColor Yellow
    }

    # Internet Usage via RPC stats
    $rpcUrl = "http://localhost:7076"
    try {
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
    } catch {
        Write-Host ("Internet Usage    | Initializing...") -ForegroundColor Yellow
    }

    # =============================================================
    # Node Stats
    # =============================================================
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Node Stats" -ForegroundColor White
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan

    # Service Status, Created Since, Concurrent Uptime
    $service = Get-Service -Name "nano-node" -ErrorAction SilentlyContinue
    $status = if ($service.Status -eq "Running") { "Running" } else { "Stopped" }

    $installDate = Get-Date (Get-Content "C:\nano-node\install_date.txt")
    $createdSince = (Get-Date) - $installDate
    $createdSinceStr = "$($createdSince.Days)d $($createdSince.Hours)h $($createdSince.Minutes)m"

    $nanoProcess = Get-Process -Name "nano_node" -ErrorAction SilentlyContinue
    if ($nanoProcess) {
        $concurrent = (Get-Date) - $nanoProcess.StartTime
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

    # Block counts: network vs local node
    try {
        $tel = Invoke-RestMethod -Uri $rpcUrl -Method Post -Body '{"action":"telemetry"}' -ContentType "application/json"

        $blockCount  = [long]$tel.block_count
        $peerCount   = $tel.peer_count
        $nodeVersion = "$($tel.major_version).$($tel.minor_version).$($tel.patch_version)"
        $bandwidthMB = [math]::Round([long]$tel.bandwidth_cap / 1MB, 0)
        $nodeId      = $tel.node_id

        # Get network block count from public endpoints
        $networkBlock = Get-NetworkBlockCount
        if ($networkBlock -gt 0) {
            $blocksGap = $networkBlock - $blockCount
            if ($blocksGap -lt 0) { $blocksGap = 0 }
            $syncPercent = [math]::Round(($blockCount / $networkBlock) * 100, 4)

            Write-Host ("Nano Block        | " + $networkBlock + "  (Latest Nano Network's Block)")
            Write-Host ("Block Count       | " + $blockCount + "  (Your Node's Block)")
            Write-Host ("Blocks Gap        | " + $blocksGap)
            Write-Host ("Sync %            | " + $syncPercent + "%")
        } else {
            Write-Host ("Nano Block        | N/A  (Could not reach public nodes)") -ForegroundColor Yellow
            Write-Host "Block Count       | " -NoNewline
            Write-Host $blockCount -ForegroundColor Cyan -NoNewline
            Write-Host "  (Your Node's Block)"
            Write-Host ("Blocks Gap        | N/A") -ForegroundColor Yellow
            Write-Host ("Sync %            | N/A") -ForegroundColor Yellow
        }

        Write-Host ("Peer Count        | " + $peerCount)
        Write-Host ("Node Version      | V" + $nodeVersion)
        Write-Host ("Bandwidth Cap     | " + $bandwidthMB + " MB/s")
    } catch {
        Write-Host ("Nano Block        | Initializing...") -ForegroundColor Yellow
        Write-Host ("Block Count       | Initializing...") -ForegroundColor Yellow
        Write-Host ("Blocks Gap        | Initializing...") -ForegroundColor Yellow
        Write-Host ("Sync %            | Initializing...") -ForegroundColor Yellow
        Write-Host ("Peer Count        | Initializing...") -ForegroundColor Yellow
        Write-Host ("Node Version      | Initializing...") -ForegroundColor Yellow
        Write-Host ("Bandwidth Cap     | Initializing...") -ForegroundColor Yellow
        $nodeId = $null
    }

    # =============================================================
    # Node Details
    # =============================================================
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Node Details" -ForegroundColor White
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan

    if ($nodeId) {
        Write-Host ("Node ID           | " + $nodeId)
    } else {
        Write-Host ("Node ID           | Initializing...") -ForegroundColor Yellow
    }

    # Footer
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " [" -NoNewline; Write-Host "X" -ForegroundColor Red -NoNewline
    Write-Host "] Stop Node   [" -NoNewline; Write-Host "S" -ForegroundColor Red -NoNewline
    Write-Host "] Start Node   [" -NoNewline; Write-Host "R" -ForegroundColor Red -NoNewline
    Write-Host "] Restart Node   [" -NoNewline; Write-Host "CTRL+C" -ForegroundColor Red -NoNewline
    Write-Host "] Exit"
    Write-Host " Auto-refreshing every 30 seconds. Press [CTRL+C] to stop." -ForegroundColor Gray
    Write-Host " Your Nano node will keep running even if you stop the dashboard." -ForegroundColor Gray
    Write-Host " To reopen dashboard double-click " -ForegroundColor Gray -NoNewline
    Write-Host "Nano Dashboard" -ForegroundColor Magenta -NoNewline
    Write-Host " on your Desktop or Start Menu" -ForegroundColor Gray
    Write-Host "===============================================================" -ForegroundColor Cyan
}

# ----------------------------------------------------------------
# Key Handler (waits 30 seconds, checks for keypresses)
# ----------------------------------------------------------------
function Handle-Keys {
    # Flush any leftover key events (both key-down AND key-up) from buffer
    while ($host.UI.RawUI.KeyAvailable) {
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp") | Out-Null
    }
    $end = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $end) {
        if ($host.UI.RawUI.KeyAvailable) {
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
            # Only act on key-down events; silently discard key-up events
            if (-not $key.KeyDown) { continue }
            $char = [string]$key.Character
            if ($char -eq "x" -or $char -eq "X") {
                if (Is-NodeRunning) {
                    Show-Message "Stopping Nano Node... please wait"
                    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "stop" -Wait -NoNewWindow
                    Start-Sleep -Seconds 2
                }
                # Flush phantom console events left by Start-Process -NoNewWindow
                while ($host.UI.RawUI.KeyAvailable) {
                    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp") | Out-Null
                }
                return
            } elseif ($char -eq "s" -or $char -eq "S") {
                if (-Not (Is-NodeRunning)) {
                    Show-Message "Starting Nano Node... please wait"
                    Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "start" -Wait -NoNewWindow
                    Start-Sleep -Seconds 45
                }
                # Flush phantom console events left by Start-Process -NoNewWindow
                while ($host.UI.RawUI.KeyAvailable) {
                    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp") | Out-Null
                }
                return
            } elseif ($char -eq "r" -or $char -eq "R") {
                Show-Message "Restarting Nano Node... please wait"
                Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "stop" -Wait -NoNewWindow
                Start-Sleep -Seconds 3
                Start-Process "C:\nano-node\nano-node-service.exe" -ArgumentList "start" -Wait -NoNewWindow
                Start-Sleep -Seconds 45
                # Flush phantom console events left by Start-Process -NoNewWindow
                while ($host.UI.RawUI.KeyAvailable) {
                    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp") | Out-Null
                }
                return
            }
            # Unrecognized key -- skip the sleep and immediately check for next key
            continue
        }
        Start-Sleep -Milliseconds 500
    }
}

# ----------------------------------------------------------------
# Main Loop
# ----------------------------------------------------------------
while ($true) {
    if (Is-NodeRunning) {
        Show-Dashboard
    } else {
        Show-OfflineBanner
    }
    Handle-Keys
    # Clear screen immediately after key action so transition message doesnt linger
    Clear-Host
}
