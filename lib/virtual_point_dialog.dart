import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show errorText;
import 'models.dart';
import 'api_service.dart';
import 'view_model.dart';

Future<void> showVirtualPointDialog(
  BuildContext context,
  ViewModel model, {
  Point? existing,
  String? root,
  String? heatId,
}) => showDialog<void>(
  context: context,
  builder: (_) => VirtualPointDialog(
    model: model,
    existing: existing,
    root: root,
    heatId: heatId,
  ),
);

class VirtualPointDialog extends StatefulWidget {
  final ViewModel model;
  final Point? existing;
  final String? root, heatId;
  const VirtualPointDialog({
    super.key,
    required this.model,
    this.existing,
    this.root,
    this.heatId,
  });
  @override
  State<VirtualPointDialog> createState() => _VirtualPointDialogState();
}

class _VirtualPointDialogState extends State<VirtualPointDialog> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? data;
  final choices = <String, String>{};
  String type = 'SEQUENCE';
  String? root, heatId, error;
  bool saving = false;
  String key = const Uuid().v4();
  String get workspace => widget.model.workspace!.id;
  @override
  void initState() {
    super.initState();
    final definition =
        widget.existing?.virtualInfo?['definition'] as Map<String, dynamic>?;
    type =
        definition?['type'] as String? ??
        (widget.heatId == null ? 'SEQUENCE' : 'HEAT');
    root = definition?['root_point'] as String? ?? widget.root;
    heatId = definition?['heat_id'] as String? ?? widget.heatId;
    name.text = widget.existing?.name ?? '';
    choices.addAll(
      (definition?['choices'] as Map? ?? {}).cast<String, String>(),
    );
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.model.repository.virtualCandidates(workspace);
      if (mounted) {
        setState(() {
          data = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException ? e.code : 'INTERNAL_ERROR');
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> list(String field) =>
      (data?[field] as List? ?? []).cast<Map<String, dynamic>>();
  String sourceName(String id) =>
      list('points').where((p) => p['id'] == id).firstOrNull?['name']
          as String? ??
      widget.model.physicalPoints.where((p) => p.id == id).firstOrNull?.name ??
      AppLocalizations.of(context).virtualSourceMissing;
  String? continuationFor(Map<String, dynamic> change) {
    final config = type == 'HEAT'
        ? list('heat').where((c) => c['id'] == heatId).firstOrNull
        : null;
    return choices[change['old_point']] ??
        (config?['choices'] as Map?)?[change['old_point']] as String? ??
        change['continuation_point'] as String?;
  }

  List<Map<String, dynamic>> relevantBranches() {
    final roots = <String>[];
    if (type == 'SEQUENCE' && root != null) roots.add(root!);
    if (type == 'HEAT') {
      final config = list('heat').where((c) => c['id'] == heatId).firstOrNull;
      if (config != null) {
        roots.addAll([
          config['net_point'] as String,
          config['house_point'] as String,
        ]);
      }
    }
    final seen = <String>{}, branches = <Map<String, dynamic>>[];
    void walk(String id) {
      if (!seen.add(id)) return;
      final change = list(
        'transitions',
      ).where((c) => c['old_point'] == id).firstOrNull;
      if (change == null) return;
      final next = (change['new_points'] as List).cast<String>();
      if (next.length > 1) {
        branches.add(change);
        final selected = continuationFor(change);
        if (selected != null && next.contains(selected)) {
          walk(selected);
        }
      } else if (next.isNotEmpty) {
        walk(next.single);
      }
    }

    for (final id in roots) {
      walk(id);
    }
    return branches;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final branches = relevantBranches();
    final roots = list(
      'transitions',
    ).map((c) => c['old_point'] as String).toSet().toList();
    return AlertDialog(
      title: Text(widget.existing == null ? l.virtualCreate : l.virtualEdit),
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.virtualHelp),
                const SizedBox(height: 16),
                if (data == null && error == null)
                  const LinearProgressIndicator(),
                if (data != null) ...[
                  TextFormField(
                    controller: name,
                    maxLength: 200,
                    enabled: !saving,
                    decoration: InputDecoration(labelText: l.virtualName),
                    validator: (s) =>
                        s == null || s.trim().isEmpty ? l.required : null,
                    onChanged: (_) => key = const Uuid().v4(),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(type),
                    initialValue: type,
                    decoration: InputDecoration(labelText: l.virtualType),
                    items: [
                      DropdownMenuItem(
                        value: 'SEQUENCE',
                        child: Text(l.virtualSequence),
                      ),
                      DropdownMenuItem(
                        value: 'HEAT',
                        child: Text(l.virtualHeat),
                      ),
                    ],
                    onChanged: widget.existing != null || saving
                        ? null
                        : (v) => setState(() {
                            type = v!;
                            choices.clear();
                            key = const Uuid().v4();
                          }),
                  ),
                  const SizedBox(height: 16),
                  if (type == 'SEQUENCE')
                    DropdownButtonFormField<String>(
                      key: ValueKey('root-$root'),
                      initialValue: roots.contains(root) ? root : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.virtualRoot),
                      items: [
                        for (final id in roots)
                          DropdownMenuItem(
                            value: id,
                            child: Text(
                              sourceName(id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (v) => v == null ? l.required : null,
                      onChanged: widget.existing != null || saving
                          ? null
                          : (v) => setState(() {
                              root = v;
                              choices.clear();
                              key = const Uuid().v4();
                            }),
                    ),
                  if (type == 'HEAT')
                    DropdownButtonFormField<String>(
                      key: ValueKey(heatId),
                      initialValue: list('heat').any((c) => c['id'] == heatId)
                          ? heatId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l.virtualHeatSource,
                      ),
                      items: [
                        for (final c in list('heat'))
                          DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(
                              c['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (v) => v == null ? l.required : null,
                      onChanged: widget.existing != null || saving
                          ? null
                          : (v) => setState(() {
                              heatId = v;
                              choices.clear();
                              key = const Uuid().v4();
                            }),
                    ),
                  if (roots.isEmpty && type == 'SEQUENCE' ||
                      list('heat').isEmpty && type == 'HEAT')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.virtualNoConfiguration),
                    ),
                  for (final branch in branches) ...[
                    const SizedBox(height: 16),
                    Text(sourceName(branch['old_point'] as String)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(
                        '${branch['id']}-${choices[branch['old_point']]}',
                      ),
                      initialValue: continuationFor(branch),
                      decoration: InputDecoration(
                        labelText: l.virtualContinuation,
                      ),
                      items: [
                        for (final id
                            in (branch['new_points'] as List).cast<String>())
                          DropdownMenuItem(
                            value: id,
                            child: Text(
                              sourceName(id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (v) => v == null ? l.virtualAmbiguous : null,
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                              choices[branch['old_point'] as String] = v!;
                              key = const Uuid().v4();
                            }),
                    ),
                  ],
                  if (type == 'HEAT')
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(l.virtualGridCostsHelp),
                    ),
                ],
                if (saving) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      errorText(l, error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: saving || data == null
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final definition = <String, dynamic>{
                    'name': name.text.trim(),
                    'type': type,
                    'choices': {
                      for (final branch in relevantBranches())
                        if (choices.containsKey(branch['old_point']))
                          branch['old_point'] as String:
                              choices[branch['old_point']]!,
                    },
                    'archived': widget.existing?.archived ?? false,
                    if (type == 'SEQUENCE') 'root_point': root,
                    if (type == 'HEAT') 'heat_id': heatId,
                  };
                  final ok = await widget.model.saveVirtual(
                    definition,
                    key,
                    existing: widget.existing,
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
    );
  }
}
