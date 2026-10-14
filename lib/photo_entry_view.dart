import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'photo_files.dart';
import 'photo_view_model.dart';
import 'models.dart';
import 'view_model.dart';
import 'navigation.dart';
import 'overview_frame.dart';

class PhotoEntryView extends StatefulWidget {
  final ViewModel model;
  final Future<Uint8List?> Function(bool camera)? picker;
  const PhotoEntryView({super.key, required this.model, this.picker});
  @override
  State<PhotoEntryView> createState() => _PhotoEntryViewState();
}

class _PhotoEntryViewState extends State<PhotoEntryView> {
  late final vm = PhotoViewModel(
    widget.model.repository,
    widget.model.workspace!.id,
  );
  final date = TextEditingController(), value = TextEditingController();
  String? pointId, registerId, notice;
  int step = 0;
  String target = 'serial';
  bool checked = false;
  List<Map<String, dynamic>> edits = [];
  Rect? region;
  Offset? start;
  @override
  void dispose() {
    vm.discard();
    vm.dispose();
    date.dispose();
    value.dispose();
    super.dispose();
  }

  void changed() {
    vm.changed();
    setState(() {
      checked = false;
      notice = null;
    });
  }

  void selectPoint(String? id, {String? suggestedRegister}) {
    pointId = id;
    final point = widget.model.activePhysicalPoints
        .where((p) => p.id == id)
        .firstOrNull;
    registerId = point?.registers.length == 1
        ? point!.registers.single.id
        : point?.registers.any((r) => r.id == suggestedRegister) == true
        ? suggestedRegister
        : null;
  }

