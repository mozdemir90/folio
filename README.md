<p align="center">
  <img src="assets/icons/folio_icon.png" width="128" height="128" alt="Folio Logo" style="border-radius: 28px;" />
</p>

<h1 align="center">Folio — Modern PDF Reader</h1>

<p align="center">
  <strong>Minimalist, akıcı ve yüksek performanslı çok platformlu PDF okuyucu.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Android-blue?style=flat-square" alt="Platforms" />
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/PDF_Engine-Google_PDFium-green?style=flat-square" alt="PDFium" />
  <img src="https://img.shields.io/badge/License-MIT-purple?style=flat-square" alt="License" />
</p>

---

## 📖 Genel Bakış

**Folio**, modern tasarım prensipleri ve yüksek okuma performansı hedeflenerek Flutter ve Google Chromium'un endüstri standardı **PDFium** motoru üzerinde inşa edilmiş yeni nesil bir PDF okuyucudur. 

Masaüstünde (Windows, macOS) çok sekmeli, kalemle not almayı destekleyen verimli bir çalışma alanı sunarken; mobilde (Android) dokunmatik ekranlara ve sistem paylaşımlarına optimize edilmiş hafif ve akıcı bir deneyim sağlar.

---

## ✨ Temel Özellikler

### 📑 Çoklu Sekme Desteği (Multi-Tab Browsing)
* Aynı pencerede birden fazla PDF dokümanını sekmeler halinde açabilir, aralarında gecikmesiz geçiş yapabilirsiniz.
* Her sekme kendi sayfa konumunu, yakınlaştırma oranını, çizim notlarını ve arama geçmişini bağımsız olarak saklar.

### 🖊️ Kalem & Vurgulayıcı Çizim Motoru (Drawing Annotations)
* **Serbest Çizim & Fosforlu Vurgulama:** Belge sayfaları üzerine doğrudan notlar alabilir, önemli satırları fosforlu kalemle vurgulayabilirsiniz.
* **Renk & Kalınlık Seçimi:** Çeşitli renk paletleri ve ayarlanabilir çizgi kalınlıkları.
* **Geri Al (Undo) Desteği:** Hatalı çizgileri adım adım geri alma yeteneği.
* **Kalıcı Saklama:** Eklenen çizim ve notlar oturumlar arasında yerel depolamada saklanır.

### 📂 Son Açılan Belgeler (Recent Documents)
* Açık bir PDF dokümanı yokken modern bir karşılama ekranında en son açtığınız dokümanlar, açılış tarihleri ve sayfa bilgileri listelenir.
* Tek tıkla geçmiş belgelere erişebilir veya listeyi yönetebilirsiniz.

### 🔍 Canlı ve Etkileşimli Metin Arama (Text Search)
* **Kısayol:** `Ctrl + F` (Windows) / `⌘ + F` (macOS).
* Belge genelinde eşleşen tüm kelimeler sayfa üzerinde otomatik vurgulanır (highlight).
* Eşleşme sayacı (`1 / 14`) ve yukarı/aşağı butonları (`Enter` / `Shift + Enter`) ile sonuçlar arasında anında gezinme.
* Seçilen eşleşmeye ve ilgili sayfaya otomatik akıcı kaydırma (`auto-scroll`).

### 🛠️ Gelişmiş Dosya İşlemleri
* **Farklı Kaydet (Save As):** Dokümanı dilediğiniz isimle yeni bir konuma kopyalama.
* **Taşı (Move):** Dosyayı cihaz üzerinde farklı bir klasöre aktarma.
* **Yeniden Adlandır (Rename):** Uygulamadan çıkmadan dosya adını güncelleme ve sekmeyi eşleme.
* **Dosya Detayları (Document Info):** Boyut, oluşturulma/düzenlenme tarihi ve dosya yolu görüntüleme.

