import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'order_screen.dart';

/// Riwayat isi saldo milik akun yang login.
class TopupHistoryScreen extends StatefulWidget {
  const TopupHistoryScreen({super.key});

  @override
  State<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends State<TopupHistoryScreen> {
  List<Order>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final l = await AppScope.read(context).repo.myTopups();
      if (mounted) setState(() => _list = l);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _date(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Isi Saldo', style: TextStyle(fontWeight: FontWeight.w800))),
      body: list == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 44, color: p.muted),
                              const SizedBox(height: 10),
                              Text('Belum ada isi saldo.', style: TextStyle(color: p.muted)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        for (final o in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => OrderScreen(invoice: o.invoice, initial: o, topup: true),
                                ));
                                if (mounted) _load();
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(rupiah(o.total), style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                                        const SizedBox(height: 3),
                                        Text('${o.method} · ${_date(o.createdAt)}', style: TextStyle(color: p.muted, fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text(o.invoice, style: TextStyle(color: p.muted, fontSize: 12)),
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
