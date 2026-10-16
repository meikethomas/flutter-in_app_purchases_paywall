# In App Purchases Paywall for Flutter

Our goal is to provide and develop useful in app purchase / subscription packages for the community.

We try to create a package suite that work smoothly in combination.

## Current Packages
### Paywall UI
* Github: [In App Purchases Paywall UI](/packages/in_app_purchases_paywall_ui)
* pub.dev: [Purchases Paywall Package](https://pub.dev/packages/in_app_purchases_paywall_ui)

### Interface
* Github: [In App Purchases Interface](/packages/in_app_purchases_interface)
* pub.dev: [Interface Package](https://pub.dev/packages/in_app_purchases_interface)

### Intl
* Github: [In App Purchases Intl](/packages/in_app_purchases_intl)
* pub.dev: [Interface Package](https://pub.dev/packages/in_app_purchases_intl)

### Subscription Management for flutter
* Github: [LinkFive Purchases](https://github.com/LinkFive/flutter-purchases-sdk)
* pub.dev: [LinkFive Purchases Package](https://pub.dev/packages/linkfive_purchases)

## Flutter 3.44.9 upgrade

The `upgrade/flutter-3.44.9` branch keeps the three packages independently
resolvable while aligning the UI package's sibling Git dependencies. Direct
dependency decisions are recorded here because the package locks contain many
Flutter-SDK-controlled transitive packages.

| Package | Dependency | Before | After | Reason |
| --- | --- | --- | --- | --- |
| Interface | `flutter` | SDK | SDK | No external runtime dependency to update. |
| Interface | `flutter_test` | SDK | SDK | Test framework remains bound to Flutter 3.44.9. |
| Intl | `flutter` | SDK | SDK | Remains SDK-provided. |
| Intl | `flutter_localizations` | SDK | SDK | Supplies the SDK-compatible Intl pin. |
| Intl | `intl` | `>=0.19.0 <0.21.0` | `^0.20.2` | Flutter 3.44.9 resolves 0.20.2; 0.20.3 is incompatible with the SDK pin. |
| Intl | `flutter_test` | SDK | SDK | Test framework remains SDK-provided. |
| Intl | `lints` | `^2.1.0` | `^6.1.0` | Latest stable compatible lint rules; requires Dart 3.8 or newer. |
| Paywall UI | `flutter` | SDK | SDK | Remains SDK-provided. |
| Paywall UI | `flutter_inappwebview` | `^6.1.5` | `^6.1.5` | 6.1.5 remains the latest stable release. |
| Paywall UI | `in_app_purchases_interface` | Git `master_upgrade` | Git `upgrade/flutter-3.44.9` | Aligns the sibling with the target upgrade branch. |
| Paywall UI | `url_launcher` | `^6.3.2` | `^6.3.3` | Latest stable release; its Dart 3.11/Flutter 3.41 floors are reflected in this package. |
| Paywall UI | `in_app_purchases_intl` | Git `master_upgrade` | Git `upgrade/flutter-3.44.9` | Aligns the sibling with the target upgrade branch. |
| Paywall UI | `responsive_spacing` | `^1.1.0` | `^1.1.0` | Already the latest stable release. |
| Paywall UI | `flutter_test` | SDK | SDK | Test framework remains SDK-provided. |
| Paywall UI | `flutter_lints` | `^2.0.2` | removed | Unused; analysis includes `package:lints/recommended.yaml`. |
| Paywall UI | `lints` | `^2.1.1` | `^6.1.0` | Latest stable rules used by the existing analysis configuration. |

The Intl package now declares Dart 3.8 or newer for `lints` 6.1.0. The UI
package declares Dart 3.11 and Flutter 3.41 or newer for `url_launcher` 6.3.3.
The upgrade is validated with Flutter 3.44.9 / Dart 3.12.2.

### Upgrade evidence

- Baseline: `c63a21d720ea24d5130cac823536c1ebf385248a`
- Git-consumer-verified implementation commit:
  `3af4b2437b7c63237449883c8565454a87b802f7`
- The final evidence/documentation commit follows that implementation commit;
  its remote branch SHA is recorded in the MMB-0010 result artifact.
- Package resolution: separate online and offline locked checks for Interface,
  Intl, and Paywall UI
- Regression coverage: legal-link visibility/dispatch, callback forwarding,
  loading-to-success state, three locales with English fallback, and nine
  ISO-8601 duration cases
- Analyzer boundary: zero errors and zero external deprecation diagnostics;
  existing style infos and the publish warning for intentional Git dependencies
  are documented in the story result
- Canonical review: `mmb0010_marker_tests`, `mmb0010_targeted_tests`,
  `mmb0010_acceptance_contract`, and `mmb0010_review_hardening` pass; the
  targeted suites select 3 UI cases, 9 duration cases, and 1 localization case
- Device boundary: real iOS ChromeSafariBrowser presentation remains a manual
  device check; widget tests verify platform dispatch without opening a browser