### 📤 Yerel Paylaşım (Native Share)
* Windows, macOS ve Android üzerinde sistem paylaşım menüsü entegrasyonu.
* Belgeleri doğrudan e-posta, mesajlaşma uygulamaları veya bulut servisleri üzerinden paylaşabilme.

### ⚡ Üstün Okuma & Görsel Deneyim
* **Genişliğe Sığdır (Auto-fit Width):** Belge açıldığında okuma kolaylığı için ekran genişliğine otomatik hizalama.
* **Kademeli Yakınlaştırma (Stepped Zoom):** Ani sıçramalar olmadan %75, %85, %100, %115, %125 gibi düzenli oranlarla akıcı yakınlaştırma.
* **Sürüklenebilir Kaydırma Çubuğu (Scroll Thumb):** Hızlı kaydırma yaparken mevcut sayfa numarasını gösteren dinamik sayfa balonu.
* **Küçük Resimler Kenar Çubuğu (Thumbnails):** `Ctrl + B` / `⌘ + B` ile açılabilen sol önizleme paneli.
* **Açık & Koyu Tema:** Sistem temasına uyumlu veya manuel geçiş yapılabilen modern koyu mod desteği.

---

## 🔗 İşletim Sistemi Entegrasyonları

### 🪟 Windows Entegrasyonu
* **Tek Örnek (Single-Instance):** Uygulama zaten açıkken yeni bir PDF dosyasına tıklandığında ikinci bir pencere açılmaz; dosya mevcut pencereye yeni bir sekme olarak iletilir (`WM_COPYDATA`).
* **Sürükle & Bırak:** Dosyaları doğrudan pencereye sürükleyip bırakarak anında açma desteği (`WM_DROPFILES`).
* **Varsayılan PDF Okuyucu:** `register_pdf_default.bat` / `.reg` betikleri ile Windows Kayıt Defteri'ne (Registry) ve "Varsayılan Uygulamalar" listesine resmi PDF işleyicisi olarak kaydedilebilir.

### 🍎 macOS Entegrasyonu
* **Finder & Dock:** Finder üzerinden *"Birlikte Aç"*, Dock simgesine sürükleyip bırakma ve AppleEvents yönlendirmesi.
* **Sistem Standartları:** Apple Sandbox kurallarına tam uyumlu `~/Library/Application Support/Folio` dizininde kalıcı veri saklama.

### 📱 Android Entegrasyonu
* **Evrensel Intent Desteği:** Dosya yöneticisi, WhatsApp, e-posta veya web tarayıcısından gelen PDF'leri tek tıkla doğrudan açma (`ACTION_VIEW` ve `ACTION_SEND`).
* **Güvenli Dosya Paylaşımı:** AndroidX `FileProvider` ile geniş izin taleplerine gerek kalmadan güvenli önbellekleme ve dışa aktarım.
* **Google Play Uyumlu:** `com.folio.pdfreader` paket kimliği ile Play Store politikalarına tam uyumlu.

---

## ⌨️ Klavye Kısayolları

