import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'view_model.dart';
import 'reading_change_dialog.dart';
import 'register_tabs.dart';
import 'photo_gallery.dart';

class ReadingHistoryView extends StatefulWidget {
  final Point point;
  final ViewModel? model;
  final int? year;
  const ReadingHistoryView({
    super.key,
    required this.point,
    this.model,
    this.year,
  });
  @override
  State<ReadingHistoryView> createState() => _ReadingHistoryViewState();
}

class _ReadingHistoryViewState extends State<ReadingHistoryView> {
  String? selectedRegister;
  int? selectedYear;

  @override
  void didUpdateWidget(covariant ReadingHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id) {
      selectedRegister = null;
      selectedYear = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final point = widget.point;
    final register =
        point.registers.where((r) => r.id == selectedRegister).firstOrNull ??
        point.registers.firstOrNull;
    if (register == null) return Center(child: Text(l.noReadings));
    final years =
        point.readings
            .where((r) => r.registerId == register.id)
            .map((r) => DateTime.parse(r.date).year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final year =
        widget.year ??
        (years.contains(selectedYear) ? selectedYear : years.firstOrNull);
    final readings =
        point.readings
            .where(
              (r) =>
                  r.registerId == register.id &&
                  DateTime.parse(r.date).year == year,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final date = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    // Use the annual projection so readings at month/year boundaries keep
    // their billing allocation rather than their calendar entry date.
    final annualPosition = point.annual
        ?.where((summary) => summary.year == year)
        .firstOrNull
        ?.positions
        .where((position) => position.registerId == register.id)
        .firstOrNull;
    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: child,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.year == null && years.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<int>(
              key: ValueKey('reading-year-${register.id}-$year'),
              initialValue: year,
              decoration: InputDecoration(labelText: l.readingYear),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (value) => setState(() => selectedYear = value),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(l.history, style: Theme.of(context).textTheme.titleLarge),
            if (year != null)
              Text(
                l.readingEntryCount(readings.length, year),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.readingsHelp, style: Theme.of(context).textTheme.bodySmall),
        if (point.registers.length > 1) ...[
          const SizedBox(height: 12),
          RegisterTabs(
            registers: point.registers,
            selectedId: register.id,
            onChanged: (id) => setState(() => selectedRegister = id),
          ),
        ],
        const SizedBox(height: 20),
        if (readings.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: Text(l.noReadings))
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                return Table(
                  columnWidths: {
                    0: const FlexColumnWidth(1),
                    1: const FlexColumnWidth(1.3),
                    2: FlexColumnWidth(narrow ? 1.2 : 1.6),
                    3: FixedColumnWidth(
                      widget.model != null &&
                              readings.any(
                                (r) => point.photos.any(
                                  (p) => p.readingId == r.id,
                                ),
                              )
                          ? 96
                          : 48,
                    ),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: AppColors.of(context).table,
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppColors.of(context).table,
                      ),
                      children: [
                        cell(
                          Text(
                            l.readingDateHeader,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        cell(
                          Text(
                            l.statementReading,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        cell(
                          Text(
                            l.readingDifferenceHeader,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox.shrink(),
                      ],
                    ),
                    for (final reading in readings)
                      TableRow(
                        key: ValueKey(
                          'reading-${reading.id ?? '${reading.registerId}-${reading.date}'}',
                        ),
                        children: [
                          cell(Text(date.format(DateTime.parse(reading.date)))),
                          cell(
                            Text(
                              '${displayQuantity(reading.value, locale: l.localeName)} ${register.unit}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          cell(_difference(context, register, reading)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (point.photos.any(
                                    (p) => p.readingId == reading.id,
                                  ) &&
                                  widget.model != null)
                                IconButton(
                                  tooltip: l.photoGallery,
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => PhotoGallery(
                                      api: widget.model!.repository.api,
                                      point: point,
                                      reading: reading,
                                      photos: point.photos
                                          .where(
                                            (p) => p.readingId == reading.id,
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.photo_outlined),
                                ),
                              _actions(context, reading),
                            ],
                          ),
                        ],
                      ),
                    TableRow(
                      key: const ValueKey('reading-year-total'),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).table,
                      ),
                      children: [
                        cell(
                          Text(
                            annualPosition?.complete == true
                                ? l.readingYearTotal
                                : l.monthSubtotal,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox.shrink(),
                        cell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                annualPosition == null ||
                                        annualPosition.from.isEmpty
                                    ? '—'
                                    : '${displayQuantity(annualPosition.quantity, locale: l.localeName)} ${register.unit}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: registerAccent(
                                    register.direction,
                                    context,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (annualPosition?.estimated == true)
                                Text(
                                  l.estimatedAllocation,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _difference(BuildContext context, Register register, Reading reading) {
    final l = AppLocalizations.of(context);
    if (reading.boundaryPriority || reading.difference == null) {
      return Tooltip(
        message: reading.boundaryPriority
            ? l.monthEndReadingPriority
            : l.noReadingDifference,
        child: Text(
          '—',
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.of(context).muted),
        ),
      );
    }
    return Text(
      '${displayQuantity(reading.difference!, locale: l.localeName)} ${register.unit}',
      textAlign: TextAlign.right,
      style: TextStyle(color: registerAccent(register.direction, context)),
    );
  }

  Widget _actions(BuildContext context, Reading reading) {
    if (widget.model?.canChangeReading(reading) != true) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return PopupMenuButton<bool>(
      tooltip: l.readingActions,
      enabled: widget.model?.busy != true,
      onSelected: (retract) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReadingChangeDialog(
          model: widget.model!,
          point: widget.point,
          reading: reading,
          retract: retract,
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(value: false, child: Text(l.correctReading)),
        PopupMenuItem(value: true, child: Text(l.retractReading)),
      ],
    );
  }
}
