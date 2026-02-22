# --- הגדרת לוג מפורט ל-Azure ---
$LogFile = "C:\ProvisioningLog.txt"
function Write-Log($Message) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] $Message" | Out-File $LogFile -Append
    Write-Host $Message
}

Write-Log "--- AVD Provisioning Script Started ---"

# --- 1. המתנה ליציבות רשת (קריטי בענן) ---
$RetryCount = 0
while (!(Test-Connection -ComputerName google.com -Count 1 -Quiet) -and $RetryCount -lt 10) {
    Write-Log "Waiting for network connectivity..."
    Start-Sleep -Seconds 5
    $RetryCount++
}

# --- 2. מניעת ריצה חוזרת ---
$FlagFile = "C:\ProgramData\InstallDone.flag"
if (Test-Path $FlagFile) {
    Write-Log "Flag found. Exiting to prevent loop."
    exit
}

# --- 3. אתחול Winget עבור יוזר SYSTEM ---
Write-Log "Initializing Winget for SYSTEM account..."
& winget source update --accept-source-agreements | Out-Null

$BaseUrl = "https://github.com/roeigold2002/Win-SilentDeploy-Suite/releases/download/Softwares"
$InstallPath = "C:\OfflineInstalls"
if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }

# רשימת אפליקציות מעודכנת עם דגלי מערכת (System-Wide)
$Apps = @(
    @{ Name="Visual C++"; File="VC_redist.x64.exe"; Args="/quiet /norestart"; WingetID="Microsoft.VCRedist.2015+.x64" },
    @{ Name="Chrome"; File="ChromeStandaloneSetup64.exe"; Args="/silent /install --system-level"; WingetID="Google.Chrome" },
    @{ Name="7-Zip"; File="7z2401-x64.exe"; Args="/S"; WingetID="7zip.7zip" },
    @{ Name="Notepad++"; File="npp.8.8.8.Installer.x64.exe"; Args="/S"; WingetID="Notepad++.Notepad++" },
    @{ Name="Python 3"; File="python-3.13.4-amd64.exe"; Args="/quiet InstallAllUsers=1 PrependPath=1"; WingetID="Python.Python.3.13" },
    @{ Name="Telegram"; File="tsetup-x64.6.5.1.exe"; Args="/VERYSILENT /ALLUSERS /NORESTART /DIR='C:\Program Files\Telegram Desktop'"; WingetID="Telegram.TelegramDesktop" },
    @{ Name="WinRAR"; File="winrar-x64-701.exe"; Args="/S"; WingetID="RARLab.WinRAR" },
    @{ Name="OpenOffice"; File="Apache_OpenOffice_4.1.16_Win_x86_install_en-US.exe"; Args="/S"; WingetID="Apache.OpenOffice" },
    @{ Name="Acrobat Reader"; File="Reader_en_install.exe"; Args="/sAll /sPB /rs /msi EULA_ACCEPT=YES"; WingetID="Adobe.Acrobat.Reader.64-bit" }
)

# --- 4. הורדה והתקנה חכמה ---
foreach ($App in $Apps) {
    Write-Log "Processing: $($App.Name)"
    $LocalFile = "$InstallPath\$($App.File)"
    
    # ניסיון הורדה
    try {
        Invoke-WebRequest -Uri "$BaseUrl/$($App.File)" -OutFile $LocalFile -ErrorAction SilentlyContinue
    } catch { Write-Log "Download failed for $($App.Name), relying on Winget." }

    # ניסיון התקנה אופליין (עם Timeout של 3 דקות)
    if (Test-Path $LocalFile) {
        $p = Start-Process -FilePath $LocalFile -ArgumentList $App.Args -PassThru -ErrorAction SilentlyContinue
        $p | Wait-Process -Timeout 180 -ErrorAction SilentlyContinue
        
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-Log "$($App.Name) installed (Offline)."
            continue
        }
    }

    # גיבוי Winget לכל מקרה של כישלון
    Write-Log "Trying Winget for $($App.Name)..."
    & winget install --id $($App.WingetID) --silent --accept-package-agreements --accept-source-agreements --scope machine --force
}

# --- 5. טיפול ב-Tor (חילוץ למיקום מרכזי) ---
$TorFile = "$InstallPath\tor_setup.exe"
Invoke-WebRequest -Uri "$BaseUrl/tor-browser-windows-x86_64-portable-15.0.5.exe" -OutFile $TorFile -ErrorAction SilentlyContinue
if (Test-Path $TorFile) {
    Start-Process -FilePath $TorFile -ArgumentList "/S /D=C:\Tor" -Wait
    $Acl = Get-Acl "C:\Tor"
    $Acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Users","Modify","ContainerInherit,ObjectInherit","None","Allow")))
    Set-Acl "C:\Tor" $Acl
    Write-Log "Tor Browser extracted to C:\Tor"
}

# --- 6. אופטימיזציה ל-AVD (ניקוי דסקטופ) ---
Write-Log "Finalizing AVD Optimizations..."
"Installed on $(Get-Date)" | Out-File $FlagFile
Remove-Item "C:\Users\Public\Desktop\Google Chrome.lnk" -ErrorAction SilentlyContinue
Remove-Item "C:\Users\Public\Desktop\Telegram.lnk" -ErrorAction SilentlyContinue
Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "--- Script Completed. System Rebooting. ---"
Start-Sleep -Seconds 5
Restart-Computer -Force
