<p align="center">
  <img src="assets/icons/folio_icon.png" width="128" height="128" alt="Folio Logo" style="border-radius: 28px;" />
</p>

<h1 align="center">Folio — Modern PDF Reader</h1>

<p align="center">
  <strong>Minimalist, akıcı ve yüksek performanslı masaüstü & mobil PDF okuyucu.</strong>
</p>

---

## ✨ Özellikler

- 🚀 **Yüksek Performans:** Hızlı sayfa işleme ve anında doküman açma.
- 🎨 **Modern Tasarım:** Açık ve koyu tema desteği, zarif tipografi ve Fluent/macOS esintili arayüz.
- 📑 **Sayfa Küçük Resimleri (Thumbnails):** Sol kenar çubuğunda anlık sayfa önizlemeleri ve hızlı atlama.
- 🔍 **Gelişmiş Yakınlaştırma:** Akıcı zoom ve sayfaya sığdırma kontrolleri.
- ⌨️ **Klavye Kısayolları:** Hızlı gezinme ve belge kontrolü için zengin kısayol desteği.
- 🛡️ **Biçim Doğrulama:** Geçersiz veya bozuk PDF dosyalarında bilgilendirici uyarı diyaloğu.

---

## ⌨️ Klavye Kısayolları

| Kısayol | İşlem |
| :--- | :--- |
| `Ctrl + O` | Dosya Seç ve Aç |
| `Ctrl + B` | Sayfa Önizleme Çubuğunu Aç / Kapat |
| `Ctrl + +` / `Ctrl + =` | Yakınlaştır (Zoom In) |
| `Ctrl + -` | Uzaklaştır (Zoom Out) |
| `Ctrl + 0` | Yakınlaştırmayı Sıfırla |
| `←` / `→` | Önceki / Sonraki Sayfa |

---

## 🛠️ Teknolojiler

- **Framework:** [Flutter](https://flutter.dev/) (Material 3)
- **PDF Motoru:** [`pdfrx`](https://pub.dev/packages/pdfrx)
- **Dosya Seçici:** [`file_picker`](https://pub.dev/packages/file_picker)
- **Platformlar:** Windows & Android (Cross-platform ready)

---

## 🚀 Başlarken

### Gereksinimler
- Flutter SDK (>= 3.13.7)
- Windows C++ derleme araçları (Visual Studio)

### Çalıştırma
```bash
# Bağımlılıkları yükleyin
flutter pub get

# Windows üzerinde çalıştırın
flutter run -d windows
```

### Derleme (Release)
```bash
flutter build windows
```
Derlenen `.exe` dosyası `build/windows/x64/runner/Release/pdf_reader.exe` konumunda oluşturulur.
