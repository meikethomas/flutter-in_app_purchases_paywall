import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:example/main.dart' as simple_demo;
import 'package:example/main_intl.dart' as intl_demo;
import 'package:example/main_moritz_intl.dart' as moritz_demo;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchases_intl/in_app_purchases_intl.dart';
import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';

const _testViewSize = Size(430, 932);

void main() {
  group('MMB0014_source_cleanup_regression', () {
    testWidgets('MMB0012_demo_entrypoints_render_paywall', (tester) async {
      _configureTestView(tester);

      await _pumpDemo(tester, simple_demo.MyApp(), locale: const Locale('en'));
      expect(find.byType(PaywallScaffold), findsOneWidget);
      expect(find.byType(SimplePaywall), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Go Premium'), findsOneWidget);
      await _disposeDemo(tester);

      await _pumpDemo(tester, intl_demo.MyApp(), locale: const Locale('en'));
      expect(find.byType(PaywallScaffold), findsOneWidget);
      expect(find.byType(SimplePaywall), findsOneWidget);
      expect(find.text('week'), findsOneWidget);
      expect(find.text('Go Premium'), findsOneWidget);
      await _disposeDemo(tester);

      await _pumpDemo(tester, moritz_demo.MyApp(), locale: const Locale('en'));
      expect(find.byType(PaywallScaffold), findsOneWidget);
      expect(find.byType(MoritzPaywall), findsOneWidget);
      expect(find.text('YourApp Premium'), findsOneWidget);
      expect(
        find.text(
          'Enjoy all the advantages of YourApp with the Premium subscription.',
        ),
        findsOneWidget,
      );
      await _disposeDemo(tester);
    });

    testWidgets('MMB0012_localized_demos_use_paywall_localizations', (
      tester,
    ) async {
      _configureTestView(tester);

      for (final locale in const <Locale>[Locale('en'), Locale('de')]) {
        final expected = await PaywallLocalizations.delegate.load(locale);

        await _pumpDemo(tester, intl_demo.MyApp(), locale: locale);
        final simpleContext = tester.element(find.byType(SimplePaywall));
        final simpleLocalizations = PaywallL10NHelper.of(simpleContext);
        expect(simpleLocalizations.localeName, locale.languageCode);
        expect(simpleLocalizations.week, expected.week);
        expect(find.text(expected.week), findsOneWidget);
        expect(find.text(expected.yearly.toTitleCase()), findsOneWidget);
        expect(find.text(expected.restore_purchase), findsOneWidget);
        await _disposeDemo(tester);

        await _pumpDemo(tester, moritz_demo.MyApp(), locale: locale);
        final moritzContext = tester.element(find.byType(MoritzPaywall));
        final moritzLocalizations = PaywallL10NHelper.of(moritzContext);
        expect(moritzLocalizations.localeName, locale.languageCode);
        expect(moritzLocalizations.month, expected.month);
        expect(find.text('/${expected.month}'), findsNWidgets(2));
        expect(find.text(expected.restore_purchase), findsOneWidget);
        await _disposeDemo(tester);
      }
    });

    testWidgets('MMB0012_demo_purchase_restore_preserve_pending_success', (
      tester,
    ) async {
      final handlerFactories = <String, DefaultPurchaseHandler Function()>{
        'main.dart': simple_demo.PurchaseHandler.new,
        'main_intl.dart': intl_demo.PurchaseHandler.new,
        'main_moritz_intl.dart': moritz_demo.PurchaseHandler.new,
      };
      final product = SubscriptionData(
        durationTitle: 'Monthly',
        durationShort: '1 month',
        price: '€1.99',
        productDetails: 'MMB0012 fixture',
      );
      final operations = <_HandlerOperation>[];
      for (final entry in handlerFactories.entries) {
        final purchaseHandler = entry.value();
        operations.add(
          _HandlerOperation(
            source: '${entry.key} purchase',
            handler: purchaseHandler,
            invoke: () => purchaseHandler.purchase(product),
          ),
        );
        final restoreHandler = entry.value();
        operations.add(
          _HandlerOperation(
            source: '${entry.key} restore',
            handler: restoreHandler,
            invoke: restoreHandler.restore,
          ),
        );
      }

      for (final operation in operations) {
        operation.listen();
      }
      try {
        await tester.pump();
        for (final operation in operations) {
          operation.expectInitialState();
        }

        final results = <bool>[];
        for (final operation in operations) {
          unawaited(operation.invoke().then(results.add));
        }
        await tester.pump();
        for (final operation in operations) {
          operation.expectPendingState();
        }

        await tester.pump(const Duration(milliseconds: 999));
        for (final operation in operations) {
          operation.expectPendingState();
        }

        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();
        expect(results, hasLength(operations.length));
        expect(results, everyElement(isTrue));
        for (final operation in operations) {
          operation.expectPurchasedState();
        }
      } finally {
        for (final operation in operations) {
          operation.cancel();
        }
        await tester.pump();
      }
    });

    test('MMB0012_example_uses_local_fork_packages', () {
      final packageConfig = File('.dart_tool/package_config.json').absolute;
      expect(
        packageConfig.existsSync(),
        isTrue,
        reason: 'Run Flutter 3.44.9 pub get in the example before testing.',
      );

      final decoded = jsonDecode(packageConfig.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final packages = (decoded as Map<String, dynamic>)['packages'];
      expect(packages, isA<List<dynamic>>());
      final packageEntries = packages as List<dynamic>;

      const packageNames = <String>[
        'in_app_purchases_interface',
        'in_app_purchases_intl',
        'in_app_purchases_paywall_ui',
      ];
      for (final packageName in packageNames) {
        final entries = packageEntries.where(
          (entry) =>
              entry is Map<String, dynamic> && entry['name'] == packageName,
        );
        expect(
          entries,
          hasLength(1),
          reason: 'package_config must contain $packageName exactly once.',
        );

        final entry = entries.single as Map<String, dynamic>;
        final rootUri = entry['rootUri'];
        expect(rootUri, isA<String>());
        final resolvedRoot = Directory.fromUri(
          packageConfig.parent.uri.resolve(rootUri as String),
        );
        expect(
          resolvedRoot.existsSync(),
          isTrue,
          reason: '$packageName rootUri does not resolve to a directory.',
        );

        final expectedRoot = Directory('../packages/$packageName');
        expect(
          resolvedRoot.resolveSymbolicLinksSync(),
          expectedRoot.resolveSymbolicLinksSync(),
          reason: '$packageName must resolve to the sibling package checkout.',
        );
      }
    });

    test('MMB0012_native_toolchain_pins_match_target', () {
      final settings = _readFile('android/settings.gradle');
      final rootBuild = _readFile('android/build.gradle');
      final appBuild = _readFile('android/app/build.gradle');
      final wrapper = _readProperties(
        File('android/gradle/wrapper/gradle-wrapper.properties'),
      );
      final manifest = _readFile('android/app/src/main/AndroidManifest.xml');

      expect(
        settings,
        contains(
          r'includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")',
        ),
      );
      _expectPluginVersion(
        settings,
        'dev.flutter.flutter-plugin-loader',
        '1.0.0',
      );
      _expectPluginVersion(
        settings,
        'com.android.application',
        '8.10.1',
        applyFalse: true,
      );
      _expectPluginVersion(
        settings,
        'org.jetbrains.kotlin.android',
        '2.1.21',
        applyFalse: true,
      );

      for (final pluginId in const <String>[
        'com.android.application',
        'org.jetbrains.kotlin.android',
        'dev.flutter.flutter-gradle-plugin',
      ]) {
        _expectPluginDeclaration(appBuild, pluginId);
      }

      expect(settings, isNot(contains('app_plugin_loader.gradle')));
      expect(appBuild, isNot(contains('apply from:')));
      expect(appBuild, isNot(contains('flutter.gradle')));
      expect(appBuild, isNot(contains('kotlin-stdlib-jdk7')));
      expect(rootBuild, isNot(contains('classpath')));
      expect(rootBuild, isNot(contains('jcenter()')));
      expect(rootBuild, contains('mavenCentral()'));

      expect(wrapper['distributionUrl'], contains('gradle-8.11.1-all.zip'));
      expect(
        appBuild,
        matches(RegExp(r'''namespace\s*=\s*["']io\.linkfive\.example["']''')),
      );
      expect(
        appBuild,
        matches(
          RegExp(r'''applicationId\s*=\s*["']io\.linkfive\.example["']'''),
        ),
      );
      expect(
        appBuild,
        matches(RegExp(r'compileSdk\s*=\s*flutter\.compileSdkVersion')),
      );
      expect(appBuild, matches(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion')));
      expect(appBuild, matches(RegExp(r'targetSdk\s*=\s*36\b')));
      expect(
        appBuild,
        matches(RegExp(r'sourceCompatibility\s*=\s*JavaVersion\.VERSION_17')),
      );
      expect(
        appBuild,
        matches(RegExp(r'targetCompatibility\s*=\s*JavaVersion\.VERSION_17')),
      );
      expect(
        appBuild,
        matches(
          RegExp(r'jvmTarget\s*=\s*JavaVersion\.VERSION_17\.toString\(\)'),
        ),
      );
      expect(
        RegExp(r'<manifest[^>]*\spackage\s*=').hasMatch(manifest),
        isFalse,
        reason: 'Android package identity belongs in namespace/applicationId.',
      );
    });
  });
}

void _configureTestView(WidgetTester tester) {
  tester.view.physicalSize = _testViewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpDemo(
  WidgetTester tester,
  Widget app, {
  required Locale locale,
}) async {
  tester.platformDispatcher.localeTestValue = locale;
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
}

Future<void> _disposeDemo(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

class _HandlerOperation {
  _HandlerOperation({
    required this.source,
    required this.handler,
    required this.invoke,
  });

  final String source;
  final DefaultPurchaseHandler handler;
  final Future<bool> Function() invoke;
  final List<bool> pendingValues = <bool>[];
  final List<PurchaseState> purchaseStates = <PurchaseState>[];
  late final StreamSubscription<bool> _pendingSubscription;
  late final StreamSubscription<PurchaseState> _stateSubscription;

  void listen() {
    _pendingSubscription = handler.purchaseInProgressStream().listen(
      pendingValues.add,
    );
    _stateSubscription = handler.purchaseStateStream().listen(
      purchaseStates.add,
    );
  }

  void expectInitialState() {
    expect(pendingValues, <bool>[false], reason: source);
    expect(purchaseStates, <PurchaseState>[
      PurchaseState.NOT_PURCHASED,
    ], reason: source);
  }

  void expectPendingState() {
    expect(pendingValues.last, isTrue, reason: source);
    expect(
      purchaseStates.last,
      PurchaseState.NOT_PURCHASED,
      reason: '$source must not succeed before its delay ends.',
    );
  }

  void expectPurchasedState() {
    expect(pendingValues.last, isFalse, reason: source);
    expect(purchaseStates.last, PurchaseState.PURCHASED, reason: source);
  }

  void cancel() {
    unawaited(_pendingSubscription.cancel());
    unawaited(_stateSubscription.cancel());
  }
}

String _readFile(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing file: $path');
  return file.readAsStringSync();
}

Map<String, String> _readProperties(File file) {
  expect(file.existsSync(), isTrue, reason: 'Missing file: ${file.path}');
  final properties = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final separator = line.indexOf('=');
    if (separator <= 0 || line.trimLeft().startsWith('#')) {
      continue;
    }
    properties[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return properties;
}

void _expectPluginDeclaration(String source, String pluginId) {
  final pattern = RegExp(
    r'''id\s+["']''' + RegExp.escape(pluginId) + r'''["']''',
  );
  expect(source, matches(pattern), reason: 'Missing app plugin: $pluginId');
}

void _expectPluginVersion(
  String source,
  String pluginId,
  String version, {
  bool applyFalse = false,
}) {
  final applyClause = applyFalse ? r'\s+apply\s+false' : '';
  final pattern = RegExp(
    r'''id\s+["']''' +
        RegExp.escape(pluginId) +
        r'''["']\s+version\s+["']''' +
        RegExp.escape(version) +
        r'''["']''' +
        applyClause,
  );
  expect(
    source,
    matches(pattern),
    reason: '$pluginId must be pinned to $version.',
  );
}
