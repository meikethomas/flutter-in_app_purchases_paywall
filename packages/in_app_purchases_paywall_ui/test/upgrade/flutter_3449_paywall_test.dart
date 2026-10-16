import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';
import 'package:in_app_purchases_paywall_ui/paywall/inherit/paywall_data_iw.dart';
import 'package:in_app_purchases_paywall_ui/paywall/inherit/subscription_callback_iw.dart';
import 'package:in_app_purchases_paywall_ui/paywall/model/paywall_data.dart';
import 'package:in_app_purchases_paywall_ui/paywall/simple/legal_row.dart';

void main() {
  group('MMB0014_source_cleanup_regression', () {
    testWidgets('MMB0010_legal_links_visibility_and_destinations', (
      tester,
    ) async {
      final platform = _RecordingInAppWebViewPlatform();
      InAppWebViewPlatform.instance = platform;

      await _pumpLegalRow(
        tester,
        tosData: const TextAndUrl('Terms', 'https://example.com/terms'),
      );
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsNothing);
      await tester.tap(find.text('Terms'));
      await tester.pump();
      _expectOpen(platform.opens.single, 'https://example.com/terms');

      platform.opens.clear();
      await _pumpLegalRow(
        tester,
        ppData: const TextAndUrl('Privacy', 'https://example.com/privacy'),
      );
      expect(find.text('Terms'), findsNothing);
      expect(find.text('Privacy'), findsOneWidget);
      await tester.tap(find.text('Privacy'));
      await tester.pump();
      _expectOpen(platform.opens.single, 'https://example.com/privacy');

      platform.opens.clear();
      await _pumpLegalRow(
        tester,
        tosData: const TextAndUrl('Terms', 'https://example.com/terms'),
        ppData: const TextAndUrl('Privacy', 'https://example.com/privacy'),
      );
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      await tester.tap(find.text('Terms'));
      await tester.pump();
      await tester.tap(find.text('Privacy'));
      await tester.pump();
      expect(
        platform.opens.map((open) => open.url.toString()),
        orderedEquals(const <String>[
          'https://example.com/terms',
          'https://example.com/privacy',
        ]),
      );

      platform.opens.clear();
      await _pumpLegalRow(tester);
      expect(find.text('Terms'), findsNothing);
      expect(find.text('Privacy'), findsNothing);
      expect(platform.opens, isEmpty);
    });

    test('MMB0010_purchase_and_restore_forward_once', () async {
      final callback = _RecordingCallback();
      final product = SubscriptionData(
        durationTitle: 'Monthly',
        durationShort: 'month',
        price: '€1.99',
        productDetails: Object(),
      );
      final inherited = SubscriptionCallbackIW(
        callbackInterface: callback,
        subscriptionListData: <SubscriptionData>[product],
        child: const SizedBox.shrink(),
      );

      inherited.onPurchase(product);
      inherited.onRestoreTap();
      await Future<void>.delayed(Duration.zero);

      expect(callback.purchaseCalls, 1);
      expect(callback.restoreCalls, 1);
      expect(callback.purchasedProduct, same(product));
    });

    testWidgets('MMB0010_loading_to_success_preserves_state', (tester) async {
      final handler = DefaultPurchaseHandler(
        initialPurchaseState: PurchaseState.NOT_PURCHASED,
        initialIsPurchaseInProgress: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePaywall(
              title: 'Purchase state',
              successTitle: 'Success state',
              callbackInterface: handler,
              purchaseStateStreamInterface: handler,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Purchase state'), findsOneWidget);
      expect(find.text('Success state'), findsNothing);

      handler.isPendingPurchase = true;
      await tester.pump();
      expect(find.text('Purchase state'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      handler.purchaseState = PurchaseState.PURCHASED;
      await tester.pump();
      expect(find.text('Purchase state'), findsNothing);
      expect(find.text('Success state'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      handler.isPendingPurchase = false;
      await tester.pump();
      expect(find.text('Success state'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('MMB0010_compact_paywall_content_remains_bounded', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePaywall(
              title: 'Compact paywall',
              bulletPoints: const <IconAndText>[
                IconAndText(
                  Icons.article_outlined,
                  'Access to All Premium Articles',
                ),
              ],
              tosData: const TextAndUrl(
                'Terms of Service',
                'https://example.com/terms',
              ),
              ppData: const TextAndUrl(
                'Privacy Policy',
                'https://example.com/privacy',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Access to All Premium Articles'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoritzPaywall(
              title: 'Compact Moritz paywall',
              subTitle: 'All premium advantages',
              continueText: 'Continue',
              bulletPoints: const <IconAndText>[
                IconAndText(
                  Icons.article_outlined,
                  'Access to All Premium Articles',
                ),
              ],
              subscriptionListData: <SubscriptionData>[
                SubscriptionData(
                  durationTitle: 'Yearly',
                  durationShort: '12 months',
                  price: '€14.99',
                  dealPercentage: 59,
                  productDetails: 'yearly',
                  currencySymbol: '€',
                  rawPrice: 14.99,
                  monthText: 'month',
                  duration: 'P1Y',
                  index: 0,
                ),
                SubscriptionData(
                  durationTitle: 'Monthly',
                  durationShort: '1 month',
                  price: '€2.99',
                  dealPercentage: 0,
                  productDetails: 'monthly',
                  currencySymbol: '€',
                  rawPrice: 2.99,
                  monthText: 'month',
                  duration: 'P1M',
                  index: 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Access to All Premium Articles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('MMB0014_cleaned_paywall_sibling_sources_are_exercised', () {
      final packageDirectory = Directory.current.absolute;
      final forkRoot = packageDirectory.parent.parent;
      final expectedPackageDirectory = Directory.fromUri(
        forkRoot.uri.resolve('packages/in_app_purchases_paywall_ui/'),
      );
      expect(
        _canonicalDirectory(packageDirectory),
        _canonicalDirectory(expectedPackageDirectory),
        reason: 'Run the test from the canonical Paywall UI package.',
      );
      expect(
        _git(forkRoot, const ['remote', 'get-url', 'origin']),
        _paywallRepositoryUrl,
      );

      final packageConfig = File.fromUri(
        packageDirectory.uri.resolve('.dart_tool/package_config.json'),
      );
      expect(
        packageConfig.existsSync(),
        isTrue,
        reason: 'Resolve the UI package with Flutter 3.44.9 before testing.',
      );
      final decoded = jsonDecode(packageConfig.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final packages = (decoded as Map<String, dynamic>)['packages'];
      expect(packages, isA<List<dynamic>>());

      final resolutions = <_SiblingResolution>{};
      for (final packageName in const [
        'in_app_purchases_interface',
        'in_app_purchases_intl',
      ]) {
        resolutions.add(
          _expectSiblingPackageTree(
            packageName: packageName,
            packageEntries: packages as List<dynamic>,
            packageConfig: packageConfig,
            forkRoot: forkRoot,
          ),
        );
      }
      expect(
        resolutions,
        hasLength(1),
        reason:
            'Interface and Intl must both resolve locally during development '
            'or both resolve from verified Pub Git-cache checkouts.',
      );
    });
  });
}

const _paywallRepositoryUrl =
    'https://github.com/meikethomas/flutter-in_app_purchases_paywall.git';

enum _SiblingResolution { local, gitCache }

_SiblingResolution _expectSiblingPackageTree({
  required String packageName,
  required List<dynamic> packageEntries,
  required File packageConfig,
  required Directory forkRoot,
}) {
  final entries = packageEntries.where(
    (entry) => entry is Map<String, dynamic> && entry['name'] == packageName,
  );
  expect(
    entries,
    hasLength(1),
    reason: 'package_config must contain $packageName exactly once.',
  );
  final rootUri = (entries.single as Map<String, dynamic>)['rootUri'];
  expect(rootUri, isA<String>());
  final resolvedRoot = Directory.fromUri(
    packageConfig.parent.uri.resolve(rootUri as String),
  );
  expect(
    resolvedRoot.existsSync(),
    isTrue,
    reason: '$packageName rootUri does not resolve to a directory.',
  );

  final packagePath = 'packages/$packageName';
  final expectedLocalRoot = Directory.fromUri(
    forkRoot.uri.resolve('$packagePath/'),
  );
  if (_canonicalDirectory(resolvedRoot) ==
      _canonicalDirectory(expectedLocalRoot)) {
    return _SiblingResolution.local;
  }

  expect(
    _git(forkRoot, ['status', '--porcelain', '--', packagePath]),
    isEmpty,
    reason:
        '$packageName has unpublished local changes and must resolve from the '
        'canonical sibling checkout.',
  );

  final resolvedRepository = Directory(
    _git(resolvedRoot, const ['rev-parse', '--show-toplevel']),
  );
  final expectedResolvedRoot = Directory.fromUri(
    resolvedRepository.uri.resolve('$packagePath/'),
  );
  expect(
    _canonicalDirectory(resolvedRoot),
    _canonicalDirectory(expectedResolvedRoot),
    reason: '$packageName must use its canonical repository package path.',
  );

  final checkoutOrigin = _git(resolvedRepository, const [
    'remote',
    'get-url',
    'origin',
  ]);
  final bareCache = Directory(checkoutOrigin);
  expect(
    bareCache.existsSync(),
    isTrue,
    reason: '$packageName must resolve from a Pub Git-cache checkout.',
  );
  expect(_directoryName(bareCache.parent), 'cache');
  expect(
    _canonicalDirectory(bareCache.parent.parent),
    _canonicalDirectory(resolvedRepository.parent),
    reason: '$packageName checkout and bare cache must share the Pub cache.',
  );
  expect(_git(bareCache, const ['rev-parse', '--is-bare-repository']), 'true');
  expect(
    _git(bareCache, const ['remote', 'get-url', 'origin']),
    _paywallRepositoryUrl,
  );
  expect(
    _git(resolvedRepository, ['status', '--porcelain', '--', packagePath]),
    isEmpty,
    reason: '$packageName Git-cache sources must be unmodified.',
  );

  final expectedTree = _git(forkRoot, ['rev-parse', 'HEAD:$packagePath']);
  final resolvedTree = _git(resolvedRepository, [
    'rev-parse',
    'HEAD:$packagePath',
  ]);
  expect(
    resolvedTree,
    expectedTree,
    reason: '$packageName must exercise the cleaned package tree.',
  );
  return _SiblingResolution.gitCache;
}

String _git(Directory workingDirectory, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: workingDirectory.path,
  );
  expect(
    result.exitCode,
    0,
    reason:
        'git ${arguments.join(' ')} failed in ${workingDirectory.path}: '
        '${result.stderr}',
  );
  return (result.stdout as String).trim();
}

String _canonicalDirectory(Directory directory) =>
    directory.resolveSymbolicLinksSync();

String _directoryName(Directory directory) =>
    directory.uri.pathSegments.where((segment) => segment.isNotEmpty).last;

Future<void> _pumpLegalRow(
  WidgetTester tester, {
  TextAndUrl? tosData,
  TextAndUrl? ppData,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PaywallDataIW(
          paywallData: PaywallData(tosData: tosData, ppData: ppData),
          child: const LegalRow(),
        ),
      ),
    ),
  );
}

void _expectOpen(_BrowserOpen open, String expectedUrl) {
  expect(open.url.toString(), expectedUrl);
  expect(open.settings, isNotNull);
  expect(open.settings!.barCollapsingEnabled, isTrue);
  expect(open.settings!.enableUrlBarHiding, isTrue);
  expect(open.settings!.shareState, CustomTabsShareState.SHARE_STATE_OFF);
}

class _RecordingCallback implements CallbackInterface {
  int purchaseCalls = 0;
  int restoreCalls = 0;
  SubscriptionData? purchasedProduct;

  @override
  Future<bool> purchase(SubscriptionData productDetails) async {
    purchaseCalls += 1;
    purchasedProduct = productDetails;
    return true;
  }

  @override
  Future<bool> restore() async {
    restoreCalls += 1;
    return true;
  }
}

class _RecordingInAppWebViewPlatform extends InAppWebViewPlatform {
  final List<_BrowserOpen> opens = <_BrowserOpen>[];

  @override
  PlatformChromeSafariBrowser createPlatformChromeSafariBrowser(
    PlatformChromeSafariBrowserCreationParams params,
  ) {
    return _RecordingChromeSafariBrowser(params, opens);
  }
}

class _RecordingChromeSafariBrowser extends PlatformChromeSafariBrowser {
  _RecordingChromeSafariBrowser(super.params, this.opens)
    : super.implementation();

  final List<_BrowserOpen> opens;

  @override
  Future<void> open({
    WebUri? url,
    Map<String, String>? headers,
    List<WebUri>? otherLikelyURLs,
    WebUri? referrer,
    // ignore: deprecated_member_use
    ChromeSafariBrowserClassOptions? options,
    ChromeSafariBrowserSettings? settings,
  }) async {
    opens.add(_BrowserOpen(url: url, settings: settings));
  }
}

class _BrowserOpen {
  const _BrowserOpen({required this.url, required this.settings});

  final WebUri? url;
  final ChromeSafariBrowserSettings? settings;
}
