import 'virtual_point_dialog.dart';
import 'move_point_dialog.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'view_model.dart';
import 'overview_frame.dart';
import 'navigation.dart';
import 'workspace_view.dart';
import 'backup_view.dart';
import 'transition_view.dart';
import 'heat_view.dart';
import 'tariff_view.dart';
import 'point_detail_view.dart';
import 'conflict_reload.dart';

class SettingsView extends StatefulWidget {
  final ViewModel model;
  const SettingsView({super.key, required this.model});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // TabBarView reparents pages during non-adjacent tab transitions. Preserve
  // the loaded members while shared model notifications rebuild the tabs.
  final membersKey = GlobalKey();
  ViewModel get model => widget.model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final workspace = model.signedIn ? model.workspace : null;
      final admin = workspace?.isAdmin == true;
      final allowed = admin || model.workspaces.any((w) => w.isSystemAdmin);
      if (model.signedIn && !allowed) {
        return WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            model: model,
            title: Text(l.settings),
            showBillingYear: false,
            automaticallyImplyLeading: false,
          ),
          body: AppNavigationFrame(
            model: model,
            selectedIndex: 2,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.settingsAccessDenied),
              ),
            ),
          ),
        );
      }
      return DefaultTabController(
        length: 3,
        child: WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            showBillingYear: false,
            automaticallyImplyLeading: false,
            model: model,
            title: Text(l.settings),
          ),
          body: AppNavigationFrame(
            model: model,
            selectedIndex: 2,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!model.signedIn) ...[
                      ..._status(context),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: FilledButton(
                          onPressed: model.busy
                              ? null
                              : () => navigate(
                                  model.workspace?.isAdmin == true
                                      ? '/auth/login?mfa=1'
                                      : '/auth/login',
                                ),
                          child: Text(l.login),
                        ),
                      ),
                    ] else ...[
                      if (workspace != null && !admin)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(l.settingsReadOnly),
                        ),
                      TabBar(
                        tabs: [
                          Tab(
                            height: 64,
                            child: Text(
                              l.settingsGeneralTab,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Tab(
                            height: 64,
                            child: Text(
                              l.settingsMetersTab,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Tab(
                            height: 64,
                            child: Text(
                              l.settingsMembersTab,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _page(context, [
                              _section(
                                context,
                                l.settingsWorkspaces,
                                l.settingsWorkspaceHelp,
                                [
                                  if (model.workspaces.any(
                                    (w) => w.isSystemAdmin,
                                  ))
                                    OutlinedButton.icon(
                                      onPressed: model.busy
                                          ? null
                                          : () => showDialog<void>(
                                              context: context,
                                              builder: (_) =>
                                                  CreateWorkspaceDialog(
                                                    model: model,
                                                  ),
                                            ),
                                      icon: const Icon(Icons.add),
                                      label: Text(l.createWorkspace),
                                    ),
                                  if (workspace == null) Text(l.noWorkspace),
                                  if (admin)
                                    OutlinedButton.icon(
                                      onPressed: model.busy
                                          ? null
                                          : () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _RenameDialog(
                                                model: model,
                                                workspace: workspace,
                                              ),
                                            ),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: Text(l.renameWorkspace),
                                    ),
                                ],
                              ),
                              if (model.repository.isOperator)
                                _section(
                                  context,
                                  l.backupTitle,
                                  l.settingsBackupHelp,
                                  [
                                    OutlinedButton.icon(
                                      onPressed: model.busy
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    BackupView(model: model),
                                              ),
                                            ),
                                      icon: const Icon(Icons.backup_outlined),
                                      label: Text(l.backupTitle),
                                    ),
                                  ],
                                ),
                            ]),
                            _page(context, [
                              if (workspace == null)
                                Text(l.noWorkspace)
                              else ...[
                                _section(
                                  context,
                                  l.settingsMeters,
                                  l.settingsMetersHelp,
                                  [
                                    if (admin)
                                      FilledButton.icon(
                                        onPressed: model.busy
                                            ? null
                                            : () => showDialog<void>(
                                                context: context,
                                                builder: (_) =>
                                                    PointDialog(model: model),
                                              ),
                                        icon: const Icon(Icons.add),
                                        label: Text(l.createPoint),
                                      ),
                                    OutlinedButton(
                                      onPressed: model.busy
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) => TransitionView(
                                                  model: model,
                                                ),
                                              ),
                                            ),
                                      child: Text(l.transitionTitle),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: model.busy
                                          ? null
                                          : () => showVirtualPointDialog(
                                              context,
                                              model,
                                            ),
                                      icon: const Icon(
                                        Icons.calculate_outlined,
                                      ),
                                      label: Text(l.virtualCreate),
                                    ),
                                    OutlinedButton(
                                      onPressed: model.busy
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) => HeatView(
                                                  model: model,
                                                  manage: true,
                                                ),
                                              ),
                                            ),
                                      child: Text(l.heatTitle),
                                    ),
                                  ],
                                ),
                                if (model.activePoints.isEmpty)
                                  Text(l.noPoints),
                                for (final point in model.activePoints)
                                  _point(context, point, admin),
                                const SizedBox(height: 16),
                                Text(
                                  l.archivedPoints,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                if (model.archivedPoints.isEmpty)
                                  Text(l.noArchivedPoints),
                                for (final point in model.archivedPoints)
                                  _point(context, point, admin),
                              ],
                            ]),
                            if (workspace == null)
                              _page(context, [Text(l.noWorkspace)])
                            else
                              MembersPanel(
                                key: membersKey,
                                model: model,
                                workspace: workspace,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _status(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      if (model.busy) const LinearProgressIndicator(),
      if (model.error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorText(l, model.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ConflictReload(
        error: model.error,
        busy: model.busy,
        onReload: model.refresh,
      ),
    ];
  }

  Widget _page(BuildContext context, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ..._status(context),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ],
  );

  Widget _section(
    BuildContext context,
    String title,
    String help,
    List<Widget> actions,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(help),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: actions),
        ],
      ),
    ),
  );

  Widget _point(BuildContext context, Point point, bool admin) {
    final l = AppLocalizations.of(context);
    if (point.isVirtual) {
      return Card(
        key: ValueKey('settings-${point.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.name, style: Theme.of(context).textTheme.titleMedium),
              Text(l.virtualCalculated),
              Text(l.virtualHelp),
              if (admin)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: model.busy
                          ? null
                          : () => showVirtualPointDialog(
                              context,
                              model,
                              existing: point,
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l.virtualEdit),
                    ),
                    TextButton(
                      onPressed: model.busy
                          ? null
                          : () => model.saveVirtual(
                              {
                                ...point.virtualInfo!['definition']
                                    as Map<String, dynamic>,
                                'archived': !point.archived,
                              },
                              const Uuid().v4(),
                              existing: point,
                            ),
                      child: Text(
                        point.archived ? l.restorePoint : l.deletePoint,
                      ),
                    ),
                    TextButton(
                      onPressed: model.busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(l.virtualRemove),
                                  content: Text(l.virtualRemoveConfirm),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(l.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(l.virtualRemove),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await model.removeVirtual(
                                  point,
                                  const Uuid().v4(),
                                );
                              }
                            },
                      child: Text(l.virtualRemove),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    return Card(
      key: ValueKey('settings-${point.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(point.name, style: Theme.of(context).textTheme.titleMedium),
            Text('${l.serial}: ${point.serial}'),
            if (admin)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!point.archived)
                    OutlinedButton.icon(
                      onPressed: model.busy
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  TariffDialog(model: model, point: point),
                            ),
                      icon: const Icon(Icons.price_change_outlined),
                      label: Text(l.manageTariffs),
                    ),
                  Tooltip(
                    message:
                        model.workspaces.any(
                          (w) => w.id != model.workspace?.id && w.isAdmin,
                        )
                        ? l.movePointHelp
                        : l.movePointNoTarget,
                    child: TextButton.icon(
                      onPressed:
                          model.busy ||
                              !model.workspaces.any(
                                (w) => w.id != model.workspace?.id && w.isAdmin,
                              )
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  MovePointDialog(model: model, point: point),
                            ),
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: Text(l.movePoint),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: model.busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _RenameDialog(model: model, point: point),
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.editPoint),
                  ),
                  TextButton.icon(
                    onPressed: model.busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _ArchiveDialog(model: model, point: point),
                          ),
                    icon: Icon(
                      point.archived ? Icons.restore : Icons.delete_outline,
                    ),
                    label: Text(
                      point.archived ? l.restorePoint : l.deletePoint,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: model.busy
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _PurgeDialog(model: model, point: point),
                          ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(l.purgePoint),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TariffView(model: model, point: point, allowManage: false),
            TextButton.icon(
              onPressed: model.busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PointDetailView(
                          model: model,
                          pointId: point.id,
                          workspaceId: model.workspace!.id,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l.meterDetails),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final ViewModel model;
  final Workspace? workspace;
  final Point? point;
  const _RenameDialog({required this.model, this.workspace, this.point});
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.workspace?.name ?? widget.point!.name,
  );
  late final serial = TextEditingController(text: widget.point?.serial ?? '');
  String key = const Uuid().v4();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    serial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.workspace != null ? l.renameWorkspace : l.editPoint),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    enabled: !saving,
                    autofocus: true,
                    maxLength: 200,
                    decoration: InputDecoration(labelText: l.name),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.required : null,
                    onChanged: (_) => key = const Uuid().v4(),
                  ),
                  if (widget.point != null)
                    TextFormField(
                      controller: serial,
                      enabled: !saving,
                      maxLength: 100,
                      decoration: InputDecoration(labelText: l.serial),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l.required : null,
                      onChanged: (_) => key = const Uuid().v4(),
                    ),
                  if (saving) const LinearProgressIndicator(),
                  if (error != null)
                    Text(
                      errorText(l, error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (error == 'AUTHENTICATION_REQUIRED')
            FilledButton(
              onPressed: saving ? null : () => navigate('/auth/login?mfa=1'),
              child: Text(l.login),
            ),
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = widget.workspace != null
                        ? await widget.model.renameWorkspace(
                            widget.workspace!,
                            name.text.trim(),
                            key,
                          )
                        : await widget.model.managePoint(
                            widget.point!,
                            'details',
                            key,
                            name: name.text.trim(),
                            serial: serial.text.trim(),
                          );
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = widget.model.error;
                      });
                    }
                  },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

