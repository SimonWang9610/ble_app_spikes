import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/adapter/adapter.dart';
import 'src/log/log_entries.dart';
import 'src/ui/log_panel.dart';
import 'src/ui/nearby_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native lib must load once before any other binding call.
  await initDartBinding();
  runApp(const ProviderScope(child: BlePocApp()));
}

class BlePocApp extends ConsumerWidget {
  const BlePocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start the log first, so it sees the adapter's first lines, then the adapter itself.
    ref.listen(logEntriesProvider, (_, _) {});
    ref.listen(adapterProvider, (_, _) {});
    return MaterialApp(
      title: 'BLE POC Flutter',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      // Wraps the navigator, so the log panel stays under every screen.
      builder: (context, navigator) => Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(context: context, removeBottom: true, child: navigator!),
          ),
          const LogPanel(),
        ],
      ),
      home: const NearbyScreen(),
    );
  }
}
