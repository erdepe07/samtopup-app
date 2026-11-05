import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'topup_history_screen.dart';
import 'topup_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _register = false;
  bool _busy = false;
  final _password2 = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _whatsapp = TextEditingController();

  @override
  void dispose() {
    _password2.dispose();
    _username.dispose();
    _password.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppScope.read(context);
    final wa = _whatsapp.text.trim();
    if (_username.text.trim().isEmpty)
      return showSnack(context, 'Username tidak boleh kosong.');
    if (_register) {
      if (wa.isEmpty)
        return showSnack(context, 'No. Whatsapp tidak boleh kosong.');
      if (wa.length < 10 || wa.length > 14)
        return showSnack(context, 'No. Whatsapp tidak sesuai.');
      if (!wa.startsWith('08'))
        return showSnack(context, 'No. Whatsapp harus diawali 08.');
    }
    if (_password.text.isEmpty)
      return showSnack(context, 'Password tidak boleh kosong.');
    if (_register) {
      if (_password.text.length < 6)
        return showSnack(context, 'Password minimal 6 karakter.');
      if (_password.text.length > 24)
        return showSnack(context, 'Password maksimal 24 karakter.');
      if (_password2.text != _password.text)
        return showSnack(context, 'Konfirmasi password tidak sesuai.');
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        await app.register(
            _username.text.trim(), wa, _password.text, _password2.text);
      } else {
        await app.login(_username.text.trim(), _password.text);
      }
      _password.clear();
      _password2.clear();
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
      appBar: AppBar(
          title: const Text('Akun',
              style: TextStyle(fontWeight: FontWeight.w800))),
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
                  u.name.isEmpty
                      ? '?'
                      : String.fromCharCode(u.name.runes.first).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
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
              Text(rupiah(u.balance),
                  style: TextStyle(
                      color: p.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TopupScreen()));
            if (mounted) AppScope.read(context).refreshUser();
          },
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Isi Saldo'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder()),
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TopupHistoryScreen())),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Riwayat Isi Saldo',
              style: TextStyle(fontWeight: FontWeight.w800)),
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
          label: const Text('Keluar',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _authForm(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(_register ? 'Register Member' : 'Masuk'),
        Text(
          'Masuk untuk memakai saldo member dan melihat riwayat di semua perangkat. Anda tetap bisa membeli tanpa akun.',
          style: TextStyle(color: p.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        if (_register) ...[
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'No. Whatsapp', hintText: '08xxxxxxxxxx'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password')),
        if (_register) ...[
          const SizedBox(height: 12),
          TextField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Ulangi Password')),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
              : Text(_register ? 'Register Akun' : 'Masuk'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _register = !_register),
            child: Text(
                _register
                    ? 'Sudah memiliki akun? Login'
                    : 'Belum punya akun? Daftar',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
