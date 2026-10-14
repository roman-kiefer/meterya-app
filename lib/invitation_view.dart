import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'invitation_view_model.dart';
import 'l10n/app_localizations.dart';
import 'repository.dart';
import 'member_roles.dart';

class InvitationDialog extends StatefulWidget {
  final Repository repository;
  final String workspace;
  final bool allowAdmin;
  const InvitationDialog({
    super.key,
    required this.repository,
    required this.workspace,
    this.allowAdmin = false,
  });
  @override
  State<InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<InvitationDialog> {
  late final InvitationViewModel model;
  final email = TextEditingController();
  final form = GlobalKey<FormState>();
  String role = 'USER', key = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    model = InvitationViewModel(widget.repository, widget.workspace);
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => AlertDialog(
        title: Text(l.invitations),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (model.busy) const LinearProgressIndicator(),
                if (model.error != null)
                  Text(
                    model.error == 'MFA_REQUIRED'
                        ? l.mfaRequired
                        : l.genericError,
                  ),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: email,
                        enabled: !model.busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(labelText: l.email),
                        onChanged: (_) => key = const Uuid().v4(),
                        validator: (v) =>
                            v == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v.trim())
                            ? l.validationError
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: InputDecoration(labelText: l.role),
                        items: [
                          DropdownMenuItem(
                            value: 'USER',
                            child: Text(l.userRole),
                          ),
                          for (final value in [
                            'MODERATOR',
                            'GUEST',
                            if (widget.allowAdmin) 'ADMIN',
                          ])
                            DropdownMenuItem(
                              value: value,
                              child: Text(roleLabel(l, value)),
                            ),
                        ],
                        onChanged: model.busy
                            ? null
                            : (v) {
                                role = v!;
                                key = const Uuid().v4();
                              },
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: model.busy
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                if (await model.invite(
                                      email.text.trim(),
                                      role,
                                      key,
                                    ) &&
                                    mounted) {
                                  email.clear();
                                  key = const Uuid().v4();
                                }
                              },
                        child: Text(l.sendInvite),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (model.invitations.isEmpty && !model.busy)
                  Text(l.noInvitations),
                for (final invitation in model.invitations)
                  ListTile(
                    title: Text(invitation.email),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${roleLabel(l, invitation.role)} · ${invitationStatus(l, invitation.status, invitation.expires)}',
                        ),
                        Text(
                          '${l.expires}: ${invitation.expires.toLocal().toIso8601String().substring(0, 10)}',
                        ),
                        if (invitation.status != 'ACCEPTED' &&
                            invitation.status != 'REVOKED')
                          Wrap(
                            children: [
                              TextButton(
                                onPressed:
                                    model.busy ||
                                        DateTime.now().isAfter(
                                          invitation.expires,
                                        )
                                    ? null
                                    : () => model.change(invitation, false),
                                child: Text(l.retryInvite),
                              ),
                              TextButton(
                                onPressed: model.busy
                                    ? null
                                    : () => model.change(invitation, true),
                                child: Text(l.revokeInvite),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }
}