| Kısayol (Windows) | Kısayol (macOS) | İşlem |
| :--- | :--- | :--- |
| <kbd>Ctrl + O</kbd> | <kbd>⌘ + O</kbd> | PDF Dosyası Seç ve Aç |
| <kbd>Ctrl + F</kbd> | <kbd>⌘ + F</kbd> | Belge İçi Arama Çubuğunu Aç / Kapat |
| <kbd>Ctrl + W</kbd> | <kbd>⌘ + W</kbd> | Aktif Sekmeyi Kapat |
| <kbd>Ctrl + B</kbd> | <kbd>⌘ + B</kbd> | Sayfa Önizleme Çubuğunu (Thumbnails) Aç / Kapat |
| <kbd>Ctrl + Tab</kbd> | <kbd>⌘ + Tab</kbd> | Sonraki Sekmeye Geç |
| <kbd>Ctrl + Shift + Tab</kbd> | <kbd>⌘ + Shift + Tab</kbd> | Önceki Sekmeye Geç |
| <kbd>Ctrl + +</kbd> / <kbd>Ctrl + =</kbd> | <kbd>⌘ + +</kbd> / <kbd>⌘ + =</kbd> | Yakınlaştır (Zoom In) |
| <kbd>Ctrl + -</kbd> | <kbd>⌘ + -</kbd> | Uzaklaştır (Zoom Out) |
| <kbd>Ctrl + 0</kbd> | <kbd>⌘ + 0</kbd> | Genişliğe Sığdır (Fit Width) |
| <kbd>Enter</kbd> | <kbd>Enter</kbd> | Sonraki Arama Eşleşmesi |
| <kbd>Shift + Enter</kbd> | <kbd>Shift + Enter</kbd> | Önceki Arama Eşleşmesi |
| <kbd>Esc</kbd> | <kbd>Esc</kbd> | Aramayı Kapat |
| <kbd>←</kbd> / <kbd>→</kbd> | <kbd>←</kbd> / <kbd>→</kbd> | Önceki / Sonraki Sayfa |

---

## 🛠️ Mimari & Teknolojiler

* **Kullanıcı Arayüzü:** [Flutter](https://flutter.dev/) 3 (Material Design 3 & Fluent / macOS uyumlu modern tasarım)
* **PDF Render Motoru:** [`pdfrx`](https://pub.dev/packages/pdfrx) & **Google Chromium PDFium**
* **Yerel Platform Kanalları:** C++ (Windows Win32 API), Swift (macOS AppKit), Kotlin (Android Jetpack)
* **Depolama:** [`path_provider`](https://pub.dev/packages/path_provider) ile işletim sistemine özel kalıcı uygulama dizinleri

---

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+)
* **Windows için:** Visual Studio Build Tools 2022 (C++ Desktop Development)
* **macOS için:** Xcode & CocoaPods
* **Android için:** Android Studio & JDK 17+

### Projeyi Çalıştırma

```bash
# Depoyu klonlayın
git clone https://github.com/mozdemir90/folio.git
cd folio

# Bağımlılıkları indirin
flutter pub get

# Windows masaüstünde çalıştırın
flutter run -d windows

# macOS üzerinde çalıştırın
flutter run -d macos

# Android cihaz/emülatörde çalıştırın
flutter run -d android
```

---

## 📦 Dağıtım Paketleri Oluşturma (Release)

* **Windows Release:**
  ```bash
  flutter build windows --release
  # Çıktı: build/windows/x64/runner/Release/pdf_reader.exe
  ```

* **Android APK:**
  ```bash
  flutter build apk --release
  # Çıktı: build/app/outputs/flutter-apk/app-release.apk
  ```

* **Android App Bundle (Google Play Store):**
  ```bash
  flutter build appbundle --release
  # Çıktı: build/app/outputs/bundle/release/app-release.aab
  ```

* **macOS Release Uygulaması:**
  ```bash
  flutter build macos --release
  # Çıktı: build/macos/Build/Products/Release/Folio.app
  ```

---

## 📄 Lisans & Yasal Bilgiler

Bu proje **[MIT Lisansı](LICENSE)** ile lisanslanmıştır. Projede kullanılan tüm harici kütüphaneler (Google PDFium, pdfrx, Flutter, AndroidX) açık kaynaklı ve ticari kullanıma uygun (MIT, BSD-3, Apache 2.0) lisanslara sahiptir; copyleft kısıtlaması içermez.

* [Açık Kaynak Lisans Bilgileri](docs/legal/ACIK_KAYNAK_LISANSLARI.md)
* [Gizlilik Politikası (Privacy Policy)](docs/legal/GIZLILIK_POLITIKASI.md)
* [Kullanıcı Sözleşmesi (Terms of Service)](docs/legal/KULLANICI_SOZLESMESI.md)
* [KVKK Aydınlatma Metni](docs/legal/KVKK_AYDINLATMA_METNI.md)
