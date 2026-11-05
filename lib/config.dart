/// Pengaturan utama aplikasi.
///
/// Jalankan dengan data contoh (tanpa server):
///   flutter run
/// Jalankan terhubung ke server asli:
///   flutter run --dart-define=MOCK=false --dart-define=API_BASE=https://domainanda.com/api/v1
class AppConfig {
  static const String appName = 'sam topup';

  /// Alamat dasar API (tanpa garis miring di akhir).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://samtopup.biz.id/api/v1',
  );

  /// true = pakai data contoh bawaan aplikasi (untuk mencoba tampilan).
  static const bool useMock = bool.fromEnvironment('MOCK', defaultValue: false);

  /// Selang cek status pesanan yang masih menunggu.
  static const Duration orderPollInterval = Duration(seconds: 5);
}
