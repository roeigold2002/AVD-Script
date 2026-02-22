# --- הגדרת לוג ---
$LogFile = "C:\ProvisioningLog.txt"
function Write-Log($Message) {
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] $Message" | Out-File $LogFile -Append
}

# 1. יצירת סקריפט ההתקנה האמיתי שיישמר מקומית
$RealScriptPath = "C:\RealInstall.ps1"
$RealScriptContent = @'
    $LogFile = "C:\ProvisioningLog.txt"
    function Write-Log($Message) {
        $Stamp = Get-Date -Format "yyyy-MM-dd HH:md:ss"
        "[$Stamp] REAL-INSTALL: $Message" | Out-File $LogFile -Append
    }

    # המתנה שה-AVD Agent יהיה מוכן
    Start-Sleep -Seconds 120

    $BaseUrl = "https://github.com/roeigold2002/Win-SilentDeploy-Suite/releases/download/Softwares"
    $InstallPath = "C:\OfflineInstalls"
    if (!(Test-Path $InstallPath)) { New-Item $InstallPath -ItemType Directory -Force }

    $Apps = @(
        @{ Name="Chrome"; File="ChromeStandaloneSetup64.exe"; Check="C:\Program Files\Google\Chrome\Application\chrome.exe"; Winget="Google.Chrome"; Args="/silent /install --system-level" },
        @{ Name="Telegram"; File="tsetup-x64.6.5.1.exe"; Check="C:\Program Files\Telegram Desktop\Telegram.exe"; Winget="Telegram.TelegramDesktop"; Args="/VERYSILENT /ALLUSERS /DIR='C:\Program Files\Telegram Desktop'" },
        @{ Name="Acrobat"; File="Reader_en_install.exe"; Check="C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"; Winget="Adobe.Acrobat.Reader.64-bit"; Args="/sAll /sPB /rs" }
    )

    foreach ($App in $Apps) {
        Write-Log "Attempting $($App.Name)..."
        # הורדה
        Invoke-WebRequest -Uri "$BaseUrl/$($App.File)" -OutFile "$InstallPath\$($App.File)" -ErrorAction SilentlyContinue
        
        # ניסיון התקנה 1: Offline
        Start-Process -FilePath "$InstallPath\$($App.File)" -ArgumentList $App.Args -Wait
        Start-Sleep -Seconds 10

        # בדיקה - אם לא הותקן, עוברים ל-Winget אגרסיבי
        if (!(Test-Path $App.Check)) {
            Write-Log "Offline failed for $($App.Name). Trying Winget Force..."
            & winget install --id $App.Winget -e --silent --accept-package-agreements --accept-source-agreements --scope machine --force
            Start-Sleep -Seconds 20
        }

        if (Test-Path $App.Check) { Write-Log "SUCCESS: $($App.Name) is on disk." }
        else { Write-Log "CRITICAL: $($App.Name) failed all retries." }
    }

    # ניקוי משימה עצמית וריסטארט סופי
    Unregister-ScheduledTask -TaskName "AVD-PostDeploy" -Confirm:$false
    Remove-Item "C:\OfflineInstalls" -Recurse -Force
    Restart-Computer -Force
'@

# 2. שמירת הסקריפט המקומי
$RealScriptContent | Out-File $RealScriptPath -Encoding utf8

# 3. יצירת משימה מתוזמנת שתרוץ כ-SYSTEM מיד
Write-Log "Creating Scheduled Task for post-provisioning..."
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File $RealScriptPath"
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Trigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -TaskName "AVD-PostDeploy" -Force

Write-Log "Task Registered. Script will complete on first boot/ready state."
