# Paywall example

This is a standalone Flutter project for exercising the three packages in the
parent repository. Its path dependencies deliberately point at `../packages`;
run commands from this directory so those local packages and the native Example
hosts are the code under test.

## Entry points

| File | Demonstrates |
| --- | --- |
| `lib/main.dart` | Simple paywall, campaign countdown, legal links, and success state |
| `lib/main_intl.dart` | Simple paywall using `PaywallLocalizations` in English and German |
| `lib/main_moritz_intl.dart` | Moritz paywall using the same localized duration data |

The purchase handlers are intentionally local simulations: purchase and
restore enter the pending state for one second and then report `PURCHASED`.
They do not contact a store or spend real money.

## Bound toolchain

Use the parent App's verified Flutter 3.44.9 SDK:

```bash
../../../.fvm/flutter_sdk/bin/flutter pub get
../../../.fvm/flutter_sdk/bin/flutter test --no-pub
../../../.fvm/flutter_sdk/bin/flutter analyze --no-pub lib test
```

Android builds through the plugin DSL at compile/target SDK 36 and min SDK 24.
iOS builds through CocoaPods with one `FlutterSceneDelegate` scene and minimum
iOS 15. `test/upgrade/native_build_test.dart` performs both real debug builds
and checks the resulting APK and Simulator app metadata.

Visible legal-link presentation, real purchases/restores, signing, and device
layout behavior remain manual integration checks; widget and artifact tests do
not claim them.
