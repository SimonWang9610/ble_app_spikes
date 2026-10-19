import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/adapter/adapter_cubit.dart';
import 'src/ble/ble_service.dart';
import 'src/log/device_log.dart';
import 'src/log/log_cubit.dart';
import 'src/nearby/nearby_bloc.dart';
import 'src/session/session_bloc.dart';
import 'src/ui/log_panel.dart';
import 'src/ui/nearby_screen.dart';

void main() => runApp(const BlePocApp());

class BlePocApp extends StatelessWidget {
  const BlePocApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Repositories (plain objects the blocs share), then the app-wide blocs that use them.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => BleService()),
        RepositoryProvider(create: (_) => DeviceLog()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => LogCubit(context.read<DeviceLog>()), lazy: false),
          BlocProvider(create: (context) => AdapterCubit(context.read(), context.read())..start(), lazy: false),
          BlocProvider(create: (context) => SessionBloc(context.read(), context.read())),
        ],
        child: MaterialApp(
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
          // Nearby's bloc belongs to its screen.
          home: BlocProvider(
            create: (context) => NearbyBloc(context.read(), context.read()),
            child: const NearbyScreen(),
          ),
        ),
      ),
    );
  }
}
