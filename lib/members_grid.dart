import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'member_roles.dart';
import 'models.dart';

/// One table for memberships and invitations awaiting resolution. Horizontal scrolling
/// keeps identities, status and actions aligned on narrow screens.
class MembersGrid extends StatelessWidget {
  final List<WorkspaceMember> members;
  final List<Invitation> invitations;
  final bool busy, systemAdmin;
  final void Function(WorkspaceMember, String?) onMember;
  final void Function(Invitation, bool) onInvitation;
  final ValueChanged<Invitation> onDeleteInvitation;
  const MembersGrid({
    super.key,
    required this.members,
    required this.invitations,
    required this.busy,
    required this.systemAdmin,
    required this.onMember,
    required this.onInvitation,
    required this.onDeleteInvitation,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final managers = members
        .where((m) => m.active && (m.role == 'ADMIN' || m.role == 'MODERATOR'))
        .length;
    String? memberDisabledReason(WorkspaceMember member) {
      if (busy) return l.memberActionsBusy;
      if (!systemAdmin && (member.role == 'ADMIN' || member.systemAdmin)) {
        return l.memberActionsAdminOnly;
      }
      if (member.active &&
          managers == 1 &&
          (member.role == 'ADMIN' || member.role == 'MODERATOR')) {
        return l.memberActionsLastManager;
      }
      return null;
    }

    String? invitationDisabledReason(Invitation invitation) {
      if (busy) return l.memberActionsBusy;
      if (invitation.status != 'REVOKED' &&
          !systemAdmin &&
          invitation.role == 'ADMIN') {
        return l.memberActionsAdminOnly;
      }
      return null;
    }

    Widget actionMenu({
      required String? disabledReason,
      required PopupMenuItemBuilder<String> items,
      required ValueChanged<String> onSelected,
    }) => Tooltip(
      message: disabledReason ?? l.memberActions,
      child: PopupMenuButton<String>(
        tooltip: '',
        enabled: disabledReason == null,
        onSelected: onSelected,
        itemBuilder: items,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.more_horiz,
            color: disabledReason == null
                ? null
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );

    Widget status(
      String text, {
      bool active = false,
      bool inactive = false,
    }) => Chip(
      label: Text(
        text,
        style: inactive
            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
      ),
      avatar: Icon(
        active
            ? Icons.check_circle_outline
            : inactive
            ? Icons.pause_circle_outline
            : Icons.mail_outline,
        size: 16,
        color: inactive ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      ),
      visualDensity: VisualDensity.compact,
    );
    final rows = <DataRow>[
      for (final m in members)
        DataRow(
          key: ValueKey(m.subject),
          cells: [
            DataCell(SelectableText(m.email)),
            DataCell(Text(roleLabel(l, m.role))),
            DataCell(
              Text(
                !m.active && !m.systemAdmin
                    ? l.memberNoAccess
                    : roleAccess(l, m.systemAdmin ? 'ADMIN' : m.role),
              ),
            ),
            DataCell(
              Tooltip(
                message: m.active ? l.memberActiveHelp : l.memberInactiveHelp,
                child: status(
                  m.active ? l.memberActive : l.memberInactive,
                  active: m.active,
                  inactive: !m.active,
                ),
              ),
            ),
            DataCell(
              actionMenu(
                disabledReason: memberDisabledReason(m),
                onSelected: (role) =>
                    onMember(m, role == 'REMOVE' ? null : role),
                items: (_) => [
                  for (final role in [
                    if (systemAdmin) 'ADMIN',
                    ...workspaceRoles,
                  ])
                    if (role != m.role)
                      PopupMenuItem(
                        value: role,
                        child: Text(roleLabel(l, role)),
                      ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: m.active ? 'DEACTIVATE' : 'ACTIVATE',
                    child: Text(
                      m.active ? l.deactivateMember : l.activateMember,
                    ),
                  ),
                  PopupMenuItem(value: 'REMOVE', child: Text(l.removeMember)),
                ],
              ),
            ),
          ],
        ),
      for (final i in invitations)
        DataRow(
          key: ValueKey(i.id),
          cells: [
            DataCell(SelectableText(i.email)),
            DataCell(Text(roleLabel(l, i.role))),
            DataCell(Text(roleAccess(l, i.role))),
            DataCell(
              Tooltip(
                message:
                    '${l.invitationStatusHelp(invitationStatus(l, i.status, i.expires))}\n${l.expires}: ${MaterialLocalizations.of(context).formatMediumDate(i.expires.toLocal())}',
                child: status(invitationStatus(l, i.status, i.expires)),
              ),
            ),
            DataCell(
              actionMenu(
                disabledReason: invitationDisabledReason(i),
                onSelected: (action) => action == 'DELETE'
                    ? onDeleteInvitation(i)
                    : onInvitation(i, action == 'REVOKE'),
                items: (_) => [
                  if (i.status == 'REVOKED')
                    PopupMenuItem(value: 'DELETE', child: Text(l.deleteInvite))
                  else ...[
                    if (!DateTime.now().isAfter(i.expires))
                      PopupMenuItem(value: 'RETRY', child: Text(l.retryInvite)),
                    PopupMenuItem(value: 'REVOKE', child: Text(l.revokeInvite)),
                  ],
                ],
              ),
            ),
          ],
        ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 68,
              columns: [
                DataColumn(label: Text(l.email)),
                DataColumn(label: Text(l.role)),
                DataColumn(label: Text(l.memberAccess)),
                DataColumn(label: Text(l.memberStatus)),
                DataColumn(label: Text(l.memberActions)),
              ],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}