class _PurgeDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  const _PurgeDialog({required this.model, required this.point});
  @override
  State<_PurgeDialog> createState() => _PurgeDialogState();
}

class _PurgeDialogState extends State<_PurgeDialog> {
  final confirmation = TextEditingController();
  final key = const Uuid().v4();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(l.purgePointTitle),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.purgePointHelp(
                    widget.point.name,
                    widget.point.serial,
                    widget.point.readings.length,
                  ),
                ),
                const SizedBox(height: 16),
                Text(l.serialCorrectionHelp),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmation,
                  enabled: !saving,
                  decoration: InputDecoration(labelText: l.purgeConfirmation),
                  onChanged: (_) => setState(() {}),
                ),
                if (saving) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    errorText(l, error!),
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
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: saving || confirmation.text.trim() != widget.point.name
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = await widget.model.purgePoint(widget.point, key);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = widget.model.error;
                      });
                    }
                  },
            child: Text(l.purgePoint),
          ),
        ],
      ),
    );
  }
}

class _ArchiveDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  const _ArchiveDialog({required this.model, required this.point});
  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  final key = const Uuid().v4();
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final restore = widget.point.archived;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(restore ? l.restorePointTitle : l.deletePointTitle),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restore
                      ? l.restorePointHelp(widget.point.name)
                      : l.deletePointHelp(widget.point.name),
                ),
                if (saving) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    errorText(l, error!),
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
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = await widget.model.managePoint(
                      widget.point,
                      restore ? 'restore' : 'archive',
                      key,
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = widget.model.error;
                      });
                    }
                  },
            child: Text(restore ? l.restorePoint : l.deletePoint),
          ),
        ],
      ),
    );
  }
}
