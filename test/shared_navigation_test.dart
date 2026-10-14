import 'package:meterya_app/profile_menu.dart';
import 'package:meterya_app/billing_year_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/overview_frame.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'shared navigation changes section and returns directly to overview at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/me')
                  ? {
                      'csrf_token': 'csrf',
                      'workspaces': [
                        {
                          'id': 'ws',
                          'name': 'Hausanschluss',
                          'role': 'MODERATOR',
                        },
                        {'id': 'ws2', 'name': 'OG', 'role': 'MODERATOR'},
                      ],
                    }
                  : r.url.path.endsWith('/transitions')
                  ? []
                  : r.url.path.endsWith('/power-to-heat')
                  ? r.url.path.contains('/ws2/')
                        ? []
                        : [
                            {
                              'id': 'heat',
                              'name': 'WP',
                              'valid_from': '2026-10-01',
                              'net_point': 'p',
                              'house_point': 'p2',
                              'flags': [],
                              'grid_periods': [],
                              'total_periods': [],
                            },
                          ]
                  : [
                      {
                        'id': 'p',
                        'name': 'Haus',
                        'version': 1,
                        'readings': [],
                        'meter': {
                          'serial': '123',
                          'registers': [
                            {'id': 'i', 'direction': 'IMPORT', 'unit': 'kWh'},
                          ],
                        },
                      },
                    ],
            ),
            200,
          ),
        );
        final model = ViewModel(
          Repository(ApiService(client, Uri.parse('http://localhost'))),
        );
        await model.initialize();
        model.points = [
          ...model.points,
          Point('p2', 'Wasser', 'W-2', 1, [
            const Register('w', 'IMPORT', 'm³'),
          ], []),
        ];
        await tester.pumpWidget(MeteryaApp(model: model));
        await tester.pumpAndSettle();
        final nav = find.byType(
          width < 900 ? NavigationDrawer : NavigationRail,
        );
        Future<void> select(String label) async {
          if (width < 900) {
            await tester.tap(find.byTooltip('Menü öffnen'));
            await tester.pumpAndSettle();
          }
          await tester.tap(
            find.descendant(of: nav, matching: find.text(label)),
          );
          await tester.pumpAndSettle();
        }

        int selected() => width < 900
            ? [0, 5, 4, 6, if (model.hasHeatConfiguration) 1, 2].indexOf(
                tester
                    .widget<WorkspaceScaffold>(find.byType(WorkspaceScaffold))
                    .body
                    .selectedIndex,
              )
            : tester.widget<NavigationRail>(nav).selectedIndex!;
        await tester.ensureVisible(find.text('Haus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Haus'));
        await tester.pumpAndSettle();
        expect(
          width < 900 ? find.byTooltip('Menü öffnen') : nav,
          findsOneWidget,
        );
        expect(selected(), 2);
        await select('Einstellungen');
        expect(find.byType(BackButton), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
        expect(find.byType(ProfileMenu), findsOneWidget);
        expect(selected(), 5);
        await select('Einstellungen');
        expect(selected(), 5);
        await select('Wärmepumpe');
        expect(find.byType(BackButton), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
        expect(find.byType(ProfileMenu), findsOneWidget);
        await tester.tap(find.byTooltip('Profil'));
        await tester.pumpAndSettle();
        expect(find.text('Profil bearbeiten'), findsOneWidget);
        expect(find.text('Abmelden'), findsOneWidget);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(selected(), 4);
        await select('Einstellungen');
        expect(selected(), 5);
        await tester.tap(find.text('Zähler & Tarife'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Wärmepumpe'));
        await tester.pumpAndSettle();
        expect(selected(), 5);
        await select('Einstellungen');
        expect(find.text('Workspaces verwalten'), findsOneWidget);
        await select('Übersicht');
        await tester.pumpAndSettle();
        expect(find.text('Meine Zähler'), findsOneWidget);
        expect(selected(), 0);
        await select('Verbrauch & Kosten');
        expect(selected(), 2);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wasser · W-2').last);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .initialValue,
          'p2',
        );
        if (width == 1280) {
          expect(tester.getTopLeft(nav).dy, 0);
          expect(
            tester.getTopLeft(find.byType(DropdownButtonFormField<String>)).dx,
            greaterThan(tester.getTopLeft(nav).dx),
          );
        }
        for (final label in ['Ablesungen', 'Verlauf', 'Verbrauch & Kosten']) {
          await select(label);
          expect(find.byType(TabBar), findsNothing);
          expect(find.byType(BillingYearPicker), findsOneWidget);
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>),
                )
                .initialValue,
            'p2',
          );
          expect(
            find.text('Ablesung erfassen'),
            width < 900 ? findsNothing : findsOneWidget,
          );
        }
        await select('Übersicht');
        await tester.ensureVisible(find.text('Haus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Haus'));
        await tester.pumpAndSettle();
        await select('Übersicht');
        expect(find.text('Meine Zähler'), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(WorkspaceScaffold))).canPop(),
          isFalse,
        );
        await tester.ensureVisible(find.text('Haus'));
        await tester.tap(find.text('Haus'));
        await tester.pumpAndSettle();
        expect(
          Navigator.of(tester.element(find.byType(WorkspaceScaffold))).canPop(),
          isTrue,
        );
        await tester.tap(find.byKey(const ValueKey('workspace-switch')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, 'OG'),
        );
        await tester.pumpAndSettle();
        expect(model.workspace!.id, 'ws2');
        expect(
          find.descendant(of: nav, matching: find.text('Wärmepumpe')),
          findsNothing,
        );
        expect(find.text('Meine Zähler'), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(WorkspaceScaffold))).canPop(),
          isFalse,
        );
        await select('Einstellungen');
        expect(selected(), 4);
        expect(find.text('Workspaces verwalten'), findsOneWidget);
        expect(
          find.descendant(of: nav, matching: find.text('Vergleich')),
          findsNothing,
        );
        await select('Übersicht');
        await tester.tap(find.byKey(const ValueKey('workspace-switch')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, 'Hausanschluss'),
        );
        await tester.pumpAndSettle();
        if (width < 900) {
          await tester.tap(find.byTooltip('Menü öffnen'));
          await tester.pumpAndSettle();
        }
        expect(
          find.descendant(of: nav, matching: find.text('Wärmepumpe')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        model.dispose();
        client.close();
      },
    );
  }
}
