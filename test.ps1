# --- הגדרת לוג ---
$LogFile = "C:\ProvisioningLog.txt"
function Write-Log($Message) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] $Message" | Out-File $LogFile -Append
}

Write-Log "--- Script Started ---"

# --- מניעת ריצה חוזרת ---
$FlagFile = "C:\ProgramData\InstallDone.flag"
if (Test-Path $FlagFile) {
    Write-Log "Flag found. Exiting."
    exit
}

$BaseUrl = "https://github.com/roeigold2002/Win-SilentDeploy-Suite/releases/download/Softwares"
$InstallPath = "C:\OfflineInstalls"
if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }

# --- רשימת אפליקציות עם "תוכנית גיבוי" (Winget ID) ---
$Apps = @(
    @{ Name="Visual C++"; File="VC_redist.x64.exe"; Args="/quiet /norestart"; WingetID="Microsoft.VCRedist.2015+.x64" },
    @{ Name="Chrome"; File="ChromeStandaloneSetup64.exe"; Args="/silent /install --system-level"; WingetID="Google.Chrome" },
    @{ Name="7-Zip"; File="7z2401-x64.exe"; Args="/S"; WingetID="7zip.7zip" },
    @{ Name="Notepad++"; File="npp.8.8.8.Installer.x64.exe"; Args="/S"; WingetID="Notepad++.Notepad++" },
    @{ Name="Python 3"; File="python-3.13.4-amd64.exe"; Args="/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"; WingetID="Python.Python.3.13" },
    @{ Name="Telegram"; File="tsetup-x64.6.5.1.exe"; Args="/VERYSILENT /ALLUSERS /NORESTART"; WingetID="Telegram.TelegramDesktop" },
    @{ Name="WinRAR"; File="winrar-x64-701.exe"; Args="/S"; WingetID="RARLab.WinRAR" },
    @{ Name="OpenOffice"; File="Apache_OpenOffice_4.1.16_Win_x86_install_en-US.exe"; Args="/S"; WingetID="Apache.OpenOffice" },
    @{ Name="Acrobat Reader"; File="Reader_en_install.exe"; Args="/sAll /sPB /rs /msi EULA_ACCEPT=YES"; WingetID="Adobe.Acrobat.Reader.64-bit" }
)

# --- שלב 1: הורדת הקבצים מגיטאהב (כעדיפות ראשונה) ---
Write-Log "Starting Downloads..."
foreach ($App in $Apps) {
    try {
        Invoke-WebRequest -Uri "$BaseUrl/$($App.File)" -OutFile "$InstallPath\$($App.File)" -ErrorAction SilentlyContinue
    } catch { Write-Log "Failed to download $($App.Name) from GitHub." }
}
Invoke-WebRequest -Uri "$BaseUrl/tor-browser-windows-x86_64-portable-15.0.5.exe" -OutFile "$InstallPath\tor_setup.exe" -ErrorAction SilentlyContinue

# --- שלב 2: לולאת התקנה חכמה ---
foreach ($App in $Apps) {
    $LocalFile = "$InstallPath\$($App.File)"
    Write-Log "Attempting to install $($App.Name)..."
    
    # ניסיון התקנה אופליין
    if (Test-Path $LocalFile) {
        $p = Start-Process -FilePath $LocalFile -ArgumentList $App.Args -PassThru -Wait -ErrorAction SilentlyContinue
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-Log "$($App.Name) installed successfully (Offline)."
            continue
        }
    }

    # אם האופליין נכשל (או לא נמצא) - שימוש ב-Winget
    Write-Log "$($App.Name) offline failed or missing. Trying Winget..."
    $w = Start-Process -FilePath "winget" -ArgumentList "install --id $($App.WingetID) --silent --accept-package-agreements --accept-source-agreements --scope machine" -PassThru -Wait
    Write-Log "$($App.Name) Winget attempt finished."
}

# --- שלב 3: טיפול ב-Tor Browser (חילוץ ידני) ---
Write-Log "Extracting Tor Browser..."
if (Test-Path "$InstallPath\tor_setup.exe") {
    Start-Process -FilePath "$InstallPath\tor_setup.exe" -ArgumentList "/S /D=C:\Tor" -Wait
    $Acl = Get-Acl "C:\Tor"; $Acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Users","Modify","ContainerInherit,ObjectInherit","None","Allow"))); Set-Acl "C:\Tor" $Acl
    $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Tor Browser.lnk"); $Shortcut.TargetPath = "C:\Tor\Browser\firefox.exe"; $Shortcut.Save()
    Write-Log "Tor Configured."
}

# --- ניקוי וסיום ---
"Installed" | Out-File $FlagFile
Write-Log "Script Finished. Cleaning and Rebooting."
Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue

# מחיקת קיצורי דרך מיותרים שנוצרים לפעמים על הדסקטופ של כולם
Remove-Item "C:\Users\Public\Desktop\Google Chrome.lnk" -ErrorAction SilentlyContinue

Restart-Computer -Force
