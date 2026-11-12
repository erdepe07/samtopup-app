import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Dialog "Cetak" ke printer thermal Bluetooth (58mm / 80mm).
/// Printer harus sudah dipasangkan (pair) lebih dulu di Pengaturan > Bluetooth HP.
class PrintDialog extends StatefulWidget {
  final Order order;
  final bool topup;

  /// Harga yang sedang tampil di nota; jadi nilai awal "Harga Jual".
  final int? initialPrice;
  const PrintDialog(
      {super.key, required this.order, this.topup = false, this.initialPrice});

  @override
  State<PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<PrintDialog> {
  final _price = TextEditingController();
  final _header = TextEditingController();
  final _footer = TextEditingController();
  SharedPreferences? _prefs;

  bool _lunas = true;
  bool _savePrice = false;
  bool _more = false;
  bool _scanning = false;
  bool _printing = false;
  String _font = 'default'; // default | large
  int _paper = 58;
  String? _mac;
  List<BluetoothInfo> _devices = [];
  String? _info;

  String get _priceKey => 'sell_price_${widget.order.product}';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _price.dispose();
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    _price.text =
        '${widget.initialPrice ?? p.getInt(_priceKey) ?? widget.order.total}';
    _savePrice = p.containsKey(_priceKey);
    _header.text = p.getString('print_header') ?? '';
    _footer.text = p.getString('print_footer') ?? '';
    _paper = p.getInt('print_paper') ?? 58;
    _font = p.getString('print_font') ?? 'default';
    _mac = p.getString('print_mac');
    if (mounted) setState(() {});
    await _scan();
  }

