import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'view_model.dart';
import 'reading_photo_evidence.dart';

class ReadingChangeDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  final Reading reading;
  final bool retract;
  const ReadingChangeDialog({
    super.key,
    required this.model,
    required this.point,
    required this.reading,
    required this.retract,
  });
  @override
  State<ReadingChangeDialog> createState() => _ReadingChangeDialogState();
}

class _ReadingChangeDialogState extends State<ReadingChangeDialog> {
  final form = GlobalKey<FormState>();
  late final date = TextEditingController(text: widget.reading.date);
  late final value = TextEditingController(
    text: displayQuantity(widget.reading.value),
  );
  final reason = TextEditingController();
  String key = const Uuid().v4();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    date.dispose();
    value.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.retract ? l.retractReading : l.correctReading),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              onChanged: () {
                if (!saving) key = const Uuid().v4();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.retract
                        ? l.readingRetractConfirm
                        : l.readingChangeHelp,
                  ),
                  const SizedBox(height: 16),
                  BookedReadingValues(
                    point: widget.point,
                    reading: widget.reading,
                  ),
                  for (final photo in widget.point.photos.where(
                    (p) => p.readingId == widget.reading.id,
                  ))
                    Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ReadingPhotoPreview(
                          api: widget.model.repository.api,
                          photo: photo,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (widget.retract)
                    Text(
                      '${widget.reading.date} · ${displayQuantity(widget.reading.value)} ${widget.point.registers.firstWhere((r) => r.id == widget.reading.registerId).unit}',
                    )
                  else ...[
                    TextFormField(
                      controller: date,
                      enabled: !saving,
                      decoration: InputDecoration(labelText: l.date),
                      validator: (v) =>
                          v != null && validDate(v) ? null : l.invalidDate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: value,
                      enabled: !saving,
                      decoration: InputDecoration(labelText: l.value),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => normalizeReading(v ?? '') != null
                          ? null
                          : l.invalidValue,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reason,
                    enabled: !saving,
                    maxLength: 500,
                    decoration: InputDecoration(labelText: l.readingReason),
                  ),
                  if (error != null)
                    Text(
                      errorText(l, error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (saving) const LinearProgressIndicator(),
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
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = await widget.model.changeReading(
                      widget.point,
                      widget.reading,
                      key,
                      retract: widget.retract,
                      reason: reason.text.trim(),
                      date: date.text,
                      value: normalizeReading(value.text),
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
            child: Text(widget.retract ? l.retractReading : l.save),
          ),
        ],
      ),
    );
  }
}
