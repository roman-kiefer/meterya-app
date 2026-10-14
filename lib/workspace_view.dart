import 'package:flutter/material.dart';
import 'conflict_reload.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'view_model.dart';
import 'navigation.dart';
import 'member_roles.dart';
import 'members_grid.dart';
import 'invitation_view.dart';

class CreateWorkspaceDialog extends StatefulWidget {
  final ViewModel model;
  const CreateWorkspaceDialog({super.key, required this.model});
  @override
  State<CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<CreateWorkspaceDialog> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  String key = const Uuid().v4();
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final m = widget.model;
      return AlertDialog(
        title: Text(l.createWorkspace),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.createWorkspaceHelp),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  autofocus: true,
                  enabled: !m.busy,
                  decoration: InputDecoration(labelText: l.name),
                  onChanged: (_) => key = const Uuid().v4(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.validationError
                      : null,
                ),
                if (m.error != null)
                  Text(
                    errorText(l, m.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: m.busy ? null : () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          if (!m.signedIn || m.error == 'MFA_REQUIRED')
            FilledButton(
              onPressed: () => navigate('/auth/login?mfa=1'),
              child: Text(l.login),
            )
          else
            FilledButton(
              onPressed: m.busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final ok = await m.createWorkspace(name.text.trim(), key);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
              child: Text(l.save),
            ),
        ],
      );
    },
  );
}

class MembersPanel extends StatefulWidget {
  final ViewModel model;
  final Workspace workspace;
  const MembersPanel({super.key, required this.model, required this.workspace});
  @override
  State<MembersPanel> createState() => _MembersPanelState();
}

class _MembersPanelState extends State<MembersPanel> {
  Memberships? data;
  List<Invitation> invitations = [];
  late String workspaceId;
  Workspace get selected => widget.model.workspace ?? widget.workspace;
  bool get allowed =>
      widget.model.signedIn &&
      widget.model.workspaces.any((w) => w.id == selected.id && w.isAdmin);
  @override
  void initState() {
    super.initState();
    workspaceId = selected.id;
    widget.model.addListener(workspaceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  void workspaceChanged() {
    if (workspaceId == selected.id) return;
    workspaceId = selected.id;
    data = null;
    invitations = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    widget.model.removeListener(workspaceChanged);
    super.dispose();
  }

  Future<void> load() async {
    final id = selected.id;
    if (!allowed) {
      if (mounted) {
        setState(() {
          data = null;
          invitations = [];
        });
      }
      return;
    }
    Memberships? loaded;
    List<Invitation> pending = [];
    final ok = await widget.model.run(() async {
      loaded = await widget.model.repository.members(id);
      pending = await widget.model.repository.invitations(id);
    });
    if (mounted && selected.id == id) {
      setState(() {
        data = ok ? loaded : null;
        invitations = ok ? pending : [];
      });
    }
  }

  Future<void> invite() async {
    await showDialog<void>(
      context: context,
      builder: (_) => InvitationDialog(
        repository: widget.model.repository,
        workspace: selected.id,
        allowAdmin: selected.isSystemAdmin,
      ),
    );
    if (mounted) await load();
  }

  Future<void> changeInvitation(
    Invitation invitation,
    bool revoke, {
    bool delete = false,
  }) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          delete
              ? l.deleteInvite
              : revoke
              ? l.revokeInvite
              : l.retryInvite,
        ),
        content: Text(
          delete ? l.deleteInviteHelp(invitation.email) : invitation.email,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              delete
                  ? l.deleteInvite
                  : revoke
                  ? l.revokeInvite
                  : l.retryInvite,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.model.run(
      () => delete
          ? widget.model.repository.deleteInvite(selected.id, invitation)
          : widget.model.repository.changeInvite(
              selected.id,
              invitation,
              revoke,
            ),
    );
    if (ok && mounted) await load();
  }

  Future<void> change(WorkspaceMember member, String? role) async {
    final l = AppLocalizations.of(context);
    final activity = role == 'ACTIVATE' || role == 'DEACTIVATE';
    final activating = role == 'ACTIVATE';
    final actionLabel = activity
        ? (activating ? l.activateMember : l.deactivateMember)
        : (role == null ? l.removeMember : l.changeMemberRole);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionLabel),
        content: Text(
          activity
              ? (activating
                    ? l.activateMemberHelp(member.email)
                    : l.deactivateMemberHelp(member.email))
              : role == null
              ? l.removeMemberHelp(member.email)
              : l.changeMemberRoleHelp(member.email, roleLabel(l, role)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              activity
                  ? actionLabel
                  : role == null
                  ? l.removeMember
                  : l.save,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = activity
        ? await widget.model.setMemberActive(
            selected.id,
            member,
            data!.version,
            const Uuid().v4(),
            activating,
          )
        : await widget.model.manageMember(
            selected.id,
            member,
            data!.version,
            const Uuid().v4(),
            role: role,
          );
    if (!mounted) return;
    if (ok) {
      if (allowed) {
        await load();
      } else {
        setState(() => data = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final m = widget.model;
      final lastAdmin =
          data?.members
              .where(
                (member) =>
                    member.active &&
                    (member.role == 'ADMIN' || member.role == 'MODERATOR'),
              )
              .length ==
          1;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.memberOverview, style: Theme.of(context).textTheme.titleLarge),
          Text(l.memberOverviewHelp),
          const SizedBox(height: 16),
          if (allowed)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: m.busy ? null : invite,
                icon: const Icon(Icons.person_add_outlined),
                label: Text(l.invitations),
              ),
            ),
          const SizedBox(height: 16),
          if (m.busy) const LinearProgressIndicator(),
          if (m.error != null)
            Text(
              errorText(l, m.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ConflictReload(
            error: m.error,
            busy: m.busy || !allowed,
            onReload: load,
          ),
          if (!m.signedIn || m.error == 'MFA_REQUIRED')
            FilledButton(
              onPressed: () => navigate('/auth/login?mfa=1'),
              child: Text(l.login),
            )
          else if (!allowed)
            Text(l.permissionError)
          else if (data != null) ...[
            if (lastAdmin) Text(l.lastWorkspaceAdmin),
            MembersGrid(
              members: data!.members,
              invitations: invitations,
              busy: m.busy,
              systemAdmin: selected.isSystemAdmin,
              onMember: change,
              onInvitation: changeInvitation,
              onDeleteInvitation: (invitation) =>
                  changeInvitation(invitation, false, delete: true),
            ),
          ],
        ],
      );
    },
  );
}
