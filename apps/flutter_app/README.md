# flutter_app

iPhone/iPad app that drives the `hm_ble` Dart binding (`ble_poc_dart`, flutter_rust_bridge) against the
`HM-BLE-FIXTURE` peripheral: scan, connect, read / write / subscribe, and reconnect after a dropped link.
State is Riverpod with code generation.

## Layout

```text
lib/
  main.dart               loads the native binding, starts the ProviderScope
  app.dart                MaterialApp, theme, log panel under every screen
  core/
    ble/                  BleService (the only code that calls the binding) behind
                          BleAdapter / DeviceLink / GattIO, and the adapter state
    log/                  Logger and loggerProvider
    fixture/              fixture name and UUID labels
    theme/                light/dark themes, AppColors extension, mono text style
    utils/                bytes, errors, time format
    widgets/              shared widgets
  features/
    nearby/               scanning and the Nearby screen
    device/               domain (keys, status, operations), session notifiers, Device screen and sheets
    log/                  log panel state and widget
test/
  helpers/fake_ble.dart   scripted fake for the three BLE interfaces
```

`core` never imports `features`. Inside a feature, `presentation` reads `application` (the notifiers),
which reads `domain` and `core`. Nearby uses the device feature to open a session.

## Run

The binding is a path dependency on the `ble-poc-foundation` worktree (see the repo README); rebuild it
there first.

```sh
flutter pub get
flutter run            # on a connected iPhone/iPad
```

## Develop

```sh
dart run build_runner build -d   # after changing a @riverpod class
flutter analyze
flutter test
```

Generated `*.g.dart` files are committed; regenerate them instead of formatting them by hand.
