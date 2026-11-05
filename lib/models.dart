int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return (num.tryParse('${v ?? ''}') ?? 0).toInt();
}

String _str(dynamic v) => v == null ? '' : '$v';

List<Map<String, dynamic>> _list(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

class GameSummary {
  final String slug, name, image;
  const GameSummary(
      {required this.slug, required this.name, required this.image});

  factory GameSummary.fromJson(Map<String, dynamic> j) => GameSummary(
        slug: _str(j['slug']),
        name: _str(j['name']),
        image: _str(j['image']),
      );
}

class GameCategory {
  final String name;
  final List<GameSummary> games;
  const GameCategory({required this.name, required this.games});

  factory GameCategory.fromJson(Map<String, dynamic> j) => GameCategory(
        name: _str(j['name']),
        games: _list(j['games']).map(GameSummary.fromJson).toList(),
      );
}

class HomeData {
  final List<String> banners;
  final List<GameCategory> categories;
  final List<String> methodImages;
  const HomeData({
    required this.banners,
    required this.categories,
    required this.methodImages,
  });

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        banners: _list(j['banners']).map((e) => _str(e['image'])).toList(),
        categories: _list(j['categories']).map(GameCategory.fromJson).toList(),
        methodImages: _list(j['methods']).map((e) => _str(e['image'])).toList(),
      );
}

/// Kolom isian di halaman beli (mis. User ID, Zone ID).
class FieldDef {
  final String key, label, hint;
  final bool numeric;
  const FieldDef({
    required this.key,
    required this.label,
    this.hint = '',
    this.numeric = false,
  });

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
        key: _str(j['key']),
        label: _str(j['label']),
        hint: _str(j['hint']),
        numeric: j['type'] == 'number',
      );
}

class Product {
  final String id, name, note;
  final int price, originalPrice;
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice = 0,
    this.note = '',
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _str(j['id']),
        name: _str(j['name']),
        price: _int(j['price']),
        originalPrice: _int(j['original_price']),
        note: _str(j['note']),
      );
}

class ProductGroup {
  final String name;
  final List<Product> products;
  const ProductGroup({required this.name, required this.products});

  factory ProductGroup.fromJson(Map<String, dynamic> j) => ProductGroup(
        name: _str(j['name']),
        products: _list(j['products']).map(Product.fromJson).toList(),
      );
}

class PayMethod {
  final String code, name, image, group;
  final int feeFlat;
  final double feePercent;
  final bool requiresLogin;
  const PayMethod({
    required this.code,
    required this.name,
    this.image = '',
    this.group = 'Lainnya',
    this.feeFlat = 0,
    this.feePercent = 0,
    this.requiresLogin = false,
  });

  factory PayMethod.fromJson(Map<String, dynamic> j) => PayMethod(
        code: _str(j['code']),
        name: _str(j['name']),
        image: _str(j['image']),
        group: _str(j['group']).isEmpty ? 'Lainnya' : _str(j['group']),
        feeFlat: _int(j['fee_flat']),
        feePercent: (num.tryParse(_str(j['fee_percent'])) ?? 0).toDouble(),
        requiresLogin: j['requires_login'] == true,
      );

  /// Perkiraan biaya. Angka final selalu dihitung server.
  int feeFor(int price) => feeFlat + (price * feePercent / 100).ceil();
}

class GameDetail {
  final String slug, name, image, description;
  final bool supportsNickname;
  final List<FieldDef> fields;
  final List<ProductGroup> groups;
  final List<PayMethod> methods;
  const GameDetail({
    required this.slug,
    required this.name,
    required this.image,
    required this.description,
    required this.supportsNickname,
    required this.fields,
    required this.groups,
    required this.methods,
  });

  factory GameDetail.fromJson(Map<String, dynamic> j) => GameDetail(
        slug: _str(j['slug']),
        name: _str(j['name']),
        image: _str(j['image']),
        description: _str(j['description']),
        supportsNickname: j['supports_nickname'] == true,
        fields: _list(j['fields']).map(FieldDef.fromJson).toList(),
        groups: _list(j['groups']).map(ProductGroup.fromJson).toList(),
        methods: _list(j['methods']).map(PayMethod.fromJson).toList(),
      );
}

class PaymentInfo {
  /// qris | va | retail | redirect | balance | none
  final String type;
  final String checkoutUrl,
      qrUrl,
      qrString,
      payCode,
      payLabel,
      instruction,
      expiredAt;
  const PaymentInfo({
    this.type = 'none',
    this.checkoutUrl = '',
    this.qrUrl = '',
    this.qrString = '',
    this.payCode = '',
    this.payLabel = '',
    this.instruction = '',
    this.expiredAt = '',
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        type: _str(j['type']).isEmpty ? 'none' : _str(j['type']),
        checkoutUrl: _str(j['checkout_url']),
        qrUrl: _str(j['qr_url']),
        qrString: _str(j['qr_string']),
        payCode: _str(j['pay_code']),
        payLabel: _str(j['pay_label']),
        instruction: _str(j['instruction']),
        expiredAt: _str(j['expired_at']),
      );
}

class Order {
  final String invoice, status, game, product, target, method, createdAt, note;
  final int total;
  final PaymentInfo payment;
  const Order({
    required this.invoice,
    required this.status,
    required this.game,
    required this.product,
    required this.target,
    required this.method,
    required this.createdAt,
    required this.total,
    this.note = '',
    this.payment = const PaymentInfo(),
  });

  bool get isFinal => const ['success', 'failed', 'expired'].contains(status);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        invoice: _str(j['invoice']),
        status: _str(j['status']),
        game: _str(j['game']),
        product: _str(j['product']),
        target: _str(j['target']),
        method: _str(j['method']),
        createdAt: _str(j['created_at']),
        total: _int(j['total']),
        note: _str(j['note']),
        payment: j['payment'] is Map
            ? PaymentInfo.fromJson(Map<String, dynamic>.from(j['payment']))
            : const PaymentInfo(),
      );

  /// Ringkasan untuk riwayat di perangkat.
  Map<String, dynamic> toJson() => {
        'invoice': invoice,
        'status': status,
        'game': game,
        'product': product,
        'target': target,
        'method': method,
        'created_at': createdAt,
        'total': total,
      };
}

class TopupInfo {
  final int min, max;
  final List<PayMethod> methods;
  const TopupInfo(
      {this.min = 10000, this.max = 5000000, this.methods = const []});

  factory TopupInfo.fromJson(Map<String, dynamic> j) => TopupInfo(
        min: _int(j['min']) == 0 ? 10000 : _int(j['min']),
        max: _int(j['max']) == 0 ? 5000000 : _int(j['max']),
        methods: _list(j['methods']).map(PayMethod.fromJson).toList(),
      );
}

class AppUser {
  final String name, username;
  final int balance;
  const AppUser({required this.name, required this.username, this.balance = 0});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        name: _str(j['name']),
        username: _str(j['username']),
        balance: _int(j['balance']),
      );
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: _str(j['token']),
        user: AppUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
      );
}

class CreateOrderRequest {
  final String gameSlug, productId, methodCode, whatsapp;
  final Map<String, String> fields;
  const CreateOrderRequest({
    required this.gameSlug,
    required this.productId,
    required this.methodCode,
    required this.fields,
    this.whatsapp = '',
  });

  Map<String, dynamic> toJson() => {
        'game_slug': gameSlug,
        'product_id': productId,
        'method_code': methodCode,
        'fields': fields,
        'whatsapp': whatsapp,
      };
}

/// "05/11/2026 21:41" dari teks ISO 8601 (waktu setempat).
String formatDateTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String rupiah(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp$b';
}
