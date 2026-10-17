import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/l10n/app_localizations_en.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'package:meterya_app/year_comparison_model.dart';

void main() {
  test('English translations cover every German message and placeholder', () {
    Map<String, dynamic> arb(String language) =>
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
    final de = arb('de');
    final en = arb('en');
    final keys = de.keys.where((key) => !key.startsWith('@')).toSet();
    expect(en.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    for (final key in keys) {
      expect(en[key], isNotEmpty, reason: key);
      final metadata = de['@$key'] as Map<String, dynamic>?;
      final placeholders = metadata?['placeholders'] as Map<String, dynamic>?;
      for (final name in placeholders?.keys ?? <String>[]) {
        expect(en[key], contains('{$name'), reason: '$key: $name');
      }
    }
  });

  for (final scenario in <(List<Locale>, String, String)>[
    ([const Locale('de', 'DE')], 'de', 'Anmelden'),
    ([const Locale('en', 'US')], 'en', 'Sign in'),
    ([const Locale('en', 'GB')], 'en', 'Sign in'),
    ([const Locale('fr', 'FR')], 'en', 'Sign in'),
    ([], 'en', 'Sign in'),
    ([const Locale('fr'), const Locale('de')], 'de', 'Anmelden'),
    ([const Locale('fr'), const Locale('en')], 'en', 'Sign in'),
    ([const Locale('de'), const Locale('en')], 'de', 'Anmelden'),
  ]) {
    testWidgets('app resolves browser languages ${scenario.$1}', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = scenario.$1;
      final client = MockClient((_) async => http.Response('{}', 200));
      addTearDown(client.close);
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('https://example.test'))),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(MeteryaApp(model: model));
      await tester.pumpAndSettle();
      expect(find.text(scenario.$3), findsOneWidget);
      final context = tester.element(find.byType(Home));
      expect(AppLocalizations.of(context).localeName, scenario.$2);
      expect(Localizations.localeOf(context).languageCode, scenario.$2);
    });
  }

  test('English ICU messages retain plural, select and fallback behaviour', () {
    final l = AppLocalizationsEn();
    expect(l.readingEntryCount(1, 2026), '1 reading · 2026');
    expect(l.readingEntryCount(2, 2026), '2 readings · 2026');
    expect(l.auditAction('ReadingCorrected'), 'Reading corrected');
    expect(l.auditAction('FUTURE_EVENT'), 'Other event');
    expect(l.auditObjectKind('virtual'), 'Virtual meter');
    expect(l.photoError('PHOTO_MISSING'), contains('missing'));
    expect(l.backupConfirmLabel, contains(l.backupConfirmWord));
  });

  test(
    'English decimal formatting preserves exact readings and large money',
    () {
      expect(displayQuantity('123.456789', locale: 'en'), '123.456789');
      expect(displayQuantity('123.450000', locale: 'en'), '123.45');
      expect(displayQuantity('123.000000', locale: 'en'), '123');
      expect(displayQuantity('123.456789', locale: 'de'), '123,456789');
      expect(
        displayEuros('1234567890123456789', locale: 'en'),
        '12345678901234567.89 €',
      );
      expect(displayEuros('-1', locale: 'en'), '−0.01 €');
      expect(displayUnitPrice(8200, locale: 'en'), '0.082');
      expect(
        YearComparisonModel.formatQuantity('1.235000', locale: 'en'),
        '1.24',
      );
      expect(normalizeReading('123.456789'), '123.456789');
      expect(normalizeReading('123,456789'), '123.456789');
    },
  );
}
