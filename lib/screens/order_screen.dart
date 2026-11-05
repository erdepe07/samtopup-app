import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Detail pesanan + petunjuk pembayaran. Status dicek otomatis selama belum selesai.
class OrderScreen extends StatefulWidget {
  final String invoice;
  final Order? initial;
  const OrderScreen({super.key, required this.invoice, this.initial});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Order? _order;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _order = widget.initial;
    _fetch();
    _timer = Timer.periodic(AppConfig.orderPollInterval, (_) {
      if (_order == null || !_order!.isFinal) _fetch(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    final app = AppScope.read(context);
    try {
      final o = await app.repo.order(widget.invoice);
      if (!mounted) return;
      setState(() {
        _order = o;
        _error = null;
      });
      await app.rememberOrder(o);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!silent || _order == null) setState(() => _error = e.message);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Tidak bisa membuka tautan pembayaran.');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.w800))),
      body: o == null
          ? (_error != null
              ? ErrorView(message: _error!, onRetry: _fetch)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SoftCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nomor invoice', style: TextStyle(color: p.muted, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(o.invoice, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ),
                            StatusChip(o.status),
                          ],
                        ),
                        const Divider(height: 28),
                        _row('Game', o.game),
                        _row('Item', o.product),
                        _row('Tujuan', o.target),
                        _row('Metode', o.method),
                        _row('Total', rupiah(o.total), bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (o.note.isNotEmpty)
                    SoftCard(
                      child: Row(
                        children: [
                          Icon(o.status == 'success' ? Icons.check_circle_rounded : Icons.info_rounded,
                              color: StatusChip.info(o.status).$2),
                          const SizedBox(width: 10),
                          Expanded(child: Text(o.note)),
                        ],
                      ),
                    ),
                  if (!o.isFinal && o.payment.type != 'none' && o.payment.type != 'balance')
                    _payment(o, p),
                  if (o.status == 'processing' || (o.payment.type == 'balance' && !o.isFinal))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SoftCard(
                        child: Row(
                          children: [
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Pesanan sedang diproses. Halaman ini diperbarui otomatis.', style: TextStyle(color: p.muted))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(k, style: TextStyle(color: p.muted))),
          Expanded(
            child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? p.primary : null)),
          ),
        ],
      ),
    );
  }

  Widget _payment(Order o, Palette p) {
    final pay = o.payment;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cara bayar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (pay.qrUrl.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Image.network(pay.qrUrl, width: 220, height: 220, errorBuilder: (_, __, ___) => const SizedBox(width: 220, height: 220, child: Icon(Icons.qr_code_2_rounded, size: 120))),
                ),
              ),
            if (pay.payCode.isNotEmpty) ...[
              Text(pay.payLabel.isEmpty ? 'Kode pembayaran' : pay.payLabel, style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: SelectableText(pay.payCode, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: .5))),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pay.payCode.replaceAll(' ', '')));
                      showSnack(context, 'Kode disalin.');
                    },
                  ),
                ],
              ),
            ],
            if (pay.expiredAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Bayar sebelum ${_fmtDate(pay.expiredAt)}', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
            if (pay.checkoutUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: () => _open(pay.checkoutUrl), child: const Text('Bayar Sekarang')),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
