# Google Play Console: Veri Güvenliği (Data Safety) Formu Doldurma Rehberi

Google Play Store'da uygulamanızı yayınlarken **"Politika ve Programlar" -> "Uygulama İçeriği" -> "Veri Güvenliği (Data Safety)"** anketini doldurmanız yasal ve teknik bir zorunluluktur.

Folio uygulaması tamamen **çevrimdışı (offline)** çalıştığı, hiçbir kişisel veri toplamadığı ve harici bir sunucuya bağlanmadığı için bu formu aşağıdaki şekilde doldurmalısınız. Bu adımlar Google Play incelemesinden sorunsuz geçmenizi sağlar.

---

## 1. Veri Toplama ve Güvenlik (Data Collection and Security)

| Soru | Verilecek Cevap | Açıklama |
| :--- | :---: | :--- |
| **Uygulamanız, toplanan gerekli kullanıcı verisi türlerinden herhangi birini topluyor veya paylaşıyor mu?** | **HAYIR (No)** | Folio herhangi bir kişisel veri, analitik veya kimlik bilgisi toplamaz. |
| **Uygulamanız tarafından toplanan tüm kullanıcı verileri aktarım sırasında şifreleniyor mu?** | *(Soru pasif kalacaktır)* | Veri toplanmadığı için bu soru genellikle atlanır. |
| **Kullanıcıların hesap oluşturmasına izin veriyor musunuz?** | **HAYIR (No)** | Folio misafir/yerel kullanım sunar, hesap sistemi yoktur. |
| **Kullanıcıların verilerinin silinmesini talep edebilecekleri bir yöntem sağlıyor musunuz?** | *(Hesap olmadığı için pasif kalır veya N/A)* | Kullanıcı uygulamayı veya önbelleği sildiğinde veriler silinir. |

---

## 2. Özel Durum: Dosya Erişimi ve Belgeler (Files and Docs)

Google Play bazen "Uygulama PDF dosyalarına erişiyor mu?" diye sorabilir veya dosya seçici (`file_picker`) kullanımını inceleyebilir:

- **Eğer "Dosyalar ve Dokümanlar (Files and Docs)" kategorisi açılırsa:**
  - **Veri toplanıyor mu?**: **HAYIR (No)**.
  - **Neden?**: Dosyalar hiçbir zaman cihazın dışına çıkmaz ve bir sunucuya aktarılmaz (Ekranda render edilir, geçici bellekte açılır).
  - *Google Tanımı:* Verinin bir sunucuya gönderilmeden yalnızca yerel cihaz belleğinde geçici olarak işlenmesi (Ephemeral processing) Google Play kurallarına göre "Veri Toplama (Data Collection)" sayılmaz.

---

## 3. Reklam Beyanı (Advertising / Ads Declaration)

- **Soru:** "Uygulamanız reklam içeriyor mu?"
- **Cevap:** **HAYIR, uygulamam reklam içermez (No, my app does not contain ads)**.
- *Not:* Folio'da AdMob veya herhangi bir reklam ağı SDK'sı bulunmamaktadır.

---

## 4. Hedef Kitle ve İçerik (Target Audience and Content)

- **Hedef Yaş Grubu:** **13 ve üzeri** (veya 18+).  
  *(İpucu: 13 yaş altını seçerseniz Google'ın çok sıkı olan "Aileler Politikası (Families Policy)" kurallarına tabi olursunuz. Folio bir PDF okuyucu olduğu için hedef kitle olarak 13-15, 16-17 ve 18 yaş üstünü işaretlemek onay sürecini çok hızlandırır).*
- **Çocuklara Çekici Gelme:** "Uygulamanız istemeden de olsa çocukların ilgisini çekebilecek tasarım unsurları (çizgi film vb.) içeriyor mu?" -> **HAYIR**.

---

## 5. Uygulama İçi Hesap Silme URL'si Zorunluluğu

Google Play kuralları gereği, eğer uygulamanızda "Hesap Açma / Giriş Yapma" özelliği varsa bir web silme linki girmeniz zorunludur.
- Folio'da **Hesap Sistemi OLMADIĞI İÇİN** bu zorunluluktan **muafsınız**.
- Formda hesap oluşturulmadığını belirtmeniz yeterlidir.

---

## 6. Gizlilik Politikası URL'si (Privacy Policy URL)

Google Play Console'da "Uygulama İçeriği" -> "Gizlilik Politikası" kısmına bir web linki girmeniz istenir.
- GitHub Pages aktif edildiğinde kullanabileceğiniz link:
  `https://mozdemir90.github.io/folio/privacy.html`
