import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show registerName, errorText;
import 'models.dart';
import 'register_tabs.dart';

class VirtualReadingsView extends StatefulWidget {
  final Point point;
  final int? year;
  const VirtualReadingsView({super.key, required this.point, this.year});
  @override
  State<VirtualReadingsView> createState() => _VirtualReadingsViewState();
}

class _VirtualReadingsViewState extends State<VirtualReadingsView> {
  String? selectedRegister;
  @override
  void didUpdateWidget(covariant VirtualReadingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id) selectedRegister = null;
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final year = widget.year;
    final l = AppLocalizations.of(context);
    final register =
        point.registers.where((r) => r.id == selectedRegister).firstOrNull ??
        point.registers.firstOrNull;
    final periods = point.virtualPeriods.where(
      (p) =>
          p['register_id'] == register?.id &&
          (year == null ||
              (p['start_date'] as String).compareTo('${year + 1}-01-01') < 0 &&
                  (p['end_date'] as String).compareTo('$year-01-01') > 0),
    );
    String date(String value) =>
        DateFormat.yMd(l.localeName).format(DateTime.parse(value));
    String name(String id) =>
        point.virtualSources
                .where((p) => p['point_id'] == id)
                .firstOrNull?['name']
            as String? ??
        id;
    final total = point.annual
        ?.where((s) => s.year == year)
        .firstOrNull
        ?.positions
        .where((p) => p.registerId == register?.id)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.virtualPeriods, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l.virtualHelp),
        if (register != null)
          RegisterTabs(
            registers: point.registers,
            selectedId: register.id,
            onChanged: (id) => setState(() => selectedRegister = id),
          ),
        for (final flag in point.virtualFlags) Text(errorText(l, flag)),
        if (periods.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.overviewNoConsumption),
          ),
        for (final p in periods)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date(p['start_date'] as String)} – ${date(p['end_date'] as String)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${registerName(l, register!)}: ${displayQuantity(p['quantity'] as String, locale: l.localeName)} ${p['unit']}',
                  ),
                  Text(
                    (p['source_ids'] as List)
                        .cast<String>()
                        .map(name)
                        .join(', '),
                  ),
                  if (p['grid_quantity'] != null)
                    Text(
                      '${l.importRegister}: ${displayQuantity(p['grid_quantity'] as String, locale: l.localeName)} kWh · ${l.virtualPV}: ${displayQuantity(p['house_pv_quantity'] as String, locale: l.localeName)} kWh',
                    ),
                ],
              ),
            ),
          ),
        if (total != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.readingYearTotal,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${registerName(l, register!)}: ${total.from.isEmpty ? '—' : displayQuantity(total.quantity, locale: l.localeName)} ${total.unit}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
