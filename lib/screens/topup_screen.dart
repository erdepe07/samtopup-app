import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'order_screen.dart';

/// Isi saldo: pilih nominal + metode, lalu lanjut ke layar pembayaran.
class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  static const _quick = [10000, 20000, 50000, 100000, 200000, 500000];

  TopupInfo? _info;
  String? _error;
  int? _amount;
  String? _method;
  bool _busy = false;
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final i = await AppScope.read(context).repo.topupInfo();
      if (mounted) setState(() => _info = i);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final info = _info!;
    final a = _amount ?? 0;
    if (a < info.min) return showSnack(context, 'Minimal isi saldo ${rupiah(info.min)}.');
    if (a > info.max) return showSnack(context, 'Maksimal isi saldo ${rupiah(info.max)}.');
    if (_method == null) return showSnack(context, 'Pilih metode pembayaran.');
    setState(() => _busy = true);
    try {
      final o = await AppScope.read(context).repo.createTopup(a, _method!);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderScreen(invoice: o.invoice, initial: o, topup: true)),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('Isi Saldo', style: TextStyle(fontWeight: FontWeight.w800))),
      body: info == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                const SectionTitle('Nominal'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in _quick)
                      ChoiceChip(
                        label: Text(rupiah(n)),
                        selected: _amount == n,
                        onSelected: (_) => setState(() {
                          _amount = n;
                          _custom.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Nominal lain',
                    prefixText: 'Rp ',
                    helperText: 'Min ${rupiah(info.min)} · Maks ${rupiah(info.max)}',
                  ),
                  onChanged: (v) => setState(() => _amount = int.tryParse(v)),
                ),
                const SizedBox(height: 20),
                const SectionTitle('Metode pembayaran'),
                if (info.methods.isEmpty)
                  Text('Belum ada metode yang tersedia.', style: TextStyle(color: p.muted))
                else
                  for (final m in info.methods)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _method = m.code),
                        child: SoftCard(
                          child: Row(
                            children: [
                              if (m.image.isNotEmpty) ...[
                                RemoteImage(url: m.image, width: 44, height: 30, radius: 6, fit: BoxFit.contain),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(m.group, style: TextStyle(color: p.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(
                                _method == m.code ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: _method == m.code ? p.primary : p.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(_amount != null && _amount! > 0 ? 'Lanjut bayar ${rupiah(_amount!)}' : 'Lanjut bayar'),
                ),
                const SizedBox(height: 10),
                Text('Saldo bertambah otomatis setelah pembayaran diterima.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ),
    );
  }
}
