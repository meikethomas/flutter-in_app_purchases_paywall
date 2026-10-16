import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';
import 'package:in_app_purchases_paywall_ui/paywall/inherit/paywall_data_iw.dart';
import 'package:in_app_purchases_paywall_ui/paywall/inherit/subscription_callback_iw.dart';
import 'package:in_app_purchases_paywall_ui/paywall/model/paywall_data.dart';
import 'package:in_app_purchases_paywall_ui/paywall/simple/legal_row.dart';

void main() {
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
}

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
