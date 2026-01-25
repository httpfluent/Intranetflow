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

# Check common install directories
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
        Write-Host "[+] Python 3.12 already installed" -ForegroundColor Green
        $BestPython = $PythonExe
    } else {
        $Installer = "$env:TEMP\python-3.12.6-amd64.exe"
        
        Write-Host "[*] Downloading Python installer..." -ForegroundColor Cyan
        try {
            (New-Object System.Net.WebClient).DownloadFile(
                "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe",
                $Installer
            )
        } catch {
            Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" `
                -OutFile $Installer -UseBasicParsing
        }

        Write-Host "[*] Installing Python..." -ForegroundColor Cyan
        
        Start-Process -FilePath $Installer -ArgumentList @(
            "/quiet",
            "InstallAllUsers=0",
            "PrependPath=0",
            "Include_test=0",
            "SimpleInstall=1",
            "TargetDir=`"$PythonRoot`""
        ) -Wait -NoNewWindow
        
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue

        if (Test-Path $PythonExe) {
            $BestPython = $PythonExe
            Write-Host "[+] Python installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "[-] Python installation failed." -ForegroundColor Red
            exit 1
        }
    }
}

# -----------------------------
# Step 2: Get user Scripts directory
# -----------------------------
Write-Host "[*] Detecting user Scripts directory..." -ForegroundColor Cyan

$UserScriptsDir = & $BestPython -c @"
import sysconfig, site, os
user_base = site.USER_BASE
if os.name == 'nt':
    scripts_dir = os.path.join(user_base, 'Scripts')
else:
    scripts_dir = os.path.join(user_base, 'bin')
print(scripts_dir)
"@ 2>&1 | Select-Object -Last 1

$UserScriptsDir = $UserScriptsDir.Trim()
Write-Host "[+] User Scripts: $UserScriptsDir" -ForegroundColor Green

if (-not (Test-Path $UserScriptsDir)) {
    New-Item -Path $UserScriptsDir -ItemType Directory -Force | Out-Null
}

# -----------------------------
# Step 3: Upgrade pip
# -----------------------------
Write-Host "[*] Upgrading pip..." -ForegroundColor Cyan
& $BestPython -m ensurepip --upgrade --user 2>&1 | Out-Null
& $BestPython -m pip install --upgrade pip --user --quiet --no-warn-script-location --disable-pip-version-check 2>&1 | Out-Null

# -----------------------------
# Step 4: Install httpfluent
# -----------------------------
Write-Host "[*] Installing requests..." -ForegroundColor Cyan
& $BestPython -m pip install requests --user --quiet --no-warn-script-location --disable-pip-version-check 2>&1 | Out-Null

Write-Host "[*] Installing httpfluent..." -ForegroundColor Cyan
$httpfluentUrl = "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"
& $BestPython -m pip install $httpfluentUrl --user --quiet --no-warn-script-location --disable-pip-version-check --force-reinstall 2>&1 | Out-Null

# -----------------------------
# Step 5: Verify installation
# -----------------------------
Write-Host "[*] Verifying installation..." -ForegroundColor Cyan

$verifyResult = & $BestPython -c "import httpfluent; print('OK')" 2>&1
if ($verifyResult -notlike "*OK*") {
    Write-Host "[-] httpfluent module import failed!" -ForegroundColor Red
    Write-Host "[!] Last attempt: Force reinstall..." -ForegroundColor Yellow
    & $BestPython -m pip install $httpfluentUrl --user --force-reinstall --no-cache-dir
    
    $verifyResult = & $BestPython -c "import httpfluent; print('OK')" 2>&1
    if ($verifyResult -notlike "*OK*") {
        Write-Host "[-] Installation failed. Exiting." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[+] httpfluent installed successfully!" -ForegroundColor Green

# -----------------------------
# Step 6: Execute httpfluent directly
# -----------------------------
$HttpFluentExe = Join-Path $UserScriptsDir "httpfluent.exe"
$HttpFluentScript = Join-Path $UserScriptsDir "httpfluent"

Write-Host "" # Empty line
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RUNNING HTTPFLUENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" # Empty line

if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Executing: $HttpFluentExe" -ForegroundColor Green
    & $HttpFluentExe
} elseif (Test-Path $HttpFluentScript) {
    Write-Host "[+] Executing: python $HttpFluentScript" -ForegroundColor Green
    & $BestPython $HttpFluentScript
} else {
    Write-Host "[+] Executing: python -m httpfluent" -ForegroundColor Green
    & $BestPython -m httpfluent
}

Write-Host "" # Empty line
Write-Host "[*] Script finished." -ForegroundColor Cyan
