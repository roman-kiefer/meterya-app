import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show errorText;
import 'models.dart' show Point, Workspace;
import 'view_model.dart';

class MovePointDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  const MovePointDialog({super.key, required this.model, required this.point});

  @override
  State<MovePointDialog> createState() => _MovePointDialogState();
}

class _MovePointDialogState extends State<MovePointDialog> {
  String? target;
  bool saving = false;
  String? error;
  String key = const Uuid().v4();
  late final List<Workspace> targets = widget.model.workspaces
      .where((w) => w.id != widget.model.workspace?.id && w.isAdmin)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.movePointTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.point.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${l.serial}: ${widget.point.serial}'),
              const SizedBox(height: 16),
              Text(l.movePointHelp),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l.movePointTarget),
                isExpanded: true,
                items: [
                  for (final w in targets)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() {
                        target = value;
                        key = const Uuid().v4();
                        error = null;
                      }),
              ),
              const SizedBox(height: 16),
              Text(l.movePointAccessHelp),
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
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: saving || target == null
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final ok = await widget.model.movePoint(
                    widget.point,
                    targets.firstWhere((w) => w.id == target),
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
          child: Text(l.movePointConfirm),
        ),
      ],
    );
  }
}
