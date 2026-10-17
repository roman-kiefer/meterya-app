import 'virtual_readings_view.dart';
import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'view_model.dart';
import 'overview_frame.dart';
import 'point_costs_view.dart';
import 'year_comparison_view.dart';
import 'reading_history_view.dart';

class PointDetailView extends StatefulWidget {
  final ViewModel model;
  final String pointId, workspaceId;
  final int? initialYear;
  final int initialSection;
  const PointDetailView({
    super.key,
    required this.model,
    required this.pointId,
    required this.workspaceId,
    this.initialYear,
    this.initialSection = 4,
  });
  @override
  State<PointDetailView> createState() => _PointDetailViewState();
}

class _PointDetailViewState extends State<PointDetailView> {
  late int section = widget.initialSection;
  @override
  void initState() {
    super.initState();
    if (widget.model.workspace?.id == widget.workspaceId) {
      widget.model.rememberPoint(widget.pointId);
    }
    if (widget.initialYear != null) {
      widget.model.selectBillingYear(widget.initialYear!);
    }
  }

  late String selectedPointId = widget.pointId;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final point =
            model.signedIn && model.workspace?.id == widget.workspaceId
            ? model.points.where((p) => p.id == selectedPointId).firstOrNull
            : null;
        if (point == null) {
          return WorkspaceScaffold(
            appBar: WorkspaceAppBar(
              model: model,
              title: Text(l.meterDetails),
              automaticallyImplyLeading: false,
            ),
            body: AppNavigationFrame(
              model: model,
              selectedIndex: section,
              child: Center(child: Text(l.settingsUnavailable)),
            ),
          );
        }
        final years = (point.annual ?? []).map((y) => y.year).toList()..sort();
        final year = model.billingYear;
        final end = year;
        return WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            automaticallyImplyLeading: false,
            model: model,
            title: Text(l.appTitle),
          ),
          body: AppNavigationFrame(
            model: model,
            selectedIndex: section,
            onMeterSectionSelected: (value) => setState(() => section = value),
            child: Column(
              children: [
                if (model.busy) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final meterPicker = DropdownButtonFormField<String>(
                        key: ValueKey('meter-selector-${point.id}'),
                        initialValue: point.id,
                        isExpanded: true,
                        isDense: false,
                        decoration: InputDecoration(labelText: l.metersNav),
                        selectedItemBuilder: (_) => [
                          for (final meter in model.points)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meter.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  meter.isVirtual
                                      ? l.virtualCalculated
                                      : meter.serial,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                        ],
                        items: [
                          for (final meter in model.points)
                            DropdownMenuItem(
                              value: meter.id,
                              child: Text(
                                '${meter.name} · ${meter.isVirtual ? l.virtualCalculated : meter.serial}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: model.busy
                            ? null
                            : (id) {
                                if (id == null) return;
                                setState(() {
                                  selectedPointId = id;
                                  model.rememberPoint(id);
                                });
                              },
                      );
                      return meterPicker;
                    },
                  ),
                ),
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      errorText(l, model.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: switch (section) {
                    4 => PointCostsView(
                      key: ValueKey(point.id),
                      model: model,
                      point: point,
                      year: year,
                    ),
                    5 =>
                      point.isVirtual
                          ? VirtualReadingsView(point: point, year: year)
                          : ReadingHistoryView(
                              key: ValueKey('readings-${point.id}'),
                              point: point,
                              model: model,
                              year: year,
                            ),
                    _ => _page([
                      if (years.isEmpty)
                        ListTile(title: Text(l.noBillingReadings)),
                      YearComparisonView(point: point, lastYear: end),
                    ]),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _page(List<Widget> children) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    ),
  );
}

class PointOverviewCard extends StatelessWidget {
  final ViewModel model;
  final Point point;
  const PointOverviewCard({
    super.key,
    required this.model,
    required this.point,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final date = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final readings = point.readings.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PointDetailView(
              model: model,
              pointId: point.id,
              workspaceId: model.workspace!.id,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).selectedPanel,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      point.registers.any((r) => r.unit == 'm³')
                          ? Icons.water_drop_outlined
                          : Icons.electric_meter_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          point.isVirtual ? l.virtualCalculated : point.serial,
                          style: TextStyle(
                            color: AppColors.of(context).muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final values = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final register in point.registers)
                    Builder(
                      builder: (context) {
                        final latest = readings
                            .where((r) => r.registerId == register.id)
                            .firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${registerName(l, register)}: ${latest == null ? l.noReadings : '${displayQuantity(latest.value, locale: l.localeName)} ${register.unit}'}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        );
                      },
                    ),
                  Text(
                    readings.isEmpty
                        ? l.noReadings
                        : '${l.lastReading}: ${date.format(DateTime.parse(readings.first.date))}',
                    style: TextStyle(
                      color: AppColors.of(context).muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.meterDetails,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              );
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: identity),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: values),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: actions),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 20),
                  values,
                  const SizedBox(height: 16),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
