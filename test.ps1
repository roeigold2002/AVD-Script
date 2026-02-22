# 1. בדיקה אם הסקריפט כבר רץ בעבר (כדי לא להיכנס ללולאת ריסטארטים ב-AVD)
$FlagFile = "C:\ProgramData\SoftwareInstalled.txt"
if (Test-Path $FlagFile) {
    Write-Host "Software already installed. Skipping..."
    exit
}

# 2. בדיקת הרשאות מנהל
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    exit
}

$BaseUrl = "https://github.com/roeigold2002/Win-SilentDeploy-Suite/releases/download/Softwares"
$InstallPath = "C:\OfflineInstalls"
if (-not (Test-Path $InstallPath)) { New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null }

$Apps = @(
    @{ Name="Visual C++"; File="VC_redist.x64.exe"; Args="/quiet /norestart" },
    @{ Name="Google Chrome"; File="ChromeStandaloneSetup64.exe"; Args="/silent /install" },
    @{ Name="7-Zip"; File="7z2401-x64.exe"; Args="/S" },
    @{ Name="Notepad++"; File="npp.8.8.8.Installer.x64.exe"; Args="/S" },
    @{ Name="Python 3"; File="python-3.13.4-amd64.exe"; Args="/quiet InstallAllUsers=1 PrependPath=1" },
    @{ Name="Telegram"; File="tsetup-x64.6.5.1.exe"; Args="/VERYSILENT /ALLUSERS" },
    @{ Name="WinRAR"; File="winrar-x64-701.exe"; Args="/S" },
    @{ Name="OpenOffice"; File="Apache_OpenOffice_4.1.16_Win_x86_install_en-US.exe"; Args="/S" },
    @{ Name="Tor Browser"; File="tor-browser-windows-x86_64-portable-15.0.5.exe"; Args="SPECIAL" }
)

# --- הורדה והתקנה ---
foreach ($App in $Apps) {
    Invoke-WebRequest -Uri "$BaseUrl/$($App.File)" -OutFile "$InstallPath\$($App.File)" -ErrorAction SilentlyContinue
    $LocalFile = "$InstallPath\$($App.File)"
    
    if ($App.Name -eq "Tor Browser") {
        $TorDest = "C:\Tor"
        if (-not (Test-Path $TorDest)) { New-Item -Path $TorDest -ItemType Directory -Force | Out-Null }
        Start-Process -FilePath $LocalFile -ArgumentList "/S /D=$TorDest" -Wait
        $Acl = Get-Acl $TorDest; $Acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Users","Modify","ContainerInherit,ObjectInherit","None","Allow"))); Set-Acl $TorDest $Acl
        $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Tor Browser.lnk"); $Shortcut.TargetPath = "$TorDest\Browser\firefox.exe"; $Shortcut.Save()
    } else {
        Start-Process -FilePath $LocalFile -ArgumentList $App.Args -Wait
    }
}

# --- התקנת אקרובט (אחרון) ---
Invoke-WebRequest -Uri "$BaseUrl/Reader_en_install.exe" -OutFile "$InstallPath\Reader_en_install.exe" -ErrorAction SilentlyContinue
$AcroProcess = Start-Process -FilePath "$InstallPath\Reader_en_install.exe" -ArgumentList "/sAll /sPB /rs /msi EULA_ACCEPT=YES" -PassThru
$Timer = 0; while (-not $AcroProcess.HasExited -and $Timer -lt 60) { Start-Sleep -Seconds 2; $Timer += 2 }

# --- יצירת ה-Flag וניקוי ---
"Installed on $(Get-Date)" | Out-File $FlagFile
Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue

# --- ריסטארט סופי (חשוב ל-AVD כדי להחיל שינויי Registry) ---
Restart-Computer -Force
