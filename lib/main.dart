import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.create();
  runApp(AppScope(state: state, child: const SamTopupApp()));
}

class SamTopupApp extends StatelessWidget {
  const SamTopupApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: app.themeMode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Shell(),
    );
  }
}
