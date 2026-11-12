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

  // Filter tanggal riwayat (bawaan: hari ini saja, supaya ringan).
  String _preset = 'today';
  DateTime _from = _dayOnly(DateTime.now());
  DateTime _to = _dayOnly(DateTime.now());

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _setPreset(String key) {
    final today = _dayOnly(DateTime.now());
    setState(() {
      _preset = key;
      switch (key) {
        case 'yesterday':
          _from = _to = today.subtract(const Duration(days: 1));
          break;
        case '7d':
          _from = today.subtract(const Duration(days: 6));
          _to = today;
          break;
        case '30d':
          _from = today.subtract(const Duration(days: 29));
          _to = today;
          break;
        default:
          _from = _to = today;
      }
    });
    _loadRemote();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Pilih rentang tanggal (maks. 3 bulan)',
    );
    if (r == null) return;
    setState(() {
      _preset = 'custom';
      _from = _dayOnly(r.start);
      _to = _dayOnly(r.end);
    });
    _loadRemote();
  }

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
      final list = await app.repo.myOrders(from: _ymd(_from), to: _ymd(_to));
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

    // Tanpa login daftar kosong: pesanan hanya bisa dicari lewat nomor transaksi.
    final orders = app.loggedIn ? (_remote ?? const <Order>[]) : const <Order>[];

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
            if (!app.loggedIn)
              SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: p.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Anda belum login, jadi riwayat pesanan tidak ditampilkan. '
                        'Salin nomor transaksi setiap kali membeli, lalu cari pesanannya di kolom atas. '
                        'Login untuk melihat semua pesanan Anda di sini.',
                        style: TextStyle(color: p.muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
            const SectionTitle('Riwayat pesanan'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in const {'today': 'Hari ini', 'yesterday': 'Kemarin', '7d': '7 hari', '30d': '30 hari'}.entries)
                  ChoiceChip(label: Text(e.value), selected: _preset == e.key, onSelected: (_) => _setPreset(e.key)),
                ChoiceChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Pilih tanggal'),
                  selected: _preset == 'custom',
                  onSelected: (_) => _pickRange(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                _from == _to ? _dmy(_from) : '${_dmy(_from)} – ${_dmy(_to)}',
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))),
            if (!_loading && orders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 44, color: p.muted),
                    const SizedBox(height: 10),
                    Text('Tidak ada pesanan pada tanggal ini.', style: TextStyle(color: p.muted)),
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
                            const SizedBox(height: 2),
                            Text(formatDateTime(o.createdAt), style: TextStyle(color: p.muted, fontSize: 12)),
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
          ],
        ),
      ),
    );
  }
}