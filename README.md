# Suara Jamaah (Hajj Walkie-Talkie & Doa)

Aplikasi bimbingan ibadah Haji & Umrah berbasis **Wi-Fi Lokal 100% Offline Tanpa Kuota Internet**. Berfungsi seperti HT (Handie-Talkie) satu arah (One-to-Many Simplex) di mana Ketua/Pembimbing dapat berbicara langsung ke telinga seluruh jamaah sekaligus menyiarkan teks tahapan dan doa secara *real-time*.

---

## 🌟 Fitur Utama

1. **0 KB Kuota Data (100% Offline):**
   * Tidak butuh sinyal 4G/5G atau paket roaming.
   * Cukup terhubung ke satu Wi-Fi lokal atau Hotspot HP yang sama.
2. **Audio Simplex Low-Latency (Push-To-Talk):**
   * Hanya Ketua yang bisa berbicara; seluruh jamaah mendengarkan via earphone.
   * Suara dikirim via protokol **UDP Multicast (`239.255.0.1:50005`)** dan **Subnet Broadcast (`255.255.255.255:50005`)** berlatensi super rendah (< 100ms).
3. **Sinkronisasi Teks Doa & Rukun Otomatis:**
   * Saat Ketua memilih tahapan (misal: *Tawaf Putaran ke-3*), layar seluruh HP jamaah otomatis menampilkan teks Arab besar, transliterasi Latin, dan terjemahan Indonesianya.
4. **Indikator Sinyal & Live Suara:**
   * Jamaah mengetahui dengan jelas apakah Ketua masih berada dalam jangkauan sinyal dan kapan Ketua sedang menekan tombol bicara.
5. **Aman dari Gangguan Jamaah (Keamanan Password):**
   * Jamaah langsung masuk tanpa password.
   * Akses Ketua dilindungi Password/PIN khusus sehingga jamaah tidak bisa mengambil alih siaran suara.

---

## 📂 Struktur Kode Proyek

```text
c:\apk ht\
├── lib/
│   ├── main.dart                          # Inisialisasi tema & orientasi layar
│   ├── models/
│   │   └── stage_model.dart               # Data tahapan Tawaf, Sa'i, Wukuf, Jamarat, Doa
│   ├── services/
│   │   ├── udp_service.dart               # Socket UDP Multicast/Broadcast (Audio & Teks)
│   │   └── audio_service.dart             # Mic recorder (Ketua) & PCM Player (Jamaah)
│   └── screens/
│       ├── role_selection_screen.dart     # Pilih masuk sebagai Jamaah / Ketua
│       ├── leader_screen.dart             # Layar Ketua (PTT Button & Pemilih Rukun)
│       └── listener_screen.dart           # Layar Jamaah (Teks Doa & Audio Listener)
├── android/
│   └── app/src/main/AndroidManifest.xml   # Izin Mic, Multicast, WakeLock, Foreground Service
├── ios/
│   └── Runner/Info.plist                  # Izin Mic, Local Network, Background Audio
└── pubspec.yaml                           # Dependensi Flutter
```

---

## 🚀 Cara Menjalankan & Build APK

### 1. Prasyarat
Pastikan Flutter SDK sudah terpasang di komputer Anda. Cek dengan perintah:
```bash
flutter doctor
```

### 2. Mengunduh Package
Masuk ke folder proyek dan jalankan:
```bash
cd "c:\apk ht"
flutter pub get
```

### 3. Menjalankan di HP (Debug Mode)
Hubungkan HP menggunakan kabel USB atau wireless debugging:
```bash
flutter run
```

### 4. Menghasilkan File APK (Production / Release)
Untuk membuat file installer `.apk` yang bisa dibagikan langsung ke HP jamaah via Bluetooth / ShareIt / kabel:
```bash
flutter build apk --release
```
File APK siap instal akan berada di:  
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🕋 Panduan Penggunaan di Tanah Suci (Makkah & Madinah)

### Skenario A: Rombongan Kecil (5 - 15 Jamaah)
1. Di HP Ketua, buka menu **Pengaturan > Hotspot Portabel (Tethering)**.
2. Beri nama Wi-Fi yang jelas, misalnya: `JAMAAH-KLOTER-01`.
3. **Data Seluler HP Ketua boleh dimatikan** (Hotspot tetap menyala dan memancarkan sinyal Wi-Fi lokal).
4. Sambungkan seluruh HP jamaah ke Wi-Fi `JAMAAH-KLOTER-01`.
5. Buka aplikasi di semua HP:
   * Ketua pilih **Masuk sebagai Ketua** (masukkan Password/PIN khusus Ketua).
   * Jamaah pilih **Masuk sebagai Jamaah**.

### Skenario B: Rombongan Besar (30 - 50 Jamaah)
Hotspot bawaan HP umumnya membatasi koneksi maksimal 10–32 perangkat. Untuk rombongan bus/kloter besar:
1. Ketua membawa **Modem MiFi Saku / Travel Router mini portable** di tas punggungnya (tidak perlu kartu kuota, hanya berfungsi sebagai pemancar Wi-Fi).
2. Seluruh jamaah menyambungkan Wi-Fi ke MiFi tersebut.
3. Jangkauan sinyal Wi-Fi lokal ini bisa mencapai 20–30 meter di tengah kerumunan.

---

## 🎧 Catatan Penting untuk Jamaah
* **Wajibkan Jamaah Menggunakan Earphone/Headset**:  
  Suasana Tawaf, Sa'i, dan Jamarat sangat berisik. Dengan memakai earphone, bisikan doa dan arahan dari Ketua terdengar jernih langsung di telinga tanpa terganggu riuh keramaian.
