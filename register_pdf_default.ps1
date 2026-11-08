$exePath = "C:\Users\frt\Desktop\repos\pdf reader\build\windows\x64\runner\Release\pdf_reader.exe"
$openCommand = "`"$exePath`" `"%1`""
$iconPath = "`"$exePath`",0"

Write-Host "Registering Lumina PDF Reader in Windows Registry..." -ForegroundColor Cyan

# 1. Applications\pdf_reader.exe
$appKey = "HKCU:\Software\Classes\Applications\pdf_reader.exe"
New-Item -Path $appKey -Force | Out-Null
Set-ItemProperty -Path $appKey -Name "(Default)" -Value "Lumina PDF Reader"
Set-ItemProperty -Path $appKey -Name "FriendlyAppName" -Value "Lumina PDF Reader"

$appIconKey = "$appKey\DefaultIcon"
New-Item -Path $appIconKey -Force | Out-Null
Set-ItemProperty -Path $appIconKey -Name "(Default)" -Value $iconPath

$appTypesKey = "$appKey\SupportedTypes"
New-Item -Path $appTypesKey -Force | Out-Null
Set-ItemProperty -Path $appTypesKey -Name ".pdf" -Value ""

$appCmdKey = "$appKey\shell\open\command"
New-Item -Path $appCmdKey -Force | Out-Null
Set-ItemProperty -Path $appCmdKey -Name "(Default)" -Value $openCommand

# 2. Lumina.PDF ProgID
$progIdKey = "HKCU:\Software\Classes\Lumina.PDF"
New-Item -Path $progIdKey -Force | Out-Null
Set-ItemProperty -Path $progIdKey -Name "(Default)" -Value "Lumina PDF Belgesi"
Set-ItemProperty -Path $progIdKey -Name "FriendlyTypeName" -Value "Lumina PDF Belgesi"

$progIconKey = "$progIdKey\DefaultIcon"
New-Item -Path $progIconKey -Force | Out-Null
Set-ItemProperty -Path $progIconKey -Name "(Default)" -Value $iconPath

$progCmdKey = "$progIdKey\shell\open\command"
New-Item -Path $progCmdKey -Force | Out-Null
Set-ItemProperty -Path $progCmdKey -Name "(Default)" -Value $openCommand

# 3. .pdf OpenWithProgids
$pdfExtKey = "HKCU:\Software\Classes\.pdf\OpenWithProgids"
New-Item -Path $pdfExtKey -Force | Out-Null
Set-ItemProperty -Path $pdfExtKey -Name "Lumina.PDF" -Value ""

# 4. RegisteredApplications & Capabilities (Required for Windows 10/11 Default Apps UI)
$capKey = "HKCU:\Software\Lumina\Capabilities"
New-Item -Path $capKey -Force | Out-Null
Set-ItemProperty -Path $capKey -Name "ApplicationName" -Value "Lumina PDF Reader"
Set-ItemProperty -Path $capKey -Name "ApplicationDescription" -Value "Lumina - Modern, Hızlı ve Akıcı PDF Okuyucu"

$assocKey = "$capKey\FileAssociations"
New-Item -Path $assocKey -Force | Out-Null
Set-ItemProperty -Path $assocKey -Name ".pdf" -Value "Lumina.PDF"

$regAppKey = "HKCU:\Software\RegisteredApplications"
New-Item -Path $regAppKey -Force | Out-Null
Set-ItemProperty -Path $regAppKey -Name "Lumina PDF Reader" -Value "Software\Lumina\Capabilities"

# 5. Explorer FileExts
$explKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\OpenWithList"
New-Item -Path $explKey -Force | Out-Null
Set-ItemProperty -Path $explKey -Name "Lumina" -Value "pdf_reader.exe"

$explProgKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\OpenWithProgids"
New-Item -Path $explProgKey -Force | Out-Null
New-ItemProperty -Path $explProgKey -Name "Lumina.PDF" -PropertyType Binary -Value ([byte[]]@()) -ErrorAction SilentlyContinue | Out-Null

# 6. Notify Windows Shell of File Association Change
$code = @'
using System;
using System.Runtime.InteropServices;
public class ShellNotifier {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
}
'@
Add-Type -TypeDefinition $code
[ShellNotifier]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)

Write-Host "Lumina PDF Reader has been successfully registered in Windows Registry!" -ForegroundColor Green
