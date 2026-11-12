import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'print_dialog.dart';

enum NotaAction { none, share, print }

/// Pratinjau nota (gambar). Dari sini nota bisa dibagikan sebagai gambar PNG atau dicetak.
class NotaScreen extends StatefulWidget {
  final Order order;
  final bool topup;
  final NotaAction auto; // aksi yang langsung dijalankan setelah nota tampil
  const NotaScreen(
      {super.key,
      required this.order,
      this.topup = false,
      this.auto = NotaAction.none});

  @override
  State<NotaScreen> createState() => _NotaScreenState();
}

class _NotaScreenState extends State<NotaScreen> {
  final _key = GlobalKey();
  final _priceCtl = TextEditingController();
  bool _busy = false;
  int _price = 0; // harga yang tertulis di nota (bisa diubah)
  String _footer = '';

  @override
  void initState() {
    super.initState();
    _price = widget.order.total;
    _priceCtl.text = '$_price';
    _loadPrefs().then((_) => _autoRun());
  }

  @override
  void dispose() {
    _priceCtl.dispose();
    super.dispose();
  }

  /// Harga jual tersimpan (dari dialog Cetak) dan footer dipakai sebagai nilai awal.
  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getInt('sell_price_${widget.order.product}');
      if (saved != null && saved > 0 && !widget.topup) {
        _price = saved;
        _priceCtl.text = '$saved';
      }
      _footer = p.getString('print_footer') ?? '';
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _autoRun() {
    if (widget.auto != NotaAction.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(
            const Duration(milliseconds: 350)); // tunggu nota selesai digambar
        if (!mounted) return;
        widget.auto == NotaAction.share ? _share() : _print();
      });
    }
  }

  Future<Uint8List> _png() async {
    final boundary =
        _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _png();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nota_${widget.order.invoice}.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Nota ${widget.order.invoice} - ${AppConfig.appName}',
      );
    } catch (_) {
      if (mounted) showSnack(context, 'Gagal membagikan nota. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cetak = printer thermal Bluetooth (dialog pengaturan di print_dialog.dart).
  Future<void> _print() async {
    if (_busy) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PrintDialog(
          order: widget.order, topup: widget.topup, initialPrice: _price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF9),
      appBar: AppBar(
          title: const Text('Nota',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: RepaintBoundary(
                  key: _key,
                  child: _Receipt(
                      order: widget.order,
                      topup: widget.topup,
                      total: _price,
                      footer: _footer),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _priceCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Total di nota (bisa diubah)',
                prefixText: 'Rp ',
                filled: true,
              ),
              onChanged: (v) => setState(() => _price = int.tryParse(v) ?? 0),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder()),
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Cetak',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Bagikan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nota: warna tetap (terang) supaya hasil gambar/cetak selalu terbaca, apa pun tema aplikasi.
class _Receipt extends StatelessWidget {
  final Order order;
  final bool topup;
  final int total;
  final String footer;
  const _Receipt(
      {required this.order,
      required this.topup,
      required this.total,
      required this.footer});

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF1D4ED8);

  (String, Color) get _status {
    switch (order.status) {
      case 'success':
        return ('BERHASIL', const Color(0xFF16A34A));
      case 'processing':
        return ('DIPROSES', const Color(0xFF2563EB));
      case 'pending':
        return ('MENUNGGU PEMBAYARAN', const Color(0xFFD97706));
      case 'expired':
        return ('KEDALUWARSA', const Color(0xFF64748B));
      default:
        return ('GAGAL', const Color(0xFFDC2626));
    }
  }

  Widget _line(String k, String v, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 96,
                child: Text(k,
                    style: const TextStyle(color: _muted, fontSize: 13))),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color ?? _ink,
                  fontSize: bold ? 16 : 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dash() => LayoutBuilder(
        builder: (_, c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: List.generate(
              (c.maxWidth / 7).floor(),
              (_) => Expanded(
                  child: Container(
                      height: 1.2,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      color: const Color(0xFFCBD5E1))),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status;
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 6))
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: _ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('sam topup',
                  style: TextStyle(
                      color: _blue,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(topup ? 'NOTA ISI SALDO' : 'NOTA PEMBELIAN',
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
            ),
            _dash(),
            _line('No. Transaksi', order.invoice),
            _line('Waktu', formatDateTime(order.createdAt)),
            if (!topup) ...[
              _line('Game', order.game),
              _line('Item', order.product),
              _line('Tujuan', order.target),
            ],
            _line('Metode', order.method),
            _dash(),
            _line('Total', rupiah(total), bold: true, color: _blue),
            if (order.status == 'success' && order.note.isNotEmpty) ...[
              _dash(),
              const Text('Catatan / SN',
                  style: TextStyle(color: _muted, fontSize: 12.5)),
              const SizedBox(height: 4),
              SelectableText(order.note,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
            _dash(),
            if (footer.trim().isNotEmpty)
              Center(
                  child: Text(footer.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _muted, fontSize: 12.5, height: 1.4)))
            else ...const [
              Center(
                  child: Text('Terima kasih telah berbelanja',
                      style: TextStyle(color: _muted, fontSize: 12.5))),
              SizedBox(height: 2),
              Center(
                  child: Text('samtopup.biz.id',
                      style: TextStyle(
                          color: _blue,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700))),
            ],
          ],
        ),
      ),
    );
  }
}
