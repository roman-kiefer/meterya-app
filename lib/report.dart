import 'dart:convert';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';

enum ReportFormat { html, json }

class ReportFile {
  final String name, mediaType, content;
  const ReportFile(this.name, this.mediaType, this.content);
}

abstract interface class ReportDelivery {
  Future<void> save(ReportFile file);
}

// A report is an immutable snapshot of the values already displayed by the API.
// It deliberately does not calculate money again from rounded display quantities.
class BillingReport {
  final Workspace workspace;
  final Point point;
  final AnnualSummary summary;
  final DateTime exportedAt;
  BillingReport(this.workspace, this.point, this.summary, this.exportedAt) {
    if (summary.pointVersion != point.version ||
        summary.calculationVersion == null ||
        summary.calculationVersion! < 1) {
      throw StateError('REPORT_UNAVAILABLE');
    }
  }

  List<Reading> get readings {
    final start = '${summary.year.toString().padLeft(4, '0')}-01-01';
    final end = '${(summary.year + 1).toString().padLeft(4, '0')}-01-01';
    final sources = <Reading>{};
    for (final register in point.registers) {
      final readings =
          point.readings.where((r) => r.registerId == register.id).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      sources.addAll(
        readings.where(
          (r) => r.date.compareTo(start) >= 0 && r.date.compareTo(end) <= 0,
        ),
      );
      for (var i = 1; i < readings.length; i++) {
        if (readings[i - 1].date.compareTo(end) < 0 &&
            readings[i].date.compareTo(start) > 0) {
          sources.add(readings[i - 1]);
          sources.add(readings[i]);
        }
      }
    }
    return sources.toList()..sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order == 0 ? a.registerId.compareTo(b.registerId) : order;
    });
  }

  List<Price> get prices {
    final start = '${summary.year.toString().padLeft(4, '0')}-01-01';
    final end = '${(summary.year + 1).toString().padLeft(4, '0')}-01-01';
    return [...point.tariffs.basePrices, ...point.tariffs.unitPrices]
        .where(
          (p) =>
              p.from.compareTo(end) < 0 &&
              (p.until.isEmpty || p.until.compareTo(start) > 0),
        )
        .toList()
      ..sort((a, b) {
        final order = a.category.compareTo(b.category);
        return order == 0 ? a.from.compareTo(b.from) : order;
      });
  }

  Map<String, dynamic> toJson() => {
    'report_schema_version': 1,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'workspace': {'id': workspace.id, 'name': workspace.name},
    'point': {
      'id': point.id,
      'name': point.name,
      'serial': point.serial,
      'version': point.version,
    },
    'kind': point.kind,
    'virtual': ?point.virtualInfo,
    'year': summary.year,
    'calculation_version': summary.calculationVersion,
    'complete': summary.complete,
    'estimated': summary.estimated,
    'warnings': summary.warnings,
    'interval_convention': 'START_INCLUSIVE_END_EXCLUSIVE',
    'currency': 'EUR',
    'base_cents': summary.baseCents,
    'net_cents': summary.netCents,
    'positions': [
      for (final p in summary.positions)
        {
          'register_id': p.registerId,
          'direction': p.direction,
          'unit': p.unit,
          'quantity': p.from.isEmpty ? null : p.quantity,
          'covered_from': p.from.isEmpty ? null : p.from,
          'covered_until': p.until.isEmpty ? null : p.until,
          'cents': p.cents,
          'complete': p.complete,
          'estimated': p.estimated,
        },
    ],
    'prices': [
      for (final p in prices)
        {
          ...p.toJson(),
          'category': p.category,
          'cent_basis': p.category == 'BASE' ? p.period : 'PER_1000_UNITS',
        },
    ],
    'readings': [
      for (final r in readings)
        {
          'id': r.id,
          'register_id': r.registerId,
          'date': r.date,
          'value': r.value,
        },
    ],
  };

  ReportFile render(ReportFormat format, AppLocalizations l) {
    // Resource IDs keep names stable and exclude user-provided path characters.
    final safeID = point.id.replaceAll(RegExp('[^a-zA-Z0-9-]'), '_');
    final name = 'meterya-${summary.year}-$safeID-v${point.version}';
    return switch (format) {
      ReportFormat.html => ReportFile(
        '$name.html',
        'text/html;charset=utf-8',
        _html(l),
      ),
      ReportFormat.json => ReportFile(
        '$name.json',
        'application/json;charset=utf-8',
        const JsonEncoder.withIndent('  ').convert(toJson()),
      ),
    };
  }

  String _html(AppLocalizations l) {
    final escape = const HtmlEscape(HtmlEscapeMode.element);
    String e(String text) => escape.convert(text);
    final dates = DateFormat.yMd(l.localeName);
    String date(String value) => dates.format(DateTime.parse(value));
    String money(String? value) => value == null
        ? l.notCalculated
        : displayEuros(value, locale: l.localeName);
    String category(String direction) => switch (direction) {
      'BASE' => l.basePrice,
      'IMPORT' => l.importRegister,
      'EXPORT' => l.exportRegister,
      _ => l.consumptionRegister,
    };
    String warning(String code) => switch (code) {
      'COVERAGE_DIFFERS' => l.virtualCoverageDiffers,
      'MEASUREMENT_GAP' => l.measurementGap,
      'UNIT_PRICE_GAP' => l.unitPriceGap,
      'BASE_PRICE_GAP' => l.basePriceGap,
      _ => l.reportUnknownWarning(code),
    };
    String row(List<String> cells) =>
        '<tr>${cells.map((cell) => '<td>${e(cell)}</td>').join()}</tr>';
    String table(List<String> headers, List<List<String>> rows) =>
        '<div class="table-scroll"><table><thead><tr>${headers.map((h) => '<th scope="col">${e(h)}</th>').join()}</tr></thead><tbody>${rows.map(row).join()}</tbody></table></div>';
    final status = summary.complete ? l.completeYear : l.partialYear;
    final quantities = table(
      [l.register, l.reportQuantity, l.reportCoverage, l.reportStatus],
      [
        for (final p in summary.positions)
          [
            category(p.direction),
            p.from.isEmpty
                ? l.notCalculated
                : l.quantityWithUnit(
                    displayQuantity(p.quantity, locale: l.localeName),
                    p.unit,
                  ),
            p.from.isEmpty
                ? l.noRegisterCoverage
                : l.readingPeriod(date(p.from), date(p.until)),
            '${p.complete ? l.reportCompletePosition : l.reportPartialPosition}${p.estimated ? ' · ${l.estimatedAllocation}' : ''}',
          ],
      ],
    );
    final costs = table(
      [l.reportPosition, l.reportEuros],
      [
        for (final p in summary.positions)
          if (!point.isVirtualHeat || p.direction == 'CONSUMPTION')
            [
              point.isVirtualHeat
                  ? l.virtualGridEnergy
                  : p.direction == 'EXPORT'
                  ? l.exportRevenue
                  : l.positionCost(category(p.direction)),
              money(p.cents),
            ],
        [l.baseCosts, money(summary.baseCents)],
        [
          point.isVirtualHeat
              ? l.virtualGridCosts
              : summary.complete
              ? l.netCosts
              : l.partialCosts,
          money(summary.netCents),
        ],
      ],
    );
    final tariffRows = table(
      [l.priceKind, l.reportPrice, l.reportCoverage],
      [
        for (final p in prices)
          [
            category(p.category),
            p.category == 'BASE'
                ? l.basePriceAmount(
                    displayEuros(p.cents.toString(), locale: l.localeName),
                    p.period == 'MONTH' ? l.perMonth : l.perYear,
                  )
                : l.unitPriceAmount(
                    displayUnitPrice(p.cents, locale: l.localeName),
                    point.registers
                        .firstWhere((r) => r.direction == p.category)
                        .unit,
                  ),
            p.until.isEmpty
                ? l.priceFrom(date(p.from))
                : l.pricePeriod(date(p.from), date(p.until)),
          ],
      ],
    );
    final sourceRows = table(
      [l.reportReadingDate, l.register, l.value, l.reportReadingID],
      [
        for (final r in readings)
          [
            date(r.date),
            category(
              point.registers
                  .firstWhere((reg) => reg.id == r.registerId)
                  .direction,
            ),
            l.quantityWithUnit(
              displayQuantity(r.value, locale: l.localeName),
              point.registers.firstWhere((reg) => reg.id == r.registerId).unit,
            ),
            r.id ?? l.notAvailable,
          ],
      ],
    );
    final derivedRows = table(
      [l.virtualPeriods, l.register, l.statementConsumption, l.virtualSources],
      [
        for (final row in point.virtualPeriods.where(
          (p) =>
              (p['start_date'] as String).compareTo(
                    '${summary.year + 1}-01-01',
                  ) <
                  0 &&
              (p['end_date'] as String).compareTo('${summary.year}-01-01') > 0,
        ))
          [
            '${date(row['start_date'] as String)} – ${date(row['end_date'] as String)}',
            category(
              point.registers
                  .firstWhere((r) => r.id == row['register_id'])
                  .direction,
            ),
            '${displayQuantity(row['quantity'] as String, locale: l.localeName)} ${row['unit']}',
            (row['source_ids'] as List)
                .cast<String>()
                .map(
                  (id) =>
                      point.virtualSources
                              .where((p) => p['point_id'] == id)
                              .firstOrNull?['name']
                          as String? ??
                      id,
                )
                .join(', '),
          ],
      ],
    );
    return '''<!DOCTYPE html>
<html lang="${e(l.localeName)}"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>${e(l.billingReport)} ${summary.year} · ${e(point.name)}</title>
<style>
body{font:16px/1.5 system-ui,sans-serif;color:#173832;background:#fff;max-width:960px;margin:32px auto;padding:0 24px}
h1{font-size:28px;margin-bottom:8px}h2{font-size:21px;margin-top:32px}h3{font-size:17px}
.status{padding:12px 16px;border-left:5px solid #236b61;background:#edf5f2}
.partial{border-color:#a65b00;background:#fff4e4}.metadata{color:#425e58;overflow-wrap:anywhere}
.table-scroll{overflow-x:auto}table{width:100%;border-collapse:collapse;text-align:left;font-size:14px}
th,td{padding:10px 12px;border-bottom:1px solid #ccd8d4;vertical-align:top;overflow-wrap:anywhere}
th:first-child,td:first-child{min-width:6.5em}
th{background:#edf5f2}thead{display:table-header-group}.note{color:#425e58;font-size:14px}
@page{size:A4;margin:16mm}@media print{body{margin:0;padding:0;max-width:none;font-size:11pt}h2{break-after:avoid}tr{break-inside:avoid}.table-scroll{overflow:visible}th,td{font-size:9pt;padding:6px}}
</style></head><body>
<h1>${e(l.billingReport)} ${summary.year}</h1>
<div class="metadata"><p><strong>${e(workspace.name)} · ${e(point.name)}</strong><br>${point.isVirtual ? e(l.virtualCalculated) : '${e(l.serial)}: ${e(point.serial)}'}</p>
<p>${e(l.reportExportedAt)}: ${e(exportedAt.toUtc().toIso8601String())}<br>${e(l.reportSnapshot(point.id, point.version.toString(), summary.calculationVersion.toString()))}</p></div>
<div class="status ${summary.complete ? '' : 'partial'}"><strong>${e(status)}</strong>${summary.estimated ? '<br>${e(l.estimatedAllocation)}' : ''}
${summary.warnings.isEmpty ? '' : '<ul>${summary.warnings.map((code) => '<li>${e(warning(code))}</li>').join()}</ul>'}</div>
<h2>${e(l.reportConsumption)}</h2>$quantities
<h2>${e(l.reportCosts)}</h2>$costs
<p class="note">${e(l.billingRounding)}</p>
<h2>${e(l.reportTariffs)}</h2>${prices.isEmpty ? '<p>${e(l.noTariffs)}</p>' : tariffRows}
${point.isVirtual ? '<h2>${e(l.virtualPeriods)}</h2>$derivedRows${point.isVirtualHeat ? '<p>${e(l.virtualGridCostsHelp)}</p>' : ''}' : ''}
<h2>${e(l.reportSources)}</h2><p class="note">${e(l.reportSourcesHelp)}</p>${readings.isEmpty ? '<p>${e(l.noReadings)}</p>' : sourceRows}
<p class="note">${e(l.reportPrintHelp)}</p>
</body></html>''';
  }
}
