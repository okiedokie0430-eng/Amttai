import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/theme.dart';

class AmttaiBridgeApp extends ConsumerStatefulWidget {
  const AmttaiBridgeApp({super.key});

  @override
  ConsumerState<AmttaiBridgeApp> createState() => _AmttaiBridgeAppState();
}

class _AmttaiBridgeAppState extends ConsumerState<AmttaiBridgeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchdogProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(watchdogProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final syncEngine = ref.watch(syncEngineProvider);
    final watchdog = ref.watch(watchdogProvider);

    return MaterialApp(
      title: 'Amttai Payment Bridge',
      debugShowCheckedModeBanner: false,
      theme: BridgeTheme.dark,
      home: DashboardScreen(db: db, syncEngine: syncEngine, watchdog: watchdog),
    );
  }
}
