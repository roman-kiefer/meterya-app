import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'heat_model.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';

/// Measured yearly consumption, with the explanatory cascade available on demand.
class HeatFlowView extends StatelessWidget {
  final HeatReport report;
  final Point? net, house;
  final int year;
  const HeatFlowView({
    super.key,
    required this.report,
    required this.net,
    required this.house,
    required this.year,
  });

  Widget _tiles(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 680) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final overview = HeatYearOverview(report, year);
    String quantity(String? value) => value == null
        ? '—'
        : '${displayQuantity(value, locale: l.localeName)} kWh';
    String share(int value) =>
        '${value ~/ 10}${decimalSeparator(l.localeName)}${value % 10} %';
    final dateFormat = l.localeName == 'de'
        ? DateFormat('dd.MM.yyyy', l.localeName)
        : DateFormat.yMd(l.localeName);
    final gridShare = overview.gridShare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeatSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Eyebrow(l.costYear),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('$year', style: Theme.of(context).textTheme.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).panel,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      overview.from == null
                          ? l.noBillingReadings
                          : '${dateFormat.format(DateTime.parse(overview.from!))} – '
                                '${dateFormat.format(DateTime.parse(overview.until!))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _tiles([
                _MetricCard(
                  label: l.heatGrid,
                  value: quantity(overview.grid),
                  icon: Icons.bolt_outlined,
                  color: AppColors.of(context).grid,
                  formula: l.heatGridFormula,
                  share: gridShare == null ? null : share(gridShare),
                  explanation: l.heatGridShareHelp,
                ),
                _MetricCard(
                  label: l.heatHousePV,
                  value: quantity(overview.housePV),
                  icon: Icons.solar_power_outlined,
                  color: AppColors.of(context).pv,
                  formula: l.heatPVFormula,
                  share: overview.pvShare == null
                      ? null
                      : share(overview.pvShare!),
                  explanation: l.heatPVShareHelp,
                ),
                _MetricCard(
                  label: l.heatTotal,
                  value: quantity(overview.total),
                  icon: Icons.heat_pump_outlined,
                  color: AppColors.of(context).heatAccent,
                  formula: l.heatTotalFormula,
                  gridShare: gridShare,
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.heatYearMeasuredHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!overview.sameCoverage && overview.total != null)
          Text(
            l.heatDifferentCoverage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (overview.hasGaps)
          Text(l.measurementGap, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            key: ValueKey('heat-topology-${report.id}'),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(
              Icons.info_outline,
              color: AppColors.of(context).heatAccent,
            ),
            title: Text(
              l.heatTopologyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              l.heatCalculationInfo,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            childrenPadding: const EdgeInsets.all(24),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Eyebrow(l.heatTopologyLabel),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        l.heatFlowTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _Legend(l.importRegister, AppColors.of(context).grid),
                          _Legend(l.exportRegister, AppColors.of(context).pv),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _tiles([
                    _MeterCard(
                      point: net,
                      role: l.heatNetCoupling,
                      description: l.heatNetDescription,
                      importLabel: l.heatImportZ1,
                      exportLabel: l.heatExportZ1,
                    ),
                    _VirtualCard(name: report.name),
                    _MeterCard(
                      point: house,
                      role: l.heatHouseCoupling,
                      description: l.heatHouseDescription,
                      importLabel: l.heatImportZ2,
                      exportLabel: l.heatExportZ2,
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared white section surface for the heat overview and its detail panels.
class HeatSection extends StatelessWidget {
  final Widget child;
  const HeatSection({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.of(context).border),
    ),
    child: child,
  );
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.of(context).muted,
      letterSpacing: 1.2,
    ),
  );
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 7, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MeterCard extends StatelessWidget {
  final Point? point;
  final String role, description, importLabel, exportLabel;
  const _MeterCard({
    required this.point,
    required this.role,
    required this.description,
    required this.importLabel,
    required this.exportLabel,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.electric_meter_outlined,
                size: 20,
                color: AppColors.of(context).heatAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            point?.name ?? l.transitionDeleted,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.of(context).ink),
          ),
          const SizedBox(height: 6),
          Text(
            point?.serial ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  importLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.of(context).grid,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  exportLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.of(context).pv,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VirtualCard extends StatelessWidget {
  final String name;
  const _VirtualCard({required this.name});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff005f59),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff005f59).withValues(alpha: .15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodySmall!.copyWith(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.heatVirtualMeter.toUpperCase(),
                    style: const TextStyle(fontSize: 10, letterSpacing: 1),
                  ),
                ),
                const Icon(
                  Icons.heat_pump_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(l.heatElectricity),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff004d49),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.heatFormulaLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff9ce7dc),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.heatCascadeFormula,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.heatCalculated,
              style: const TextStyle(color: Color(0xffb4eee5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, formula;
  final IconData icon;
  final Color color;
  final String? share, explanation;
  final int? gridShare;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.formula,
    required this.icon,
    required this.color,
    this.share,
    this.explanation,
    this.gridShare,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.of(context).panel,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: .4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: color),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).ink,
          ),
        ),
        const SizedBox(height: 12),
        if (share != null)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  share!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
              Text(explanation!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        if (gridShare != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                if (gridShare! > 0)
                  Expanded(
                    flex: gridShare!,
                    child: Container(
                      height: 6,
                      color: AppColors.of(context).grid,
                    ),
                  ),
                if (gridShare! < 1000)
                  Expanded(
                    flex: 1000 - gridShare!,
                    child: Container(
                      height: 6,
                      color: AppColors.of(context).pv,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          formula,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.of(context).muted,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
