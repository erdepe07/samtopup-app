import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'order_screen.dart';

class GameScreen extends StatefulWidget {
  final String slug;
  final String title;
  const GameScreen({super.key, required this.slug, required this.title});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameDetail? _game;
  String? _error;
  bool _loading = true;

  final Map<String, TextEditingController> _ctrl = {};
  final _whatsapp = TextEditingController();
  Product? _product;
  PayMethod? _method;

  String? _nickname;
  String? _nickError;
  bool _checking = false;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final g = await app.repo.game(widget.slug);
      if (!mounted) return;
      for (final f in g.fields) {
        _ctrl.putIfAbsent(f.key, () => TextEditingController());
      }
      setState(() {
        _game = g;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Map<String, String> get _fields => {
        for (final e in _ctrl.entries) e.key: e.value.text.trim(),
      };

  bool get _fieldsFilled => _game != null && _game!.fields.every((f) => (_ctrl[f.key]?.text.trim() ?? '').isNotEmpty);

  int get _fee => (_product == null || _method == null) ? 0 : _method!.feeFor(_product!.price);
  int get _total => (_product?.price ?? 0) + _fee;

  Future<void> _checkNickname() async {
    if (!_fieldsFilled) {
      showSnack(context, 'Lengkapi ID terlebih dahulu.');
      return;
    }
    final app = AppScope.read(context);
    setState(() {
      _checking = true;
      _nickname = null;
      _nickError = null;
    });
    try {
      final n = await app.repo.checkNickname(widget.slug, _fields);
      if (!mounted) return;
      setState(() => _nickname = n);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _nickError = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _buy() async {
    final app = AppScope.read(context);
    if (!_fieldsFilled) return showSnack(context, 'Lengkapi data akun terlebih dahulu.');
    if (_product == null) return showSnack(context, 'Pilih nominal terlebih dahulu.');
    if (_method == null) return showSnack(context, 'Pilih metode pembayaran.');
    if (_method!.requiresLogin && !app.loggedIn) {
      return showSnack(context, 'Masuk ke akun untuk memakai metode ini.');
    }

    setState(() => _buying = true);
    try {
      final order = await app.repo.createOrder(CreateOrderRequest(
        gameSlug: widget.slug,
        productId: _product!.id,
        methodCode: _method!.code,
        fields: _fields,
        whatsapp: _whatsapp.text.trim(),
      ));
      await app.rememberOrder(order);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderScreen(invoice: order.invoice, initial: order)),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _form(p),
      bottomNavigationBar: (_game == null) ? null : _checkoutBar(p),
    );
  }

  Widget _form(Palette p) {
    final g = _game!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SoftCard(
          child: Row(
            children: [
              RemoteImage(url: g.image, label: g.name, width: 64, height: 64, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (g.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(g.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 1. Data akun
        const SectionTitle('Masukkan data akun', step: '1'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < g.fields.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                flex: i == 0 ? 3 : 2,
                child: TextField(
                  controller: _ctrl[g.fields[i].key],
                  keyboardType: g.fields[i].numeric ? TextInputType.number : TextInputType.text,
                  inputFormatters: g.fields[i].numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
                  onChanged: (_) => setState(() {
                    _nickname = null;
                    _nickError = null;
                  }),
                  decoration: InputDecoration(
                    labelText: g.fields[i].label,
                    hintText: g.fields[i].hint,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (g.supportsNickname) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _nickname != null
                    ? Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_nickname!, style: const TextStyle(fontWeight: FontWeight.w800))),
                      ])
                    : Text(_nickError ?? 'Cek nama akun sebelum membeli.',
                        style: TextStyle(color: _nickError != null ? const Color(0xFFDC2626) : p.muted, fontSize: 12.5)),
              ),
              TextButton(
                onPressed: _checking ? null : _checkNickname,
                child: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cek Akun', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),

        // 2. Nominal
        const SectionTitle('Pilih nominal', step: '2'),
        for (final group in g.groups) ...[
          if (g.groups.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Text(group.name, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [for (final prod in group.products) _productTile(prod, p)],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),

        // 3. Metode
        const SectionTitle('Pilih metode pembayaran', step: '3'),
        ..._methodList(g, p),
        const SizedBox(height: 22),

        // 4. Kontak
        const SectionTitle('Nomor WhatsApp (opsional)', step: '4'),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '08xxxxxxxxxx'),
        ),
        const SizedBox(height: 6),
        Text('Untuk menerima kabar status pesanan.', style: TextStyle(color: p.muted, fontSize: 12)),
      ],
    );
  }

  Widget _productTile(Product prod, Palette p) {
    final sel = _product?.id == prod.id;
    return SoftCard(
      selected: sel,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => setState(() => _product = prod),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prod.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(rupiah(prod.price), style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 13)),
              if (prod.originalPrice > prod.price) ...[
                const SizedBox(width: 6),
                Text(
                  rupiah(prod.originalPrice),
                  style: TextStyle(color: p.muted, fontSize: 11, decoration: TextDecoration.lineThrough),
                ),
              ],
            ],
          ),
          if (prod.note.isNotEmpty)
            Text(prod.note, style: TextStyle(color: p.accent, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  List<Widget> _methodList(GameDetail g, Palette p) {
    final groups = <String, List<PayMethod>>{};
    for (final m in g.methods) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }
    final app = AppScope.of(context);
    final out = <Widget>[];
    groups.forEach((name, list) {
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(name, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
      ));
      for (final m in list) {
        final disabled = m.requiresLogin && !app.loggedIn;
        final fee = _product == null ? null : m.feeFor(_product!.price);
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: disabled ? .5 : 1,
            child: SoftCard(
              selected: _method?.code == m.code,
              onTap: disabled ? () => showSnack(context, 'Masuk ke akun untuk memakai ${m.name}.') : () => setState(() => _method = m),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (m.image.isNotEmpty) ...[
                    RemoteImage(url: m.image, width: 44, height: 28, radius: 6, fit: BoxFit.contain),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (m.requiresLogin && !app.loggedIn)
                          Text('Perlu masuk akun', style: TextStyle(color: p.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  if (fee != null)
                    Text(fee == 0 ? 'Gratis' : '+${rupiah(fee)}', style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ));
      }
    });
    return out;
  }

  Widget _checkoutBar(Palette p) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total bayar', style: TextStyle(color: p.muted, fontSize: 12)),
                  Text(
                    _product == null ? '-' : rupiah(_total),
                    style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 19),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 170,
              child: ElevatedButton(
                onPressed: _buying ? null : _buy,
                child: _buying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Beli Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
