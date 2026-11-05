import '../models.dart';
import 'api_client.dart';

/// Pintu tunggal ke data. Ada dua isi: [HttpRepository] (server asli)
/// dan [MockRepository] (data contoh untuk mencoba tampilan).
abstract class Repository {
  Future<HomeData> home();
  Future<GameDetail> game(String slug);

  /// Mengembalikan nama akun game, atau melempar [ApiException] bila tidak ditemukan.
  Future<String> checkNickname(String slug, Map<String, String> fields);

  Future<Order> createOrder(CreateOrderRequest req);
  Future<Order> order(String invoice);
  Future<List<Order>> myOrders();

  /// Isi saldo (wajib login). Hasilnya berbentuk [Order] agar layar pembayaran bisa dipakai ulang.
  Future<TopupInfo> topupInfo();
  Future<Order> createTopup(int amount, String methodCode);
  Future<Order> topup(String id);
  Future<List<Order>> myTopups();

  Future<AuthResult> login(String username, String password);
  Future<AuthResult> register({
    required String username,
    required String whatsapp,
    required String password,
    required String passwordConfirm,
  });
  Future<AppUser> me();
  Future<void> registerDevice(String fcmToken, String platform);
}

class HttpRepository implements Repository {
  final ApiClient api;
  HttpRepository(this.api);

  Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

  @override
  Future<HomeData> home() async =>
      HomeData.fromJson(_map(await api.get('/home')));

  @override
  Future<GameDetail> game(String slug) async =>
      GameDetail.fromJson(_map(await api.get('/games/$slug')));

  @override
  Future<String> checkNickname(String slug, Map<String, String> fields) async {
    final d =
        _map(await api.post('/games/$slug/check-nickname', {'fields': fields}));
    return '${d['nickname'] ?? ''}';
  }

  @override
  Future<Order> createOrder(CreateOrderRequest req) async =>
      Order.fromJson(_map(await api.post('/orders', req.toJson())));

  @override
  Future<Order> order(String invoice) async => Order.fromJson(
      _map(await api.get('/orders/${Uri.encodeComponent(invoice)}')));

  @override
  Future<List<Order>> myOrders() async {
    final d = await api.get('/orders');
    final list = d is Map ? d['orders'] : d;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<TopupInfo> topupInfo() async =>
      TopupInfo.fromJson(_map(await api.get('/topup/methods')));

  @override
  Future<Order> createTopup(int amount, String methodCode) async =>
      Order.fromJson(_map(await api
          .post('/topup', {'amount': amount, 'method_code': methodCode})));

  @override
  Future<List<Order>> myTopups() async {
    final d = await api.get('/topup');
    final list = d is Map ? d['orders'] : d;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Order> topup(String id) async =>
      Order.fromJson(_map(await api.get('/topup/${Uri.encodeComponent(id)}')));

  @override
  Future<AuthResult> login(String username, String password) async =>
      AuthResult.fromJson(_map(await api
          .post('/auth/login', {'username': username, 'password': password})));

  @override
  Future<AuthResult> register({
    required String username,
    required String whatsapp,
    required String password,
    required String passwordConfirm,
  }) async =>
      AuthResult.fromJson(_map(await api.post('/auth/register', {
        'username': username,
        'whatsapp': whatsapp,
        'password': password,
        'password_confirm': passwordConfirm,
      })));

  @override
  Future<AppUser> me() async => AppUser.fromJson(_map(await api.get('/me')));

  @override
  Future<void> registerDevice(String fcmToken, String platform) async {
    await api.post('/device-token', {'token': fcmToken, 'platform': platform});
  }
}
