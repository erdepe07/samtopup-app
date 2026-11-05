import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'order_screen.dart';

/// Cek pesanan lewat nomor invoice + riwayat pesanan.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _invoice = TextEditingController();
  List<Order>? _remote;
  bool _loading = false;
  String? _error;
  bool _lastLoggedIn = false;

  @override
  void dispose() {
    _invoice.dispose();
    super.dispose();
  }

  Future<void> _loadRemote() async {
    final app = AppScope.read(context);
    if (!app.loggedIn) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await app.repo.myOrders();
      if (!mounted) return;
      setState(() => _remote = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String invoice, [Order? o]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderScreen(invoice: invoice, initial: o)),
    );
  }

  void _search() {
    final inv = _invoice.text.trim();
    if (inv.isEmpty) return showSnack(context, 'Masukkan nomor invoice.');
    FocusScope.of(context).unfocus();
    _open(inv);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);

    // Muat riwayat server saat status login berubah.
    if (app.loggedIn != _lastLoggedIn) {
      _lastLoggedIn = app.loggedIn;
      if (app.loggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemote());
      } else {
        _remote = null;
      }
    }

    final orders = app.loggedIn ? (_remote ?? app.localOrders) : app.localOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan', style: TextStyle(fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
        onRefresh: _loadRemote,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionTitle('Cek pesanan'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoice,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(hintText: 'Nomor invoice'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(onPressed: _search, child: const Text('Cek')),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SectionTitle(app.loggedIn ? 'Riwayat pesanan' : 'Pesanan di perangkat ini'),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))),
            if (!_loading && orders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 44, color: p.muted),
                    const SizedBox(height: 10),
                    Text('Belum ada pesanan.', style: TextStyle(color: p.muted)),
                  ],
                ),
              ),
            for (final o in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  onTap: () => _open(o.invoice, o),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${o.game} · ${o.product}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(o.invoice, style: TextStyle(color: p.muted, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(rupiah(o.total), style: TextStyle(color: p.primary, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      StatusChip(o.status),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
