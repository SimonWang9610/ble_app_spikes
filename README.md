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

| File | Role |
|---|---|
| `Ble/BleService.swift` | actor, the only code that touches the binding |
| `Models/AdapterModel.swift`, `NearbyModel.swift` | Bluetooth state; scanning while Nearby is visible |
| `Models/DeviceSession.swift` | the connected device: connection, auto-reconnect, subscriptions, one `CharacteristicState` per characteristic |
| `Models/SessionStore.swift` | holds the current session (outlives the Device screen) |
| `Models/DeviceLog.swift` | device events in plain words; API calls behind a switch |
| `Views/` | `NearbyView`, `DeviceView`, `CharacteristicSheet`, `LogPanel` |

Creating the project in the Xcode GUI instead: File → New → Project → iOS App (SwiftUI); File → Add
Package Dependencies → Add Local… → `dist/swift/BlePocSwift`; General → Frameworks → add
`CoreBluetooth`; add the `Sources/` files; add `NSBluetoothAlwaysUsageDescription` under Info.

## Flutter app

```sh
cd apps/flutter_app
open ios/Runner.xcworkspace   # once: Runner → Signing & Capabilities → your team
flutter run                   # with the device connected
```

| Folder | Role |
|---|---|
| `lib/src/ble/ble_service.dart` | the only code that touches the binding (repository) |
| `lib/src/log/` | `DeviceLog` repository blocs write to; `LogCubit` for the panel |
| `lib/src/adapter/` | `AdapterCubit`: initialize, Bluetooth state |
| `lib/src/nearby/` | `NearbyBloc`: scan while visible (`restartable`), filter |
| `lib/src/session/` | `SessionBloc`: connection, auto-reconnect, subscriptions; immutable `SessionState` / `CharState` |
| `lib/src/ui/` | `NearbyScreen`, `DeviceScreen`, `CharacteristicSheet`, `LogPanel` |

State uses `flutter_bloc`: repositories via `RepositoryProvider`, app-wide blocs in `main.dart`,
`NearbyBloc` owned by its screen. Rows use `BlocSelector`, so only the changed characteristic rebuilds.

## Simulator

The simulator has no Bluetooth, but both apps start there, which is enough to see the UI and the
binding's errors: `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` /
`flutter run` with a simulator open. The Flutter app excludes x86_64 for the simulator because the
package ships only arm64 simulator libs.

## Current state

On the simulator (no Bluetooth) both apps initialize and show "Bluetooth is not ready". On a device
with the fixture running, follow the walkthrough in `docs/test-plan.md`.
