import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/reading_history_view.dart';

void main() {
  testWidgets('annual footer uses billing year and selected register', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final point = Point(
      'p',
      'Meter',
      'serial',
      1,
      [
        const Register('i', 'IMPORT', 'kWh'),
        const Register('e', 'EXPORT', 'kWh'),
      ],
      [
        const Reading('2025-01-01', '100', 'i'),
        const Reading('2026-01-01', '4292.000001', 'i'),
        const Reading('2025-01-01', '200', 'e'),
      ],
      annual: [
        const AnnualSummary(2025, false, true, null, null, [], [
          AnnualPosition(
            'i',
            'IMPORT',
            'kWh',
            '4192.000001',
            '2025-01-01',
            '2026-01-01',
            null,
            false,
            true,
          ),
          AnnualPosition(
            'e',
            'EXPORT',
            'kWh',
            '3564.000002',
            '2025-01-01',
            '2025-10-01',
            null,
            true,
            false,
          ),
        ]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReadingHistoryView(point: point, year: 2025)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jahressumme'), findsOneWidget);
    expect(find.text('4192,000001 kWh'), findsOneWidget);
    expect(find.text('4292,000001 kWh'), findsNothing);
    await tester.tap(find.widgetWithText(Tab, 'Einspeisung'));
    await tester.pumpAndSettle();
    expect(find.text('Jahressumme bisher'), findsOneWidget);
    expect(find.text('3564,000002 kWh'), findsOneWidget);
    expect(find.text('4192,000001 kWh'), findsNothing);
    expect(find.text('Zeitanteilig geschätzt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('secondary month-start reading explains month-end priority', (
    tester,
  ) async {
    final point = Point(
      'p',
      'Meter',
      'serial',
      1,
      [const Register('i', 'IMPORT', 'kWh')],
      [
        const Reading('2026-02-01', '101', 'i', boundaryPriority: true),
        const Reading('2026-01-31', '100', 'i'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReadingHistoryView(point: point)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(
        'Für diese Monatsgrenze wird der Stand vom Monatsletzten verwendet.',
      ),
      findsOneWidget,
    );
    expect(find.text('101 kWh'), findsOneWidget);
    expect(find.text('100 kWh'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
  for (final width in [360.0, 1280.0]) {
    testWidgets('reading filters preserve cross-year differences at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final point = Point(
        'p',
        'Haus',
        '123',
        1,
        [
          const Register('i', 'IMPORT', 'kWh'),
          const Register('e', 'EXPORT', 'kWh'),
        ],
        [
          const Reading('2025-12-31', '100.000000', 'i'),
          const Reading(
            '2026-01-03',
            '110.000001',
            'i',
            difference: '10.000001',
          ),
          const Reading('2026-01-05', '120.000000', 'i'),
          const Reading('2024-12-31', '20.000000', 'e'),
        ],
        consumption: [
          const ConsumptionInterval(
            'i',
            '2025-12-31',
            '2026-01-03',
            '10.000001',
            'kWh',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReadingHistoryView(point: point)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('110,000001 kWh'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('120 kWh')).dy,
        lessThan(tester.getTopLeft(find.text('110,000001 kWh')).dy),
      );
      expect(find.text('10,000001 kWh'), findsOneWidget);
      expect(find.text('100 kWh'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025').last);
      await tester.pumpAndSettle();
      expect(find.text('100 kWh'), findsOneWidget);
      expect(find.text('110,000001 kWh'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Einspeisung'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('20 kWh'), findsOneWidget);
      expect(find.text('100 kWh'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReadingHistoryView(point: point, year: 2026)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 Ablesungen · 2026'), findsOneWidget);
      expect(find.text('20 kWh'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Bezug'));
      await tester.pumpAndSettle();
      expect(find.text('2 Ablesungen · 2026'), findsOneWidget);
      expect(find.text('Ablesedatum'), findsOneWidget);
      expect(find.text('110,000001 kWh'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
