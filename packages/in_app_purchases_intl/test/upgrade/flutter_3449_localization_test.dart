import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchases_intl/in_app_purchases_intl.dart';

void main() {
  group('MMB0014_source_cleanup_regression', () {
    testWidgets('MMB0010_locales_and_english_fallback', (tester) async {
      const expectedWeekly = <String, String>{
        'de': 'wöchentlich',
        'en': 'weekly',
        'es': 'semanal',
      };

      expect(
        PaywallLocalizations.supportedLocales.map(
          (locale) => locale.languageCode,
        ),
        orderedEquals(expectedWeekly.keys),
      );

      for (final locale in PaywallLocalizations.supportedLocales) {
        expect(PaywallLocalizations.delegate.isSupported(locale), isTrue);
        final localizations = await PaywallLocalizations.delegate.load(locale);
        expect(localizations.localeName, locale.languageCode);
        expect(localizations.weekly, expectedWeekly[locale.languageCode]);
      }

      late PaywallLocalizations fallback;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              fallback = PaywallL10NHelper.of(context);
              return Text(fallback.nday(2));
            },
          ),
        ),
      );

      expect(fallback.localeName, 'en');
      expect(find.text('2 days'), findsOneWidget);
    });
  });
}
