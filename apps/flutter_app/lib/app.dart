import 'package:flutter/material.dart';
import 'package:flutter_app/core/ble/adapter.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/log/application/log_entries.dart';
import 'package:flutter_app/features/log/presentation/log_panel.dart';
import 'package:flutter_app/features/nearby/presentation/nearby_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlePocApp extends ConsumerWidget {
  const BlePocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start the log first, so it sees the adapter's first lines, then the adapter itself.
    ref.listen(logEntriesProvider, (_, _) {});
    ref.listen(adapterProvider, (_, _) {});
    return MaterialApp(
      title: 'BLE POC Flutter',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
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
