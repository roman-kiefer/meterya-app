import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'point_detail_view.dart';
import 'view_model.dart';

class OverviewDashboard extends StatefulWidget {
  final ViewModel model;
  const OverviewDashboard({super.key, required this.model});

  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  ViewModel get model => widget.model;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final year = model.billingYear;
    final points = model.pointsForYear(year);
    final virtuals = points.where((p) => p.isVirtual).toList();
    final sourceIDs = model.points
        .where((p) => p.isVirtual && !p.archived)
        .expand((p) => p.virtualSources.map((s) => s['point_id'] as String))
        .toSet();
    final sources = points
        .where((p) => !p.isVirtual && sourceIDs.contains(p.id))
        .toList();
    final independent = points
        .where((p) => !p.isVirtual && !sourceIDs.contains(p.id))
        .toList();
    final primary = [...virtuals, ...independent];
    final pricedPoints = primary
        .where(
          (p) =>
              p.isVirtual ||
              [...p.tariffs.basePrices, ...p.tariffs.unitPrices].any(
                (price) =>
                    price.from.compareTo('${year + 1}-01-01') < 0 &&
                    (price.until.isEmpty ||
                        price.until.compareTo('$year-01-01') > 0),
              ),
        )
        .toList();
    final title = Text(
      l.overviewTitle,
      style: Theme.of(context).textTheme.headlineLarge,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        title,
        if (points.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '${l.overviewConsumption} $year',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _cards(primary, year),
          if (sources.isNotEmpty)
            ExpansionTile(
              title: Text(l.virtualSources),
              children: [_cards(sources, year), const SizedBox(height: 12)],
            ),
          if (pricedPoints.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              '${l.overviewCosts} $year',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _cards(pricedPoints, year, costs: true),
          ],
          const SizedBox(height: 12),
          Text(
            l.overviewScopeHelp,
            style: TextStyle(color: AppColors.of(context).muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 28),
        if (points.isEmpty) Text(l.noPoints),
      ],
    );
  }

  Widget _cards(List<Point> points, int year, {bool costs = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 850
              ? 3
              : constraints.maxWidth >= 550
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final point in points)
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    point: point,
                    year: year,
                    costs: costs,
                    onTap: model.busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PointDetailView(
                                model: model,
                                pointId: point.id,
                                workspaceId: model.workspace!.id,
                                initialYear: year,
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      );
}

class _MetricCard extends StatelessWidget {
  final Point point;
  final int year;
  final bool costs;
  final VoidCallback? onTap;
  const _MetricCard({
    required this.point,
    required this.year,
    required this.costs,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = point.annual?.where((s) => s.year == year).firstOrNull;
    final measured =
        summary?.positions.where((p) => p.from.isNotEmpty).toList() ??
        <AnnualPosition>[];
    String date(String value) =>
        (l.localeName == 'de'
                ? DateFormat('dd.MM.yyyy', l.localeName)
                : DateFormat.yMd(l.localeName))
            .format(DateTime.parse(value));
    final periods = measured
        .map((p) => l.overviewRecordedPeriod(date(p.from), date(p.until)))
        .toSet();
    final fullYear = point.registers.every(
      (r) => measured.any(
        (p) =>
            p.registerId == r.id &&
            !p.hasGaps &&
            p.from == '$year-01-01' &&
            (p.until == '$year-12-31' || p.until == '${year + 1}-01-01'),
      ),
    );
    final register = point.registers
        .where((r) => r.direction != 'EXPORT')
        .firstOrNull;
    final water = register?.unit == 'm³';
    final color = water
        ? AppColors.of(context).water
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      point.name,
                      style: TextStyle(
                        color: AppColors.of(context).ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    water ? Icons.water_drop_outlined : Icons.bolt_outlined,
                    color: color,
                    size: 22,
                  ),
                ],
              ),
              Text(
                point.isVirtual ? l.virtualCalculated : point.serial,
                style: TextStyle(
                  color: AppColors.of(context).muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              if (costs) ...[
                Text(
                  summary?.netCents == null
                      ? l.notCalculated
                      : displayEuros(summary!.netCents!, locale: l.localeName),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  point.isVirtualHeat ? l.virtualGridCosts : l.netCosts,
                  style: const TextStyle(fontSize: 12),
                ),
              ] else
                for (final r in point.registers) ...[
                  Text(
                    registerName(l, r),
                    style: TextStyle(
                      color: AppColors.of(context).muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final position = summary?.positions
                          .where(
                            (p) => p.registerId == r.id && p.from.isNotEmpty,
                          )
                          .firstOrNull;
                      return Text(
                        position == null
                            ? '—'
                            : '${displayQuantity(position.quantity, locale: l.localeName)} ${r.unit}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              for (final flag in point.virtualFlags)
                Text(
                  errorText(l, flag),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (measured.isEmpty)
                Text(
                  l.overviewNoConsumption,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              if (measured.isNotEmpty && !fullYear)
                for (final period in periods)
                  Text(period, style: TextStyle(fontSize: 11, color: color)),
              if (summary?.warnings.contains('COVERAGE_DIFFERS') == true)
                Text(
                  l.virtualCoverageDiffers,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (summary?.warnings.contains('MEASUREMENT_GAP') == true)
                Text(
                  l.measurementGap,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (summary?.estimated == true)
                Text(
                  l.estimatedAllocation,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              const SizedBox(height: 16),
              Container(height: 3, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
