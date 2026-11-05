import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/mock_repository.dart';
import '../api/repository.dart';
import '../config.dart';
import '../models.dart';

/// Status global: tema, login, dan riwayat pesanan di perangkat.
class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  final ApiClient client = ApiClient();
  late final Repository repo;

  ThemeMode themeMode = ThemeMode.system;
  AppUser? user;
  List<Order> localOrders = [];

  AppState._(this.prefs) {
    repo = AppConfig.useMock ? MockRepository() : HttpRepository(client);
  }

  static Future<AppState> create() async {
    final s = AppState._(await SharedPreferences.getInstance());
    await s._restore();
    return s;
  }

  bool get loggedIn => user != null;

  Future<void> _restore() async {
    final t = prefs.getString('theme');
    themeMode = ThemeMode.values.firstWhere((m) => m.name == t, orElse: () => ThemeMode.system);

    try {
      final raw = prefs.getString('local_orders');
      if (raw != null) {
        localOrders = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      client.token = token;
      try {
        user = await repo.me();
      } on ApiException catch (e) {
        if (e.unauthorized) await _clearSession();
      } catch (_) {
        // Offline: biarkan token tetap tersimpan, coba lagi nanti.
      }
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await prefs.setString('theme', m.name);
    notifyListeners();
  }

  Future<void> _applyAuth(AuthResult r) async {
    client.token = r.token;
    user = r.user;
    await prefs.setString('token', r.token);
    notifyListeners();
  }

  Future<void> login(String username, String password) async =>
      _applyAuth(await repo.login(username, password));

  Future<void> register(String name, String username, String password, String whatsapp) async =>
      _applyAuth(await repo.register(
        name: name,
        username: username,
        password: password,
        whatsapp: whatsapp,
      ));

  Future<void> refreshUser() async {
    if (!loggedIn) return;
    try {
      user = await repo.me();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    client.token = null;
    user = null;
    await prefs.remove('token');
  }

  /// Simpan / perbarui pesanan di riwayat perangkat (maks. 50).
  Future<void> rememberOrder(Order o) async {
    localOrders.removeWhere((e) => e.invoice == o.invoice);
    localOrders.insert(0, o);
    if (localOrders.length > 50) localOrders = localOrders.sublist(0, 50);
    await prefs.setString('local_orders', jsonEncode(localOrders.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}

/// Akses [AppState] dari widget mana pun.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// Ikut membangun ulang saat status berubah.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Tanpa ikut membangun ulang (aman dipakai di initState).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