  Map<String, dynamic> selection() => {
    'point_id': pointId,
    'register_id': registerId,
    'date': date.text.trim(),
    'value': value.text.trim(),
  };
  Future<void> pick(bool camera) async {
    try {
      final raw =
          await (widget.picker?.call(camera) ??
              pickReadingPhoto(camera: camera));
      if (raw == null || !mounted) return;
      if (await vm.upload(raw) && mounted) {
        setState(() {
          final p = vm.proposal!;
          selectPoint(p.pointId, suggestedRegister: p.registerId);
          date.text = p.date;
          value.text = p.value;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => notice = e.code);
    } catch (_) {
      if (mounted) setState(() => notice = 'PHOTO_INVALID');
    }
  }

  Future<void> edit(Map<String, dynamic>? operation) async {
    final next = operation == null
        ? <Map<String, dynamic>>[]
        : [...edits, operation];
    if (await vm.render(next) && mounted) {
      setState(() {
        edits = next;
        region = null;
        start = null;
        checked = false;
        notice = null;
      });
      vm.changed();
    }
  }

  Map<String, int>? get crop => region == null
      ? null
      : {
          'left': region!.left.round(),
          'top': region!.top.round(),
          'right': region!.right.round(),
          'bottom': region!.bottom.round(),
        };
  Future<void> recognize() async {
    if (crop == null) return;
    final input = selection()
      ..addAll({'edits': edits, 'crop': crop, 'target': target});
    if (await vm.analyze(input) && mounted) {
      setState(() {
        final p = vm.proposal!;
        if (target == 'serial' && p.pointId != null) {
          selectPoint(p.pointId, suggestedRegister: p.registerId);
        }
        if (target == 'register' && p.registerId != null) {
          registerId = p.registerId;
        }
        if (target == 'value' && p.value.isNotEmpty) value.text = p.value;
        checked = false;
        notice = p.flags.firstOrNull;
      });
      vm.changed();
    }
  }

  Future<void> save() async {
    // Validate current manual fields independently of OCR and image selections.
    if (!await vm.analyze(selection()) || !mounted) return;
    final p = vm.proposal!;
    if (!(p.canCreate || p.canAttach)) {
      setState(
        () => notice = p.flags.firstWhere(
          (f) => f != 'PHOTO_CHECK_REQUIRED',
          orElse: () => 'PERMISSION_DENIED',
        ),
      );
      return;
    }
    final input = selection()
      ..addAll({
        'value': p.value,
        'expected_version': p.version,
        'edits': edits,
        if (p.canAttach) 'existing_reading_id': p.existingReadingId,
      });
    if (await vm.save(input)) {
      await widget.model.refresh();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final point = widget.model.activePhysicalPoints
          .where((p) => p.id == pointId)
          .firstOrNull;
      final complete =
          point != null &&
          registerId != null &&
          date.text.trim().isNotEmpty &&
          value.text.trim().isNotEmpty;
      final currentWorkspace = widget.model.workspace?.id == vm.workspace;
      final labels = [l.photoEditStep, l.photoRecognizeStep, l.photoReviewStep];
      final fields = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(labels[step], style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (vm.proposal == null) ...[
            FilledButton.icon(
              onPressed: vm.busy ? null : () => pick(false),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l.photoChoose),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: vm.busy ? null : () => pick(true),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l.photoCamera),
            ),
          ] else ...[
            if (step == 0) ...[
              Text(l.photoEditHelp),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: vm.busy ? null : () => edit({'rotation': 270}),
                    icon: const Icon(Icons.rotate_left),
                    label: Text(l.photoRotateLeft),
                  ),
                  OutlinedButton.icon(
                    onPressed: vm.busy ? null : () => edit({'rotation': 90}),
                    icon: const Icon(Icons.rotate_right),
                    label: Text(l.photoRotateRight),
                  ),
                  OutlinedButton.icon(
                    onPressed: vm.busy || crop == null
                        ? null
                        : () => edit({'crop': crop}),
                    icon: const Icon(Icons.crop),
                    label: Text(l.photoApplyCrop),
                  ),
                  TextButton(
                    onPressed: vm.busy || edits.isEmpty
                        ? null
                        : () => edit(null),
                    child: Text(l.photoResetImage),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: vm.busy
                    ? null
                    : () => setState(() {
                        step = 1;
                        region = null;
                      }),
                child: Text(l.photoNext),
              ),
            ],
            if (step == 1) ...[
              Text(l.photoRegionHelp),
              const SizedBox(height: 16),
              for (final field in ['serial', 'register', 'value'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChoiceChip(
                    label: Text(
                      field == 'serial'
                          ? l.photoSerial
                          : field == 'register'
                          ? l.photoRegister
                          : l.photoValue,
                    ),
                    selected: target == field,
                    onSelected: vm.busy
                        ? null
                        : (_) => setState(() {
                            target = field;
                            region = null;
                            notice = null;
                          }),
                  ),
                ),
              FilledButton.icon(
                onPressed:
                    vm.busy ||
                        crop == null ||
                        target == 'register' && point == null
                    ? null
                    : recognize,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l.photoRecognize),
              ),
              const SizedBox(height: 16),
            ],
            if (step > 0) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('photo-point-$pointId'),
                isExpanded: true,
                initialValue: point?.id,
                decoration: InputDecoration(labelText: l.chooseReadingMeter),
                items: [
                  for (final p in widget.model.activePhysicalPoints)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} · ${p.serial}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: vm.busy
                    ? null
                    : (id) {
                        selectPoint(id);
                        changed();
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('photo-register-$pointId-$registerId'),
                isExpanded: true,
                initialValue:
                    point?.registers.any((r) => r.id == registerId) == true
                    ? registerId
                    : null,
                decoration: InputDecoration(labelText: l.photoRegister),
                items: [
                  for (final r in point?.registers ?? <Register>[])
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.unit == 'kWh' ? (r.direction == 'EXPORT' ? l.photoExport : l.photoImport) : registerName(l, r)} · ${r.unit}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: vm.busy
                    ? null
                    : (id) {
                        registerId = id;
                        changed();
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: date,
                enabled: !vm.busy,
                decoration: InputDecoration(labelText: l.photoDate),
                onChanged: (_) => changed(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: value,
                enabled: !vm.busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l.photoValue),
                onChanged: (_) => changed(),
              ),
              const SizedBox(height: 16),
              if (step == 1)
                FilledButton(
                  onPressed: vm.busy
                      ? null
                      : () => setState(() {
                          step = 2;
                          region = null;
                        }),
                  child: Text(l.photoNext),
                ),
            ],
            if (step == 2) ...[
              Text(l.photoSavedImageHelp),
              if (vm.proposal!.existingReadingId != null) ...[
                Text(l.photoExisting),
                if (vm.proposal!.existingValue != null)
                  Text(
                    l.photoExistingValue(
                      displayQuantity(vm.proposal!.existingValue!),
                    ),
                  ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: vm.busy
                    ? null
                    : (v) => setState(() => checked = v ?? false),
                title: Text(l.photoChecked),
              ),
              if (!complete) Text(l.photoCompleteFields),
              FilledButton.icon(
                onPressed: vm.busy || !checked || !complete || !currentWorkspace
                    ? null
                    : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l.save),
              ),
            ],
            if (step > 0)
              TextButton(
                onPressed: vm.busy
                    ? null
                    : () => setState(() {
                        step--;
                        region = null;
                      }),
                child: Text(l.photoPrevious),
              ),
          ],
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                notice!.startsWith('PHOTO_')
                    ? l.photoNotice(notice!)
                    : errorText(l, notice!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                errorText(l, vm.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (vm.error == 'MFA_REQUIRED' ||
              vm.error == 'AUTHENTICATION_REQUIRED')
            TextButton(
              onPressed: () => navigate('/auth/login?mfa=1'),
              child: Text(l.login),
            ),
        ],
      );
      return PopScope(
        canPop: !vm.busy,
        child: WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            model: widget.model,
            title: const SizedBox.shrink(),
            automaticallyImplyLeading: false,
            showBillingYear: false,
            busy: vm.busy,
          ),
          body: AppNavigationFrame(
            model: widget.model,
            selectedIndex: -1,
            sectionRoot: false,
            busy: vm.busy,
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.photoEntryTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(l.photoEntryHelp),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (var n = 0; n < labels.length; n++)
                              Chip(
                                label: Text('${n + 1}. ${labels[n]}'),
                                backgroundColor: n == step
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (vm.busy) const LinearProgressIndicator(),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 850;
                            final picture = vm.preview == null
                                ? const SizedBox.shrink()
                                : Column(
                                    children: [
                                      _picture(
                                        math.min(
                                          wide
                                              ? constraints.maxWidth - 420
                                              : constraints.maxWidth,
                                          700,
                                        ),
                                      ),
                                      if (step < 2)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            step == 0
                                                ? l.photoEditHelp
                                                : l.photoRegionHelp,
                                          ),
                                        ),
                                    ],
                                  );
                            if (!wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  picture,
                                  const SizedBox(height: 20),
                                  fields,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: picture),
                                const SizedBox(width: 24),
                                SizedBox(width: 380, child: fields),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _picture(double availableWidth) {
    final ratio = vm.width / vm.height;
    final width = math.min(availableWidth, 620 * ratio);
    final height = width / ratio;
    Offset pixel(Offset position) => Offset(
      (position.dx / width * vm.width).clamp(0, vm.width.toDouble()),
      (position.dy / height * vm.height).clamp(0, vm.height.toDouble()),
    );
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          key: const ValueKey('photo-working-image'),
          onPanStart: vm.busy || step == 2
              ? null
              : (d) => setState(() {
                  start = pixel(d.localPosition);
                  region = null;
                }),
          onPanUpdate: vm.busy || step == 2
              ? null
              : (d) => setState(() {
                  if (start != null) {
                    region = Rect.fromPoints(start!, pixel(d.localPosition));
                  }
                }),
          onPanEnd: vm.busy || step == 2
              ? null
              : (_) => setState(() {
                  if (region != null &&
                      (region!.width < 10 || region!.height < 10)) {
                    region = null;
                  }
                }),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(vm.preview!, fit: BoxFit.fill),
              if (region != null)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    region!.left / vm.width * width,
                    region!.top / vm.height * height,
                    region!.right / vm.width * width,
                    region!.bottom / vm.height * height,
                  ),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .15),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