  /// Muat daftar printer yang sudah dipasangkan.
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _info = null;
    });
    try {
      final st = await [Permission.bluetoothConnect, Permission.bluetoothScan]
          .request();
      final denied = st.values.any((s) => s.isPermanentlyDenied || s.isDenied);
      if (denied) {
        _info =
            'Izin "Perangkat sekitar" ditolak. Aktifkan di Pengaturan > Aplikasi > sam topup > Izin.';
      } else if (!await PrintBluetoothThermal.bluetoothEnabled) {
        _info = 'Bluetooth belum aktif. Nyalakan Bluetooth lalu tekan CARI.';
      } else {
        final list = await PrintBluetoothThermal.pairedBluetooths;
        _devices = list;
        if (!list.any((d) => d.macAdress == _mac))
          _mac = list.length == 1 ? list.first.macAdress : null;
        if (list.isEmpty) {
          _info =
              'Belum ada printer. Pasangkan (pair) printer di Pengaturan > Bluetooth HP, lalu tekan CARI.';
        }
      }
    } catch (_) {
      _info = 'Gagal membaca perangkat Bluetooth.';
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _print() async {
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (price <= 0) return showSnack(context, 'Isi harga jual.');
    if (_mac == null)
      return showSnack(context, 'Pilih perangkat Bluetooth (printer).');

    setState(() => _printing = true);
    try {
      final p = _prefs!;
      if (_savePrice) {
        await p.setInt(_priceKey, price);
      } else {
        await p.remove(_priceKey);
      }
      await p.setString('print_header', _header.text.trim());
      await p.setString('print_footer', _footer.text.trim());
      await p.setInt('print_paper', _paper);
      await p.setString('print_font', _font);
      await p.setString('print_mac', _mac!);

      if (!await PrintBluetoothThermal.connectionStatus) {
        final ok =
            await PrintBluetoothThermal.connect(macPrinterAddress: _mac!);
        if (!ok)
          throw 'Tidak bisa terhubung ke printer. Pastikan printer menyala dan dekat.';
      }
      final bytes = await _build(price);
      final sent = await PrintBluetoothThermal.writeBytes(bytes);
      await PrintBluetoothThermal.disconnect;
      if (!sent) throw 'Data gagal dikirim ke printer.';
      if (mounted) {
        Navigator.of(context).pop();
        showSnack(context, 'Nota dikirim ke printer.');
      }
    } catch (e) {
      if (mounted)
        showSnack(context, e is String ? e : 'Gagal mencetak. Coba lagi.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  // ------------------------------------------------------------------ ESC/POS
  static String _ascii(String s) =>
      s.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

  static List<String> _wrap(String text, int cols) {
    final out = <String>[];
    var line = '';
    for (final w in _ascii(text).split(RegExp(r'\s+'))) {
      var word = w;
      while (word.length > cols) {
        if (line.isNotEmpty) {
          out.add(line);
          line = '';
        }
        out.add(word.substring(0, cols));
        word = word.substring(cols);
      }
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= cols) {
        line += ' $word';
      } else {
        out.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) out.add(line);
    return out;
  }

  static List<String> _kv(String k, String v, int cols) {
    k = _ascii(k);
    v = _ascii(v);
    if (k.length + 1 + v.length <= cols)
      return ['$k${' ' * (cols - k.length - v.length)}$v'];
    return [k, ..._wrap(v, cols)];
  }

  Future<List<int>> _build(int price) async {
    final o = widget.order;
    final profile = await CapabilityProfile.load();
    final g =
        Generator(_paper == 80 ? PaperSize.mm80 : PaperSize.mm58, profile);
    // sisakan 1 kolom: printer yang menulis sampai kolom terakhir kadang menambah baris kosong
    final cols = _paper == 80 ? 47 : 31;
    const center = PosStyles(align: PosAlign.center);
    final head =
        _ascii(_header.text).isEmpty ? 'SAM TOPUP' : _ascii(_header.text);

    var b = <int>[];
    b += g.reset();
    for (final l in _wrap(head, cols ~/ 1)) {
      b += g.text(l,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2));
    }
    b += g.text(widget.topup ? 'NOTA ISI SALDO' : 'NOTA PEMBELIAN',
        styles: center);
    b += g.text('-' * cols);
    for (final l in _kv('Waktu', formatDateTime(o.createdAt), cols)) {
      b += g.text(l);
    }
    for (final l in _kv('No', o.invoice, cols)) {
      b += g.text(l);
    }
    if (!widget.topup) {
      for (final l in _kv('Game', o.game, cols)) {
        b += g.text(l);
      }
      for (final l in _kv('Item', o.product, cols)) {
        b += g.text(l);
      }
      for (final l in _kv('Tujuan', o.target, cols)) {
        b += g.text(l);
      }
    }
    for (final l in _kv('Status', _lunas ? 'LUNAS' : 'KASBON', cols)) {
      b += g.text(l, styles: const PosStyles(bold: true));
    }
    b += g.text('-' * cols);
    for (final l in _kv('HARGA', rupiah(price), cols)) {
      b += g.text(l, styles: const PosStyles(bold: true));
    }

    if (o.status == 'success' && o.note.trim().isNotEmpty) {
      b += g.text('-' * cols);
      b += g.text('SN / Catatan:');
      final big = _font == 'large';
      for (final l in _wrap(o.note, big ? cols ~/ 2 : cols)) {
        b += g.text(l,
            styles: big
                ? const PosStyles(
                    bold: true,
                    height: PosTextSize.size2,
                    width: PosTextSize.size2)
                : const PosStyles(bold: true));
      }
    }
    b += g.text('-' * cols);
    final foot =
        _footer.text.split('\n').expand((l) => _wrap(l, cols)).toList();
    if (foot.isNotEmpty) {
      for (final l in foot) {
        b += g.text(l, styles: center);
      }
    } else {
      b += g.text('Terima kasih', styles: center);
      b += g.text('samtopup.biz.id', styles: center);
    }
    b += g.feed(3);
    b += g.cut();
    return b;
  }

  // ---------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final valid = _devices.any((d) => d.macAdress == _mac);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
            color: p.primary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28))),
        child: const Row(
          children: [
            Icon(Icons.print_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Cetak',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Harga Jual', prefixText: 'Rp '),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Radio<bool>(
                      value: true,
                      groupValue: _lunas,
                      onChanged: (v) => setState(() => _lunas = v!)),
                  const Text('Lunas'),
                  const SizedBox(width: 14),
                  Radio<bool>(
                      value: false,
                      groupValue: _lunas,
                      onChanged: (v) => setState(() => _lunas = v!)),
                  const Text('Kasbon'),
                ],
              ),
              if (!widget.topup)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _savePrice,
                  onChanged: (v) => setState(() => _savePrice = v ?? false),
                  title: Text(
                      'Simpan atau perbarui harga jual ${widget.order.product} untuk transaksi berikutnya.',
                      style: const TextStyle(fontSize: 13.5)),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: valid ? _mac : null,
                isExpanded: true,
                hint: Text(_scanning ? 'Mencari...' : 'Perangkat Bluetooth'),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.print_outlined)),
                items: [
                  for (final d in _devices)
                    DropdownMenuItem(
                        value: d.macAdress,
                        child: Text(d.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _mac = v),
              ),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_info!,
                      style: TextStyle(
                          color: p.muted, fontSize: 12.5, height: 1.35)),
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _font,
                decoration: const InputDecoration(labelText: 'Font SN'),
                items: const [
                  DropdownMenuItem(
                      value: 'default', child: Text('Font Default')),
                  DropdownMenuItem(value: 'large', child: Text('Font Besar')),
                ],
                onChanged: (v) => setState(() => _font = v ?? 'default'),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => setState(() => _more = !_more),
                icon: Text('Pengaturan lainnya',
                    style: TextStyle(
                        color: p.primary, fontWeight: FontWeight.w700)),
                label: Icon(
                    _more
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: p.primary),
              ),
              if (_more) ...[
                DropdownButtonFormField<int>(
                  value: _paper,
                  decoration: const InputDecoration(labelText: 'Ukuran Kertas'),
                  items: const [
                    DropdownMenuItem(value: 58, child: Text('58mm')),
                    DropdownMenuItem(value: 80, child: Text('80mm')),
                  ],
                  onChanged: (v) => setState(() => _paper = v ?? 58),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _header,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Header',
                      hintText: 'Nama toko (kosong = SAM TOPUP)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footer,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Footer',
                      hintText:
                          'Contoh: Terima kasih, simpan nota ini (kosong = bawaan)'),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        Row(
          children: [
            TextButton(
                onPressed: _scanning || _printing ? null : _scan,
                child: const Text('CARI')),
            const Spacer(),
            TextButton(
                onPressed: _printing ? null : () => Navigator.of(context).pop(),
                child: const Text('BATAL')),
            TextButton(
              onPressed: _printing ? null : _print,
              child: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Text('CETAK'),
            ),
          ],
        ),
      ],
    );
  }
}
