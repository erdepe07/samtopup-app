import 'dart:async';

import '../models.dart';
import 'api_client.dart';
import 'repository.dart';

/// Data contoh supaya aplikasi bisa dicoba tanpa server.
class MockRepository implements Repository {
  final Map<String, DateTime> _created = {};
  final Map<String, Order> _orders = {};
  AppUser? _user;

  Future<T> _delay<T>(T v) => Future.delayed(const Duration(milliseconds: 450), () => v);

  @override
  Future<HomeData> home() => _delay(HomeData(
        banners: const ['', ''],
        methodImages: const [],
        categories: [
          GameCategory(name: 'Games', games: [
            for (final g in const [
              ['mobile-legends', 'Mobile Legends'],
              ['free-fire', 'Free Fire'],
              ['pubg-mobile', 'PUBG Mobile'],
              ['genshin-impact', 'Genshin Impact'],
              ['valorant', 'Valorant'],
              ['honor-of-kings', 'Honor of Kings'],
            ])
              GameSummary(slug: g[0], name: g[1], image: ''),
          ]),
          const GameCategory(name: 'Pulsa', games: [
            GameSummary(slug: 'telkomsel', name: 'Telkomsel', image: ''),
            GameSummary(slug: 'indosat', name: 'Indosat', image: ''),
          ]),
          const GameCategory(name: 'Voucher', games: [
            GameSummary(slug: 'google-play', name: 'Google Play', image: ''),
          ]),
        ],
      ));

  @override
  Future<GameDetail> game(String slug) {
    final isMl = slug == 'mobile-legends';
    return _delay(GameDetail(
      slug: slug,
      name: slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
      image: '',
      description: 'Topup cepat dan aman. Masukkan ID akun dengan benar, pesanan diproses otomatis.',
      supportsNickname: isMl,
      fields: [
        const FieldDef(key: 'user_id', label: 'User ID', hint: 'Masukkan User ID', numeric: true),
        if (isMl) const FieldDef(key: 'zone_id', label: 'Zone ID', hint: 'Zone', numeric: true),
      ],
      groups: const [
        ProductGroup(name: 'Diamond', products: [
          Product(id: 'd5', name: '5 Diamond', price: 1500),
          Product(id: 'd12', name: '12 Diamond', price: 3300),
          Product(id: 'd59', name: '59 Diamond', price: 15800, originalPrice: 16500),
          Product(id: 'd172', name: '172 Diamond', price: 45000),
          Product(id: 'd344', name: '344 Diamond', price: 89000, note: 'Terlaris'),
          Product(id: 'd706', name: '706 Diamond', price: 178000),
        ]),
        ProductGroup(name: 'Pass & Bundle', products: [
          Product(id: 'wdp', name: 'Weekly Diamond Pass', price: 27500),
          Product(id: 'twilight', name: 'Twilight Pass', price: 145000),
        ]),
      ],
      methods: const [
        PayMethod(code: 'qris', name: 'QRIS', group: 'E-Wallet & QRIS', feePercent: 0.7),
        PayMethod(code: 'bca_va', name: 'BCA Virtual Account', group: 'Transfer Bank', feeFlat: 4000),
        PayMethod(code: 'mandiri_va', name: 'Mandiri Virtual Account', group: 'Transfer Bank', feeFlat: 4000),
        PayMethod(code: 'alfamart', name: 'Alfamart', group: 'Minimarket', feeFlat: 3500),
        PayMethod(code: 'saldo', name: 'Saldo Member', group: 'Saldo', requiresLogin: true),
      ],
    ));
  }

  @override
  Future<String> checkNickname(String slug, Map<String, String> fields) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final id = fields['user_id'] ?? '';
    if (id.length < 5) throw const ApiException('ID tidak ditemukan.');
    return 'Pemain_$id';
  }

  @override
  Future<Order> createOrder(CreateOrderRequest req) async {
    final inv = 'INV${DateTime.now().millisecondsSinceEpoch % 100000000}';
    _created[inv] = DateTime.now();
    final detail = await game(req.gameSlug);
    final product = detail.groups.expand((g) => g.products).firstWhere((p) => p.id == req.productId);
    final method = detail.methods.firstWhere((m) => m.code == req.methodCode);
    final total = product.price + method.feeFor(product.price);
    final isBalance = method.code == 'saldo';
    final o = Order(
      invoice: inv,
      status: isBalance ? 'processing' : 'pending',
      game: detail.name,
      product: product.name,
      target: req.fields.values.join(' / '),
      method: method.name,
      createdAt: DateTime.now().toIso8601String(),
      total: total,
      payment: isBalance
          ? const PaymentInfo(type: 'balance')
          : PaymentInfo(
              type: method.code.contains('va') ? 'va' : 'qris',
              payCode: method.code.contains('va') ? '8077 0000 1234 5678' : '',
              payLabel: method.name,
              expiredAt: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            ),
    );
    _orders[inv] = o;
    return _delay(o);
  }

  @override
  Future<Order> order(String invoice) async {
    final o = _orders[invoice];
    if (o == null) throw const ApiException('Pesanan tidak ditemukan.', status: 404);
    final age = DateTime.now().difference(_created[invoice]!).inSeconds;
    final status = age > 20 ? 'success' : (age > 10 ? 'processing' : o.status);
    return Order(
      invoice: o.invoice,
      status: status,
      game: o.game,
      product: o.product,
      target: o.target,
      method: o.method,
      createdAt: o.createdAt,
      total: o.total,
      payment: status == 'success' ? const PaymentInfo() : o.payment,
      note: status == 'success' ? 'Pesanan berhasil dikirim ke akun Anda.' : '',
    );
  }

  @override
  Future<List<Order>> myOrders() async => _delay(_orders.values.toList().reversed.toList());

  @override
  Future<AuthResult> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (password.length < 4) throw const ApiException('Username atau password salah.', status: 401);
    _user = AppUser(name: username, username: username, balance: 250000);
    return AuthResult(token: 'mock-token', user: _user!);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String username,
    required String password,
    String whatsapp = '',
  }) async {
    _user = AppUser(name: name, username: username, balance: 0);
    return _delay(AuthResult(token: 'mock-token', user: _user!));
  }

  @override
  Future<AppUser> me() async => _user ?? (throw const ApiException('Belum login.', status: 401));

  @override
  Future<void> registerDevice(String fcmToken, String platform) async {}
}
