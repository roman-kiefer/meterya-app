import 'virtual_point_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'navigation.dart';
import 'transition_view_model.dart';
import 'view_model.dart';
import 'overview_frame.dart';

class TransitionView extends StatefulWidget {
  final ViewModel model;
  const TransitionView({super.key, required this.model});
  @override
  State<TransitionView> createState() => _TransitionViewState();
}

class _TransitionViewState extends State<TransitionView> {
  late final initialWorkspace = widget.model.workspace!;
  late final vm = TransitionViewModel(
    widget.model.repository,
    widget.model.workspace!.id,
  );
  late final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  String? oldID, continuation;
  bool createVirtual = false;
  final selected = <String>{};
  String key = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    vm.load();
  }

  @override
  void dispose() {
    vm.dispose();
    date.dispose();
    super.dispose();
  }

  String name(String id, AppLocalizations l) =>
      widget.model.points.where((p) => p.id == id).firstOrNull?.name ??
      l.transitionDeleted;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final points = widget.model.physicalPoints;
      final ws = widget.model.workspace ?? initialWorkspace;
      final old = points.where((p) => p.id == oldID).firstOrNull;
      final replacements = points
          .where((p) => selected.contains(p.id))
          .toList();
      return PopScope(
        canPop: !vm.busy,
        child: WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            showBillingYear: false,
            model: widget.model,
            busy: vm.busy,
            title: Text(l.transitionTitle),
          ),
          body: AppNavigationFrame(
            model: widget.model,
            selectedIndex: 2,
            sectionRoot: false,
            busy: vm.busy,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(l.transitionHelp),
                    if (vm.busy) const LinearProgressIndicator(),
                    if (vm.error != null)
                      Text(
                        errorText(l, vm.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (vm.error == 'AUTHENTICATION_REQUIRED' ||
                        vm.error == 'MFA_REQUIRED')
                      FilledButton(
                        onPressed: () => navigate('/auth/login?mfa=1'),
                        child: Text(l.login),
                      ),
                    for (final v in vm.records)
                      Card(
                        child: ListTile(
                          title: Text(
                            DateFormat.yMd(
                              l.localeName,
                            ).format(DateTime.parse(v.date)),
                          ),
                          trailing: ws.isAdmin
                              ? IconButton(
                                  tooltip: l.virtualCreate,
                                  icon: const Icon(Icons.calculate_outlined),
                                  onPressed: widget.model.busy
                                      ? null
                                      : () => showVirtualPointDialog(
                                          context,
                                          widget.model,
                                          root: v.oldPoint,
                                        ),
                                )
                              : null,
                          subtitle: Text(
                            l.transitionLink(
                              name(v.oldPoint, l),
                              v.newPoints.map((id) => name(id, l)).join(', '),
                            ),
                          ),
                        ),
                      ),
                    if (widget.model.signedIn &&
                        ws.id == vm.workspace &&
                        ws.isAdmin) ...[
                      const SizedBox(height: 24),
                      TextField(
                        controller: date,
                        decoration: InputDecoration(
                          labelText: l.transitionDate,
                        ),
                        onChanged: (_) => setState(() {
                          key = const Uuid().v4();
                        }),
                        enabled: !vm.busy,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(oldID),
                        initialValue: oldID,
                        decoration: InputDecoration(labelText: l.transitionOld),
                        items: points
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} · ${p.serial}'),
                              ),
                            )
                            .toList(),
                        onChanged: vm.busy
                            ? null
                            : (id) => setState(() {
                                oldID = id;
                                selected.remove(id);
                                key = const Uuid().v4();
                              }),
                      ),
                      const SizedBox(height: 16),
                      Text(l.transitionNew),
                      for (final p in points.where(
                        (p) => !p.archived && p.id != oldID,
                      ))
                        CheckboxListTile(
                          title: Text(p.name),
                          subtitle: Text(p.serial),
                          value: selected.contains(p.id),
                          onChanged:
                              vm.busy ||
                                  (!selected.contains(p.id) &&
                                      selected.length >= 2)
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(p.id);
                                  } else {
                                    selected.remove(p.id);
                                  }
                                  key = const Uuid().v4();
                                }),
                        ),
                      if (selected.length > 1)
                        DropdownButtonFormField<String>(
                          key: ValueKey(selected.join(',')),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l.virtualContinuation,
                          ),
                          items: [
                            for (final id in selected)
                              DropdownMenuItem(
                                value: id,
                                child: Text(
                                  name(id, l),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: vm.busy
                              ? null
                              : (id) => setState(() => continuation = id),
                        ),
                      CheckboxListTile(
                        value: createVirtual,
                        onChanged: vm.busy
                            ? null
                            : (value) =>
                                  setState(() => createVirtual = value == true),
                        title: Text(l.virtualCreate),
                      ),
                      if (old != null && replacements.isNotEmpty) ...[
                        Text(l.transitionReadings),
                        for (final p in [old, ...replacements])
                          ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              p.registers
                                  .map((reg) {
                                    final r = p.readings
                                        .where(
                                          (r) =>
                                              r.registerId == reg.id &&
                                              r.date == date.text,
                                        )
                                        .firstOrNull;
                                    return '${registerName(l, reg)}: ${r == null ? l.transitionMissing : displayQuantity(r.value, locale: l.localeName)} ${reg.unit}';
                                  })
                                  .join('\n'),
                            ),
                          ),
                      ],
                      FilledButton(
                        onPressed:
                            vm.busy ||
                                old == null ||
                                replacements.isEmpty ||
                                (selected.length > 1 &&
                                    (continuation == null ||
                                        !selected.contains(continuation)))
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(l.transitionConfirm),
                                    content: Text(
                                      '${date.text}\n${l.transitionLink(old.name, replacements.map((p) => p.name).join(', '))}\n\n${l.transitionWarning}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(l.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(l.save),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !mounted) return;
                                if (await vm.save(
                                  ws,
                                  old,
                                  replacements,
                                  date.text,
                                  key,
                                  continuation: continuation,
                                )) {
                                  await widget.model.refresh();
                                  if (!mounted || !context.mounted) return;
                                  if (createVirtual) {
                                    await showVirtualPointDialog(
                                      context,
                                      widget.model,
                                      root: old.id,
                                    );
                                    if (!mounted || !context.mounted) return;
                                  }
                                  setState(() {
                                    oldID = null;
                                    continuation = null;
                                    createVirtual = false;
                                    selected.clear();
                                    key = const Uuid().v4();
                                  });
                                }
                              },
                        child: Text(l.transitionSave),
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
}
