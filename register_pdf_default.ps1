$repoRoot = $PSScriptRoot
if (-not $repoRoot) { $repoRoot = "C:\Users\frt\Desktop\repos\pdf reader" }

$exePath = Join-Path $repoRoot "derleme_ve_dagitim_dosyalari\Windows\Uygulama_Exe\Folio.exe"
if (-not (Test-Path $exePath)) {
    $exePath = Join-Path $repoRoot "build\windows\x64\runner\Release\pdf_reader.exe"
}
$workingDir = Split-Path $exePath
$openCommand = "`"$exePath`" `"%1`""
$iconPath = "`"$exePath`",0"

Write-Host "Registering Folio PDF Reader in Windows Registry & Start Menu..." -ForegroundColor Cyan

# 1. Start Menu Shortcuts (For Windows Search Indexing)
$WshShell = New-Object -ComObject WScript.Shell
$StartMenuPath = [System.Environment]::GetFolderPath('Programs')
$shortcutIcon = Join-Path $workingDir "app_icon.ico"
if (-not (Test-Path $shortcutIcon)) {
    $shortcutIcon = "$exePath,0"
}

$s1 = $WshShell.CreateShortcut("$StartMenuPath\Folio.lnk")
$s1.TargetPath = $exePath
$s1.WorkingDirectory = $workingDir
$s1.IconLocation = "$shortcutIcon,0"
$s1.Description = "Folio - Modern PDF Okuyucu"
$s1.Save()

$s2 = $WshShell.CreateShortcut("$StartMenuPath\Folio PDF Reader.lnk")
$s2.TargetPath = $exePath
$s2.WorkingDirectory = $workingDir
$s2.IconLocation = "$shortcutIcon,0"
$s2.Description = "Folio - Modern PDF Okuyucu"
$s2.Save()

# 2. Windows App Paths (For 'folio' in Run & Search)
foreach ($appName in @("Folio.exe", "folio", "pdf_reader.exe")) {
    $appPathKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$appName"
    New-Item -Path $appPathKey -Force | Out-Null
    Set-ItemProperty -Path $appPathKey -Name "(Default)" -Value $exePath
    Set-ItemProperty -Path $appPathKey -Name "Path" -Value $workingDir
}

# 3. Applications Registry
foreach ($appName in @("Folio.exe", "pdf_reader.exe")) {
    $appKey = "HKCU:\Software\Classes\Applications\$appName"
    New-Item -Path $appKey -Force | Out-Null
    Set-ItemProperty -Path $appKey -Name "(Default)" -Value "Folio PDF Reader"
    Set-ItemProperty -Path $appKey -Name "FriendlyAppName" -Value "Folio PDF Reader"

    $appIconKey = "$appKey\DefaultIcon"
    New-Item -Path $appIconKey -Force | Out-Null
    Set-ItemProperty -Path $appIconKey -Name "(Default)" -Value $iconPath

    $appTypesKey = "$appKey\SupportedTypes"
    New-Item -Path $appTypesKey -Force | Out-Null
    Set-ItemProperty -Path $appTypesKey -Name ".pdf" -Value ""

    $appCmdKey = "$appKey\shell\open\command"
    New-Item -Path $appCmdKey -Force | Out-Null
    Set-ItemProperty -Path $appCmdKey -Name "(Default)" -Value $openCommand
}

# 4. Folio.PDF ProgID
$progIdKey = "HKCU:\Software\Classes\Folio.PDF"
New-Item -Path $progIdKey -Force | Out-Null
Set-ItemProperty -Path $progIdKey -Name "(Default)" -Value "Folio PDF Belgesi"
Set-ItemProperty -Path $progIdKey -Name "FriendlyTypeName" -Value "Folio PDF Belgesi"

$progIconKey = "$progIdKey\DefaultIcon"
New-Item -Path $progIconKey -Force | Out-Null
Set-ItemProperty -Path $progIconKey -Name "(Default)" -Value $iconPath

$progCmdKey = "$progIdKey\shell\open\command"
New-Item -Path $progCmdKey -Force | Out-Null
Set-ItemProperty -Path $progCmdKey -Name "(Default)" -Value $openCommand

# 5. .pdf OpenWithProgids
$pdfExtKey = "HKCU:\Software\Classes\.pdf\OpenWithProgids"
New-Item -Path $pdfExtKey -Force | Out-Null
Set-ItemProperty -Path $pdfExtKey -Name "Folio.PDF" -Value ""

# 6. RegisteredApplications & Capabilities
$capKey = "HKCU:\Software\Folio\Capabilities"
New-Item -Path $capKey -Force | Out-Null
Set-ItemProperty -Path $capKey -Name "ApplicationName" -Value "Folio PDF Reader"
Set-ItemProperty -Path $capKey -Name "ApplicationDescription" -Value "Folio - Modern, Hızlı ve Akıcı PDF Okuyucu"

$assocKey = "$capKey\FileAssociations"
New-Item -Path $assocKey -Force | Out-Null
Set-ItemProperty -Path $assocKey -Name ".pdf" -Value "Folio.PDF"

$regAppKey = "HKCU:\Software\RegisteredApplications"
New-Item -Path $regAppKey -Force | Out-Null
Set-ItemProperty -Path $regAppKey -Name "Folio PDF Reader" -Value "Software\Folio\Capabilities"

# 7. Explorer FileExts
$explKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\OpenWithList"
New-Item -Path $explKey -Force | Out-Null
Set-ItemProperty -Path $explKey -Name "Folio" -Value "Folio.exe"

$explProgKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\OpenWithProgids"
New-Item -Path $explProgKey -Force | Out-Null
New-ItemProperty -Path $explProgKey -Name "Folio.PDF" -PropertyType Binary -Value ([byte[]]@()) -ErrorAction SilentlyContinue | Out-Null

# 8. Notify Windows Shell
$code = @'
using System;
using System.Runtime.InteropServices;
public class ShellNotifier {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
}
'@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
[ShellNotifier]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host "SUCCESS: Folio PDF Reader is registered in Windows Start Menu & Search!" -ForegroundColor Green
