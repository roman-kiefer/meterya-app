import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';

class ConsumptionView extends StatelessWidget {
  final Point point;
  final String? title, help;
  const ConsumptionView({
    super.key,
    required this.point,
    this.title,
    this.help,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final formatter = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final intervals = point.consumption;
    String registerName(Register r) => switch (r.direction) {
      'IMPORT' => l.importRegister,
      'EXPORT' => l.exportRegister,
      _ => l.consumptionRegister,
    };
    return ExpansionTile(
      title: Text(title ?? l.consumption),
      subtitle: Text(l.newestFirst),
      children: [
        if (help != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(help!)),
        if (intervals == null)
          ListTile(title: Text(l.consumptionUnavailable))
        else
          for (final register in point.registers) ...[
            ListTile(title: Text(registerName(register))),
            if (!intervals.any((i) => i.registerId == register.id))
              ListTile(title: Text(l.needTwoReadings)),
            for (final interval in intervals.where(
              (i) => i.registerId == register.id,
            ))
              ListTile(
                title: Text(
                  l.quantityWithUnit(
                    displayQuantity(interval.quantity),
                    interval.unit,
                  ),
                ),
                subtitle: Text(
                  l.readingPeriod(
                    formatter.format(DateTime.parse(interval.startDate)),
                    formatter.format(DateTime.parse(interval.endDate)),
                  ),
                ),
              ),
          ],
      ],
    );
  }
}
