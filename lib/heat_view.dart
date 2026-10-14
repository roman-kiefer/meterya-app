import 'virtual_point_dialog.dart';
import 'app_theme.dart';
import 'heat_flow_view.dart';
import 'heat_details_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'navigation.dart';
import 'heat_view_model.dart';
import 'view_model.dart';
import 'overview_frame.dart';

class HeatView extends StatefulWidget {
  final ViewModel model;
  final bool manage;
  const HeatView({super.key, required this.model, this.manage = false});
  @override
  State<HeatView> createState() => _HeatViewState();
}

class _HeatViewState extends State<HeatView> {
  late final workspace = widget.model.workspace!;
  late final vm = HeatViewModel(widget.model.repository, workspace.id);
  final name = TextEditingController();
  final from = TextEditingController();
  bool createVirtual = false;
  String? netId, houseId;
  String key = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    from.text = DateTime.now().toIso8601String().substring(0, 10);
    vm.load();
  }

  @override
  void dispose() {
    vm.dispose();
    name.dispose();
    from.dispose();
    super.dispose();
  }

  String pointName(String id, AppLocalizations l) =>
      widget.model.points.where((p) => p.id == id).firstOrNull?.name ??
      l.transitionDeleted;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.model]),
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final points = widget.model.activePhysicalPoints
          .where(
            (p) =>
                p.registers.any((r) => r.direction == 'IMPORT') &&
                p.registers.any((r) => r.direction == 'EXPORT'),
          )
          .toList();
      final net = points.where((p) => p.id == netId).firstOrNull,
          house = points.where((p) => p.id == houseId).firstOrNull;
      final current = widget.model.workspace;
      return PopScope(
        canPop: !vm.busy,
        child: WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            automaticallyImplyLeading: widget.manage,
            model: widget.model,
            busy: vm.busy,
            title: Text(l.heatTitle),
          ),
          body: AppNavigationFrame(
            model: widget.model,
            selectedIndex: widget.manage ? 2 : 1,
            sectionRoot: !widget.manage,
            busy: vm.busy,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    HeatSection(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.of(context).panel,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.heat_pump_outlined,
                              color: AppColors.of(context).heatAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.heatTitle,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(l.heatOverviewHelp),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                    if (vm.reports.isEmpty && !vm.busy) Text(l.heatEmpty),
                    for (final r in vm.reports) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (current?.isAdmin == true)
                              IconButton(
                                tooltip: l.virtualCreate,
                                icon: const Icon(Icons.calculate_outlined),
                                onPressed: widget.model.busy
                                    ? null
                                    : () => showVirtualPointDialog(
                                        context,
                                        widget.model,
                                        heatId: r.id,
                                      ),
                              ),
                            Text(
                              r.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).successPanel,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l.heatFrom(
                                  DateFormat.yMd(
                                    l.localeName,
                                  ).format(DateTime.parse(r.from)),
                                ),
                                style: TextStyle(
                                  color: AppColors.of(context).onSuccess,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final flag in r.flags)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            switch (flag) {
                              'NEGATIVE_BALANCE' => l.heatNegative,
                              'VIRTUAL_AMBIGUOUS' => l.virtualAmbiguous,
                              'VIRTUAL_INCOMPATIBLE' => l.virtualIncompatible,
                              'MEASUREMENT_GAP' => l.measurementGap,
                              'SOURCE_MISSING' => l.heatSourceMissing,
                              'MISSING_COMMON_EXPORT_READINGS' =>
                                l.heatMissingAll,
                              _ => l.heatMissingImport,
                            },
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      HeatFlowView(
                        report: r,
                        net: widget.model.points
                            .where((p) => p.id == r.currentNet)
                            .firstOrNull,
                        house: widget.model.points
                            .where((p) => p.id == r.currentHouse)
                            .firstOrNull,
                        year: widget.model.billingYear,
                      ),
                      const SizedBox(height: 20),
                      HeatDetailsView(
                        report: r,
                        model: widget.model,
                        busy: vm.busy,
                        onTariffChanged: () async {
                          await vm.load();
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.manage &&
                        widget.model.signedIn &&
                        current?.id == workspace.id &&
                        current?.isAdmin == true) ...[
                      const SizedBox(height: 24),
                      Text(
                        l.heatSetup,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextField(
                        controller: name,
                        onChanged: (_) => key = const Uuid().v4(),
                        decoration: InputDecoration(labelText: l.heatName),
                        enabled: !vm.busy,
                      ),
                      TextField(
                        controller: from,
                        onChanged: (_) => key = const Uuid().v4(),
                        decoration: InputDecoration(labelText: l.heatDate),
                        enabled: !vm.busy,
                      ),
                      for (final isNet in [true, false])
                        DropdownButtonFormField<String>(
                          key: ValueKey('${isNet ? netId : houseId}-$isNet'),
                          initialValue: isNet ? netId : houseId,
                          decoration: InputDecoration(
                            labelText: isNet ? l.heatNet : l.heatHouse,
                          ),
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
                                  if (isNet) {
                                    netId = id;
                                  } else {
                                    houseId = id;
                                  }
                                  key = const Uuid().v4();
                                }),
                        ),
                      if (net != null && house != null)
                        Text(l.heatCascade(net.name, house.name)),
                      CheckboxListTile(
                        value: createVirtual,
                        onChanged: vm.busy
                            ? null
                            : (value) =>
                                  setState(() => createVirtual = value == true),
                        title: Text(l.virtualCreate),
                      ),
                      FilledButton(
                        onPressed:
                            vm.busy ||
                                net == null ||
                                house == null ||
                                net.id == house.id
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(l.heatConfirm),
                                    content: Text(
                                      '${l.heatCascade(net.name, house.name)}\n${from.text}\n\n${l.heatConfirmHelp}',
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
                                if (ok != true || !mounted) return;
                                if (await vm.configure(
                                  current!,
                                  name.text.trim(),
                                  from.text.trim(),
                                  net,
                                  house,
                                  key,
                                )) {
                                  await widget.model.refresh();
                                  if (!mounted || !context.mounted) return;
                                  if (createVirtual) {
                                    final created = vm.reports
                                        .where(
                                          (r) => r.name == name.text.trim(),
                                        )
                                        .firstOrNull;
                                    if (created != null) {
                                      await showVirtualPointDialog(
                                        context,
                                        widget.model,
                                        heatId: created.id,
                                      );
                                      if (!mounted || !context.mounted) return;
                                    }
                                  }
                                  setState(() {
                                    createVirtual = false;
                                    netId = null;
                                    houseId = null;
                                    name.clear();
                                    key = const Uuid().v4();
                                  });
                                }
                              },
                        child: Text(l.heatSave),
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
