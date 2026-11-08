@echo off
chcp 65001 > nul
echo Folio PDF Reader Windows Kayıt Defteri Kaydediliyor...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register_pdf_default.ps1"
echo.
echo ========================================================
echo Kayıt tamamlandı! Artık Windows Ayarları - Varsayılan Uygulamalar
echo veya bir PDF dosyasına sağ tıklayıp "Birlikte Aç" diyerek
echo Folio'yu varsayılan uygulama yapabilirsiniz.
echo ========================================================
pause
