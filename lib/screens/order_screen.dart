import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  /// true = ini isi saldo (bukan pesanan game).
  final bool topup;
  const OrderScreen({super.key, required this.invoice, this.initial, this.topup = false});

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
      final o = widget.topup ? await app.repo.topup(widget.invoice) : await app.repo.order(widget.invoice);
      if (!mounted) return;
      setState(() {
        _order = o;
        _error = null;
      });
      if (widget.topup) {
        if (o.status == 'success') await app.refreshUser(); // saldo baru tampil di Akun
      } else {
        await app.rememberOrder(o);
      }
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
      appBar: AppBar(title: Text(widget.topup ? 'Isi Saldo' : 'Detail Pesanan', style: TextStyle(fontWeight: FontWeight.w800))),
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
                                  Text(widget.topup ? 'Nomor isi saldo' : 'Nomor transaksi', style: TextStyle(color: p.muted, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  SelectableText(o.invoice, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Salin nomor',
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: o.invoice));
                                showSnack(context, 'Nomor transaksi disalin.');
                              },
                            ),
                            StatusChip(o.status),
                          ],
                        ),
                        const Divider(height: 28),
                        if (!widget.topup) ...[
                          _row('Game', o.game),
                          _row('Item', o.product),
                          _row('Tujuan', o.target),
                        ],
                        _row('Waktu', formatDateTime(o.createdAt)),
                        _row('Metode', o.method),
                        _row('Total', rupiah(o.total), bold: true),
                      ],
                    ),
                  ),
                  if (!widget.topup && !AppScope.of(context).loggedIn) ...[
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: p.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Salin nomor transaksi ini! Karena Anda belum login, pesanan hanya bisa dilihat lagi '
                                  'lewat menu Pesanan > Cek pesanan dengan memasukkan nomor ini.',
                                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: o.invoice));
                              showSnack(context, 'Nomor transaksi disalin.');
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text('Salin ${o.invoice}'),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            Expanded(child: Text('${widget.topup ? 'Menunggu pembayaran' : 'Pesanan sedang diproses'}. Halaman ini diperbarui otomatis.', style: TextStyle(color: p.muted))),
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
            if (pay.qrUrl.isEmpty && pay.qrString.isNotEmpty) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: QrImageView(data: pay.qrString, size: 220, backgroundColor: Colors.white),
                ),
              ),
            ],
            if (pay.qrUrl.isNotEmpty || pay.qrString.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Buka aplikasi e-wallet / m-banking, pilih Scan QR (atau unggah dari galeri), lalu bayar sesuai total. '
                'Bila membayar dari HP ini, screenshot QR di atas dulu.',
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ],
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
            const SizedBox(height: 8),
            Text('Total bayar', style: TextStyle(color: p.muted, fontSize: 12.5)),
            Row(
              children: [
                Expanded(child: SelectableText(rupiah(o.total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: p.primary))),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Salin nominal',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${o.total}')); // angka saja, tanpa titik
                    showSnack(context, 'Nominal disalin.');
                  },
                ),
              ],
            ),
            if (pay.instruction.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(pay.instruction, style: TextStyle(color: p.muted, fontSize: 12.5)),
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