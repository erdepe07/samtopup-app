# Kontrak API sam topup (v1)

Aplikasi mobile hanya **membeli**. Produk, harga, banner, dan metode bayar tetap diatur dari admin web;
aplikasi hanya membaca hasilnya lewat API ini.

- Dasar URL: `https://domainanda.com/api/v1` (wajib HTTPS)
- Format: JSON, UTF-8
- Login: header `Authorization: Bearer <token>` (hanya untuk endpoint bertanda 🔒)
- Semua respons dibungkus:

```json
{ "success": true, "message": "OK", "data": { } }
```

Bila gagal: status HTTP 4xx/5xx dan `{ "success": false, "message": "Pesan yang boleh dibaca pengguna" }`.
Gambar selalu berupa **URL lengkap** (`https://...`), bukan nama file.

## Aturan keamanan (wajib di server)

1. **Harga tidak boleh dipercaya dari aplikasi.** Aplikasi hanya mengirim `product_id` dan `method_code`;
   server menghitung ulang harga, biaya, dan total dari database.
2. Metode `requires_login` (mis. saldo) ditolak bila token tidak ada atau saldo kurang.
3. Batasi `check-nickname` dan `auth/login` (rate limit per IP) agar tidak disalahgunakan.
4. Cegah pesanan ganda: tolak pesanan yang sama (akun + produk + metode) yang masuk dalam beberapa detik.
5. Token dibuat acak (minimal 32 byte), simpan hash-nya di tabel, beri masa berlaku.

## Endpoint

### GET `/home`
```json
{
  "banners": [{ "image": "https://.../banner/1.png" }],
  "categories": [
    { "name": "Games", "games": [
      { "slug": "mobile-legends", "name": "Mobile Legends", "image": "https://.../games/ml.png" }
    ]}
  ],
  "methods": [{ "image": "https://.../method/bca.png" }]
}
```
Hanya kirim game berstatus `On`. Urutan kategori dan game mengikuti web.

### GET `/games/{slug}`
```json
{
  "slug": "mobile-legends",
  "name": "Mobile Legends",
  "image": "https://...",
  "description": "Topup diamond ...",
  "supports_nickname": true,
  "fields": [
    { "key": "user_id", "label": "User ID", "hint": "Masukkan User ID", "type": "number" },
    { "key": "zone_id", "label": "Zone ID", "hint": "Zone", "type": "number" }
  ],
  "groups": [
    { "name": "Diamond", "products": [
      { "id": "d59", "name": "59 Diamond", "price": 15800, "original_price": 16500, "note": "Terlaris" }
    ]}
  ],
  "methods": [
    { "code": "qris", "name": "QRIS", "image": "https://...", "group": "E-Wallet & QRIS",
      "fee_flat": 0, "fee_percent": 0.7, "requires_login": false }
  ]
}
```
`price` dan `fee_*` hanya untuk **perkiraan tampilan**; angka final dari server saat pesanan dibuat.
`id` produk boleh berupa kode produk di database Anda (teks atau angka).

### POST `/games/{slug}/check-nickname`
Body: `{ "fields": { "user_id": "123456", "zone_id": "1234" } }`
Sukses: `{ "nickname": "NamaPemain" }` · Gagal: 404/422 dengan `message`.

### POST `/orders`
Body:
```json
{
  "game_slug": "mobile-legends",
  "product_id": "d59",
  "method_code": "qris",
  "fields": { "user_id": "123456", "zone_id": "1234" },
  "whatsapp": "0812xxxxxxx"
}
```
Respons = objek **Order** (lihat bawah). Pembuatan pesanan harus memakai logika yang sama dengan checkout web
(pembayaran Tripay, pengiriman Digiflazz/Api Games, potong saldo, dst.).

### GET `/orders/{invoice}`
Objek **Order**. Boleh dibuka siapa saja yang tahu nomor invoice (seperti "Cek Pesanan" di web), jadi
nomor invoice harus sulit ditebak. Jangan tampilkan data pribadi lain selain yang ada di bawah.

### 🔒 GET `/orders`
`{ "orders": [ Order, ... ] }` milik pengguna yang login, terbaru dulu (maks. 50).

### POST `/auth/login`
Body: `{ "username": "...", "password": "..." }` → `{ "token": "...", "user": { "name", "username", "balance" } }`
Salah password: HTTP 401.

### POST `/auth/register`
Body: `{ "name", "username", "password", "whatsapp" }` → sama seperti login. Sesuaikan kolom dengan tabel user web.

### 🔒 GET `/me`
`{ "name": "...", "username": "...", "balance": 250000 }` · Token tidak valid: HTTP 401.

### 🔒 POST `/device-token`  *(tahap notifikasi)*
Body: `{ "token": "<fcm token>", "platform": "android" }`. Simpan per pengguna/perangkat.

## Objek Order

```json
{
  "invoice": "INV12345678",
  "status": "pending",
  "game": "Mobile Legends",
  "product": "59 Diamond",
  "target": "123456 / 1234",
  "method": "QRIS",
  "total": 16000,
  "created_at": "2026-11-05T11:44:00+07:00",
  "note": "",
  "payment": {
    "type": "qris",
    "checkout_url": "",
    "qr_url": "https://.../qr.png",
    "pay_code": "",
    "pay_label": "",
    "expired_at": "2026-11-05T12:44:00+07:00"
  }
}
```

- `status`: `pending` (menunggu bayar) · `processing` · `success` · `failed` · `expired`
- `payment.type`: `qris` | `va` | `retail` | `redirect` | `balance` | `none`
  - `qr_url` → ditampilkan sebagai gambar QR
  - `pay_code` → nomor VA / kode bayar (ada tombol salin), `pay_label` = namanya (mis. "BCA Virtual Account")
  - `checkout_url` → tombol "Bayar Sekarang" membuka tautan ini di browser (e-wallet/redirect)
- Setelah `success`/`failed`/`expired`, `payment` boleh dikosongkan.

## Contoh rute CodeIgniter 4 (`app/Config/Routes.php`)

```php
$routes->group('api/v1', ['namespace' => 'App\Controllers\Api'], static function ($routes) {
    $routes->get('home', 'Home::index');
    $routes->get('games/(:segment)', 'Games::show/$1');
    $routes->post('games/(:segment)/check-nickname', 'Games::checkNickname/$1');
    $routes->post('orders', 'Orders::create');
    $routes->get('orders/(:segment)', 'Orders::show/$1');
    $routes->get('orders', 'Orders::mine', ['filter' => 'apiauth']);
    $routes->post('auth/login', 'Auth::login');
    $routes->post('auth/register', 'Auth::register');
    $routes->get('me', 'Auth::me', ['filter' => 'apiauth']);
    $routes->post('device-token', 'Devices::store', ['filter' => 'apiauth']);
});
```
Rute API sebaiknya dikecualikan dari filter CSRF web.
