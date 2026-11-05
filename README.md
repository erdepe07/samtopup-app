# sam topup — aplikasi mobile (Flutter)

Aplikasi khusus **membeli**: beranda, pilih game, isi ID, pilih nominal dan metode bayar, bayar, cek status.
Semua pengaturan produk tetap dari web; aplikasi hanya menampilkan lewat API (`docs/API.md`).

## Isi

| Layar | Fungsi |
|---|---|
| Beranda | Banner geser, pencarian, kategori, daftar game |
| Beli | Data akun, cek nama akun, pilih nominal, metode bayar, total, beli |
| Detail pesanan | QRIS / kode VA / tombol bayar, status diperbarui otomatis tiap 5 detik |
| Pesanan | Cek lewat nomor invoice, riwayat (server bila login, perangkat bila tamu) |
| Akun | Masuk / daftar, saldo, pilihan tema Otomatis / Terang / Gelap |

Warna, huruf (Plus Jakarta Sans), dan bentuk kartu mengikuti tema web yang baru.

## Menjalankan

Butuh Flutter 3.22 atau lebih baru (Dart 3.3+).

```bash
# 1. Buat kerangka platform di folder baru, lalu salin kode ini ke dalamnya
flutter create --org id.samtopup --project-name samtopup_app samtopup_app_build
cp -r lib assets pubspec.yaml samtopup_app_build/
cd samtopup_app_build
flutter pub get

# 2. Coba dengan data contoh (tanpa server)
flutter run

# 3. Terhubung ke server asli (setelah API siap)
flutter run --dart-define=MOCK=false --dart-define=API_BASE=https://domainanda.com/api/v1
```

Mode contoh (`MOCK=true`, bawaan) memakai data palsu di `lib/api/mock_repository.dart`: pesanan contoh berubah
dari menunggu, diproses, lalu berhasil dalam sekitar 20 detik, jadi alur bisa dicoba penuh.

## Rilis ke Play Store

```bash
flutter build appbundle --release \
  --dart-define=MOCK=false --dart-define=API_BASE=https://domainanda.com/api/v1
```
Siapkan keystore penandatanganan, nama paket (`id.samtopup...`), ikon (`assets/images/icon.png` bisa dipakai
dengan paket `flutter_launcher_icons`), dan kebijakan privasi. Aplikasi jual beli item digital bisa
meminta syarat tambahan dari Play Store, jadi baca kebijakan pembayarannya sebelum mengajukan.

## Struktur kode

```
lib/
  main.dart            titik masuk, tema
  config.dart          alamat API dan mode contoh
  theme.dart           warna dan gaya (terang & gelap)
  models.dart          bentuk data dari API
  api/                 api_client, repository (server), mock_repository (contoh)
  state/app_state.dart tema, login, riwayat di perangkat
  screens/             home, game, order, orders, account, shell
  widgets/common.dart  gambar, kartu, judul, status
docs/API.md            kontrak API yang harus disediakan server
```

## Yang belum ada

- **Notifikasi push.** Butuh proyek Firebase milik Anda (`google-services.json`), paket `firebase_messaging`,
  dan server yang mengirim notifikasi saat status pesanan berubah. Endpoint `/device-token` sudah
  dirancang di `docs/API.md`. Sementara itu, status pesanan di layar detail diperbarui otomatis.
- **Isi saldo** dan fitur lain di luar membeli: tetap lewat web.
- **Logo di splash screen dan ikon peluncur:** pakai `assets/images/icon.png`.

## Catatan

Kode ini ditulis tanpa bisa dikompilasi di lingkungan pembuatnya (SDK Flutter tidak bisa diunduh di sana),
jadi kemungkinan ada kesalahan kecil saat `flutter pub get` atau `flutter run` pertama. Kirim pesan error-nya
untuk diperbaiki.
