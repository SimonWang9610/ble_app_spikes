# BLE POC app spikes

Two iPhone/iPad apps that use the `hm_ble` bindings the way a user would (find nearby devices,
connect to one, read / write / subscribe, survive a dropped link), and a Mac fixture that plays the
peripheral, with a control page that mirrors the apps.

| Path | What |
|---|---|
| `fixture/` | Python + [bless](https://github.com/kevincar/bless) peripheral `HM-BLE-FIXTURE` |
| `apps/swift_app/` | SwiftUI app on `BlePocSwift` (BoltFFI) |
| `apps/flutter_app/` | Flutter app on `ble_poc_dart` (flutter_rust_bridge) |
| `docs/test-plan.md` | fixture GATT layout and the walkthrough |
| `docs/design-v2.md` | screens, state, reconnect rules, fixture page |

Bindings are used in place from
`/Users/WANGDX94/projects/rust-interoperability-poc/.worktree/ble-poc-foundation/dist`; rebuild them
there, then rebuild the apps.

## Setup

```sh
brew install xcodegen
python3 -m venv fixture/.venv && fixture/.venv/bin/pip install -r fixture/requirements.txt
```

## Fixture (Mac)

```sh
fixture/.venv/bin/python fixture/fixture.py
```

The first run asks for Bluetooth access for the terminal app; allow it in System Settings →
Privacy & Security → Bluetooth. The fixture logs every read, write, subscription and counter push.
Ctrl-C stops it.

Control page: http://127.0.0.1:8080 (this Mac only; `--port 0` turns it off). It shows the device,
its services and characteristics the way a phone sees them, with live state and log:

- device: Bluetooth, advertising, subscribed phones; turn Bluetooth off / on (drops every phone's
  link, needs `brew install blueutil`), start / stop advertising
- mock link drops: Bluetooth off for a few seconds on a repeating interval (also `blueutil`)
- VALUE: set the value phones get on their next read (nothing is sent)
- NOTIFY, INDICATE: each has its own counter, interval, pause; send the next counter or custom bytes
  now, to the phones subscribed to that characteristic

Turning Bluetooth off is a real link loss for the phone (and disconnects the Mac's other Bluetooth
devices). When it comes back on, the fixture publishes
and advertises again by itself.

Check it without the apps: nRF Connect or LightBlue on the iPhone. The Mac can't be its own central.

## Devices

Connect the iPhone/iPad by USB, trust the Mac, turn on Settings → Privacy & Security → Developer Mode,
and open Xcode → Window → Devices and Simulators once to pair it. `xcrun devicectl list devices`
should then list it as connected. On first launch, trust the developer profile under Settings →
General → VPN & Device Management.

## Swift app

```sh
cd apps/swift_app
xcodegen generate
open BlePocSwiftApp.xcodeproj
```

Pick your team under Signing & Capabilities, pick the device, Run. `project.yml` is the source of
truth; run `xcodegen generate` again after changing it or adding files.

Tests (Swift Testing, on a simulator, over the in-memory `FakeBle`):

```sh
xcodebuild -project BlePocSwiftApp.xcodeproj -scheme BlePocSwiftApp \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

| Path | Role |
|---|---|
| `Sources/App/` | `BlePocApp` owns the `Log` and the app-wide models and puts them in the environment; `RootView`: navigation stack above the log panel |
| `Sources/Core/Ble/` | `BleAdapter` / `DeviceLink` / `GattIO`; `BleService`, the actor that implements them and the only code that touches the binding; `AdapterModel` (Bluetooth state); `FakeBle` (debug only, for previews and tests) |
| `Sources/Core/Log/` | `Log`: device events in plain words, API calls behind a switch; `LogPanel` |
| `Sources/Core/Support/` | bytes and time formatting, fixture UUID labels, preview models |
| `Sources/Features/Nearby/` | `NearbyModel` scans while Nearby is visible; `NearbyView` |
| `Sources/Features/Device/` | `SessionStore` holds the current `DeviceSession`, which orders `Connection`, `Gatt`, `Characteristic`, `Subscriptions` and `Reconnector`; `DeviceView`, `CharacteristicSheet` (one operation) |
| `Tests/` | bytes, fixture, scanning, connect / subscribe / reconnect / disconnect |

Creating the project in the Xcode GUI instead: File → New → Project → iOS App (SwiftUI); File → Add
Package Dependencies → Add Local… → `dist/swift/BlePocSwift`; General → Frameworks → add
`CoreBluetooth`; add the `Sources/` files; add `NSBluetoothAlwaysUsageDescription` under Info.

## Flutter app

```sh
cd apps/flutter_app
open ios/Runner.xcworkspace   # once: Runner → Signing & Capabilities → your team
dart run build_runner build   # after changing a provider (the generated *.g.dart files are committed)
flutter run                   # with the device connected
```

| Folder | Role |
|---|---|
| `lib/src/ble/` | `BleAdapter` / `DeviceLink` / `GattIO` and the `BleService` that implements them (the only code that touches the binding) |
| `lib/src/log/` | `Log` singleton (`Log.event`, `Log.api`, …) and the panel's `logEntriesProvider` |
| `lib/src/adapter/` | initialize, Bluetooth state |
| `lib/src/nearby/` | scan while Nearby is visible, filter |
| `lib/src/session/` | `DeviceSession` coordinator and its parts: current device, connection, reconnector, gatt, characteristic, subscriptions |
| `lib/src/ui/` | `NearbyScreen`, `DeviceScreen`, `OperationSheet`, `LogPanel` |

State uses Riverpod with code generation. `main()` loads the binding before `runApp`. App-wide providers
are kept alive; Nearby's is disposed with its screen. Session providers watch the current device and free
their watcher, streams and timers in `ref.onDispose` when it is cleared. Each row watches only its own characteristic, so
only the changed row rebuilds.

## Simulator

The simulator has no Bluetooth, but both apps start there, which is enough to see the UI and the
binding's errors: `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` /
`flutter run` with a simulator open. The Flutter app excludes x86_64 for the simulator because the
package ships only arm64 simulator libs.

## Current state

On the simulator (no Bluetooth) both apps initialize and show "Bluetooth is not ready". On a device
with the fixture running, follow the walkthrough in `docs/test-plan.md`.
