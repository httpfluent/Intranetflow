# =====================================================
# Python + httpfluent (user-only, fully automatic)
# =====================================================

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Step 0: Detect existing Python >=3.9
# -----------------------------
$BestPython = $null
$Candidates = @()

# Check Python in PATH
$cmd = Get-Command python -ErrorAction SilentlyContinue
if ($cmd) { $Candidates += $cmd.Source }

$cmd = Get-Command python3 -ErrorAction SilentlyContinue
if ($cmd) { $Candidates += $cmd.Source }

# Check common user install directories
$Roots = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:APPDATA\Python",
    "C:\Program Files\Python*",
    "C:\Program Files (x86)\Python*"
)

foreach ($root in $Roots) {
    if ($root -like "*\*") {
        Get-ChildItem -Path (Split-Path $root) -Directory -Filter (Split-Path $root -Leaf) -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) { $Candidates += $exe }
        }
    } elseif (Test-Path $root) {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) { $Candidates += $exe }
        }
    }
}

# Pick first Python >=3.9
foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    try {
        $versionOutput = & $candidate --version 2>&1 | Out-String
        if ($versionOutput -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            
            if (($major -eq 3 -and $minor -ge 9) -or $major -gt 3) {
                $BestPython = $candidate
                Write-Host "[+] Found Python: $versionOutput (at $candidate)" -ForegroundColor Green
                break
            }
        }
    } catch {
        continue
    }
}

# -----------------------------
# Step 1: Install Python 3.12 if needed
# -----------------------------
if (-not $BestPython) {
    Write-Host "[!] No suitable Python found. Installing Python 3.12.6 (user-mode)..." -ForegroundColor Yellow

    $PythonRoot = "$env:LOCALAPPDATA\Programs\Python\Python312"
    $PythonExe = Join-Path $PythonRoot "python.exe"

    if (Test-Path $PythonExe) {
        Write-Host "[+] Python 3.12 already installed at $PythonRoot" -ForegroundColor Green
        $BestPython = $PythonExe
    } else {
        $Installer = "$env:TEMP\python-3.12.6-amd64.exe"
        
        Write-Host "[*] Downloading Python installer..." -ForegroundColor Cyan
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile(
                "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe",
                $Installer
            )
        } catch {
            Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" `
                -OutFile $Installer -UseBasicParsing
        }

        Write-Host "[*] Installing Python (this may take 1-2 minutes)..." -ForegroundColor Cyan
        
        $installArgs = @(
            "/quiet",
            "InstallAllUsers=0",
            "PrependPath=0",
            "Include_test=0",
            "SimpleInstall=1",
            "TargetDir=`"$PythonRoot`""
        )
        
        Start-Process -FilePath $Installer -ArgumentList $installArgs -Wait -NoNewWindow
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path $PythonExe)) {
            Write-Host "[-] Python installation failed." -ForegroundColor Red
            exit 1
        }

        $BestPython = $PythonExe
        Write-Host "[+] Python 3.12.6 installed successfully!" -ForegroundColor Green
    }
}

# -----------------------------
# Step 2: Get correct user Scripts directory
# -----------------------------
Write-Host "[*] Detecting user Scripts directory..." -ForegroundColor Cyan

$UserScriptsDir = & $BestPython -c @"
import sysconfig
import os
# Force user scheme
user_base = sysconfig.get_config_var('userbase')
if not user_base:
    import site
    user_base = site.USER_BASE
scripts_dir = os.path.join(user_base, 'Scripts')
print(scripts_dir)
"@ 2>&1 | Select-Object -Last 1

$UserScriptsDir = $UserScriptsDir.Trim()
Write-Host "[+] User Scripts directory: $UserScriptsDir" -ForegroundColor Green

# Create Scripts directory if it doesn't exist
if (-not (Test-Path $UserScriptsDir)) {
    New-Item -Path $UserScriptsDir -ItemType Directory -Force | Out-Null
}

# -----------------------------
# Step 3: Upgrade pip (user-mode)
# -----------------------------
Write-Host "[*] Ensuring pip is installed..." -ForegroundColor Cyan
& $BestPython -m ensurepip --upgrade --user 2>&1 | Out-Null

Write-Host "[*] Upgrading pip..." -ForegroundColor Cyan
& $BestPython -m pip install --upgrade pip --user --quiet --no-warn-script-location --disable-pip-version-check 2>&1 | Out-Null

# -----------------------------
# Step 4: Install dependencies (user-mode)
# -----------------------------
Write-Host "[*] Installing requests..." -ForegroundColor Cyan
& $BestPython -m pip install requests --user --quiet --no-warn-script-location --disable-pip-version-check 2>&1 | Out-Null

Write-Host "[*] Installing httpfluent..." -ForegroundColor Cyan
$httpfluentUrl = "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"
& $BestPython -m pip install $httpfluentUrl --user --quiet --no-warn-script-location --disable-pip-version-check --force-reinstall 2>&1 | Out-Null

# -----------------------------
# Step 5: Find and run httpfluent
# -----------------------------
$HttpFluentExe = Join-Path $UserScriptsDir "httpfluent.exe"
$HttpFluentScript = Join-Path $UserScriptsDir "httpfluent"

Write-Host "[*] Looking for httpfluent..." -ForegroundColor Cyan

if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Found httpfluent.exe" -ForegroundColor Green
    Write-Host "[+] Running httpfluent --help..." -ForegroundColor Green
    & $HttpFluentExe --help
} elseif (Test-Path $HttpFluentScript) {
    Write-Host "[+] Found httpfluent script" -ForegroundColor Green
    Write-Host "[+] Running httpfluent --help..." -ForegroundColor Green
    & $BestPython $HttpFluentScript --help
} else {
    Write-Host "[!] Executable not found. Trying module import..." -ForegroundColor Yellow
    
    $moduleTest = & $BestPython -c "import httpfluent; print('OK')" 2>&1
    if ($moduleTest -like "*OK*") {
        Write-Host "[+] httpfluent module installed successfully!" -ForegroundColor Green
        Write-Host "[+] Running httpfluent --help..." -ForegroundColor Green
        & $BestPython -m httpfluent --help 2>&1
    } else {
        Write-Host "[-] httpfluent installation failed." -ForegroundColor Red
        Write-Host "[*] Debug info:" -ForegroundColor Yellow
        Write-Host "    Python: $BestPython" -ForegroundColor Yellow
        Write-Host "    Scripts: $UserScriptsDir" -ForegroundColor Yellow
        Write-Host "[*] Try manual installation:" -ForegroundColor Yellow
        Write-Host "    $BestPython -m pip install --user $httpfluentUrl" -ForegroundColor Yellow
    }
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
