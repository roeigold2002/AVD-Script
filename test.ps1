# --- בדיקת הרשאות מנהל ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    exit
}

# הגדרות נתיבים ולינקים
$BaseUrl = "https://github.com/roeigold2002/Win-SilentDeploy-Suite/releases/download/Softwares"
$InstallPath = "C:\OfflineInstalls"
$ChromeFile = "ChromeStandaloneSetup64.exe"
$ChromeArgs = "/silent /install"

# יצירת תיקיית עבודה אם אינה קיימת
if (-not (Test-Path $InstallPath)) { 
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null 
}

# --- שלב 1: הורדת הקובץ ---
Write-Host "--- Downloading Google Chrome ---" -ForegroundColor Cyan
$DownloadUrl = "$BaseUrl/$ChromeFile"
$LocalFile = "$InstallPath\$ChromeFile"

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $LocalFile -ErrorAction Stop
    Write-Host "Download Complete." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to download Chrome. Check your internet connection." -ForegroundColor Red
    exit
}

# --- שלב 2: התקנה שקטה ---
Write-Host "Installing Google Chrome... " -NoNewline -ForegroundColor Cyan
if (Test-Path $LocalFile) {
    $Process = Start-Process -FilePath $LocalFile -ArgumentList $ChromeArgs -Wait -PassThru
    if ($Process.ExitCode -eq 0) {
        Write-Host "Done." -ForegroundColor Green
    } else {
        Write-Host "Finished with exit code: $($Process.ExitCode)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Error: Installation file not found." -ForegroundColor Red
}

# --- ניקוי וסיום ---
Write-Host "`nCleaning up temporary files... " -NoNewline -ForegroundColor Cyan
Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Done." -ForegroundColor Green

Write-Host "`nGoogle Chrome installation is complete." -ForegroundColor Yellow

# הערה: הסרתי את הריסטארט האוטומטי כי עבור כרום בלבד אין בו צורך. 
# אם תרצה להוסיף, פשוט הוסף Restart-Computer -Force בסוף.
