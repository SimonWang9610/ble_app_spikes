import 'package:ble_poc_dart/ble_poc_dart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native lib must load once before any other binding call.
  await initDartBinding();
  runApp(const ProviderScope(child: BlePocApp()));
}
