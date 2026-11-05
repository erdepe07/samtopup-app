import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _register = false;
  bool _busy = false;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _whatsapp = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppScope.read(context);
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      return showSnack(context, 'Isi username dan password.');
    }
    if (_register && _name.text.trim().isEmpty) {
      return showSnack(context, 'Isi nama Anda.');
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        await app.register(_name.text.trim(), _username.text.trim(), _password.text, _whatsapp.text.trim());
      } else {
        await app.login(_username.text.trim(), _password.text);
      }
      _password.clear();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Akun', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (app.loggedIn) _profile(app, p) else _authForm(p),
          const SizedBox(height: 24),
          const SectionTitle('Tampilan'),
          SoftCard(
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Otomatis')),
                ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profile(AppState app, Palette p) {
    final u = app.user!;
    return Column(
      children: [
        SoftCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: p.primary,
                child: Text(
                  u.name.isEmpty ? '?' : String.fromCharCode(u.name.runes.first).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text('@${u.username}', style: TextStyle(color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: p.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('Saldo', style: TextStyle(color: p.muted))),
              Text(rupiah(u.balance), style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Isi saldo dilakukan lewat website.', style: TextStyle(color: p.muted, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: const StadiumBorder(),
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFDC2626)),
          ),
          onPressed: () => app.logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _authForm(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(_register ? 'Buat akun' : 'Masuk'),
        Text(
          'Masuk untuk memakai saldo member dan melihat riwayat di semua perangkat. Anda tetap bisa membeli tanpa akun.',
          style: TextStyle(color: p.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_register) ...[
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 12),
        ],
        TextField(controller: _username, autocorrect: false, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        if (_register) ...[
          const SizedBox(height: 12),
          TextField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp (opsional)')),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(_register ? 'Daftar' : 'Masuk'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _register = !_register),
            child: Text(_register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
