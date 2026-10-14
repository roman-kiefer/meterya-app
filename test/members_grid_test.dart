import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/members_grid.dart';
import 'package:meterya_app/models.dart';

void main() {
  testWidgets('members and pending invites share a grid on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MembersGrid(
            members: const [
              WorkspaceMember('admin', 'admin@example.test', 'ADMIN'),
              WorkspaceMember('mod', 'mod@example.test', 'MODERATOR'),
              WorkspaceMember('guest', 'guest@example.test', 'GUEST'),
            ],
            invitations: [
              Invitation(
                'pending',
                'invited@example.test',
                'USER',
                'SENT',
                1,
                DateTime.now().add(const Duration(days: 2)),
              ),
            ],
            busy: false,
            systemAdmin: false,
            onMember: (_, _) {},
            onInvitation: (_, _) {},
            onDeleteInvitation: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('invited@example.test'), findsOneWidget);
    expect(find.text('Versendet'), findsOneWidget);
    expect(find.text('Nur Lesen'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuButton<String>>(
            find.byType(PopupMenuButton<String>).first,
          )
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('members and actionable API invitations are displayed directly', (
    tester,
  ) async {
    Future<void> showGrid(List<WorkspaceMember> members) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MembersGrid(
            members: members,
            invitations: [
              Invitation(
                'pending',
                'pending@example.test',
                'GUEST',
                'SENT',
                1,
                DateTime(2026, 12),
              ),
              Invitation(
                'revoked',
                'revoked@example.test',
                'USER',
                'REVOKED',
                1,
                DateTime(2026, 12),
              ),
            ],
            busy: false,
            systemAdmin: true,
            onMember: (_, _) {},
            onInvitation: (_, _) {},
            onDeleteInvitation: (_) {},
          ),
        ),
      ),
    );
    await showGrid(const [
      WorkspaceMember('member', 'member@example.test', 'USER'),
    ]);
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Angenommen'), findsNothing);
    expect(find.text('pending@example.test'), findsOneWidget);
    expect(find.text('revoked@example.test'), findsOneWidget);
    await showGrid(const []);
    expect(find.text('member@example.test'), findsNothing);
  });

  testWidgets('disabled member and invitation actions explain the reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MembersGrid(
            members: const [
              WorkspaceMember('admin', 'admin@example.test', 'ADMIN'),
            ],
            invitations: [
              Invitation(
                'revoked',
                'invite@example.test',
                'USER',
                'REVOKED',
                1,
                DateTime.now().add(const Duration(days: 2)),
              ),
            ],
            busy: false,
            systemAdmin: true,
            onMember: (_, _) => invoked = true,
            onInvitation: (_, _) => invoked = true,
            onDeleteInvitation: (_) => invoked = true,
          ),
        ),
      ),
    );
    final menus = find.byType(PopupMenuButton<String>);
    await tester.longPress(menus.first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Weise zuerst einem weiteren Mitglied'),
      findsOneWidget,
    );
    await tester.tap(menus.last);
    await tester.pumpAndSettle();
    expect(find.text('Einladung löschen'), findsOneWidget);
    expect(find.text('Erneut versenden'), findsNothing);
    expect(invoked, isFalse);
    expect(
      find.byTooltip(
        'Statusanzeige: Dieses Mitglied hat Zugriff. Rolle und Zugriff werden über das Aktionsmenü verwaltet.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  test(
    'guest can never record, moderator can manage but is not a system admin',
    () {
      expect(const Workspace('w', 'Home', 'GUEST').canRecord, isFalse);
      expect(const Workspace('w', 'Home', 'MODERATOR').isAdmin, isTrue);
      expect(const Workspace('w', 'Home', 'MODERATOR').isSystemAdmin, isFalse);
    },
  );
}
