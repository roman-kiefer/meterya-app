import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'l10n/app_localizations.dart';

class MonthlyBillingView extends StatelessWidget {
  final Point point;
  const MonthlyBillingView({super.key, required this.point});
  @override
  Widget build(BuildContext context) {
    if (point.monthlyBilling.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ExpansionTile(
      title: Text(l.monthlyStatement),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.monthlyStatementHelp),
        ),
        for (final bill in point.monthlyBilling)
          ExpansionTile(
            title: Text(
              point.registers.any((r) => r.direction == 'EXPORT')
                  ? l.statementRegisterYear(
                      bill.year.toString(),
                      bill.isExport
                          ? l.statementExportRegister
                          : l.statementImportRegister,
                    )
                  : bill.year.toString(),
            ),
            subtitle: Text(bill.complete ? l.completeYear : l.partialYear),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.openingReading(displayQuantity(bill.opening))),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(l.statementMonth)),
                    DataColumn(label: Text(l.statementReading)),
                    DataColumn(
                      label: Text(
                        bill.isExport
                            ? l.exportRegister
                            : l.statementConsumption,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        bill.isExport ? l.statementExportRate : l.statementRate,
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        bill.isExport
                            ? l.statementExportEnergy
                            : l.statementEnergy,
                      ),
                    ),
                    DataColumn(label: Text(l.baseCosts)),
                    DataColumn(
                      label: Text(
                        bill.isExport
                            ? l.statementReceived
                            : l.statementPayment,
                      ),
                    ),
                  ],
                  rows: [
                    for (final row in bill.rows)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormat.MMMM(
                                locale,
                              ).format(DateTime.parse(row.date)),
                            ),
                          ),
                          DataCell(Text(displayQuantity(row.value))),
                          DataCell(
                            Text('${displayQuantity(row.quantity)} kWh'),
                          ),
                          DataCell(
                            Text(
                              '${displayQuantity('${row.rate ~/ 1000}.${(row.rate % 1000).toString().padLeft(3, '0')}')} ct/kWh',
                            ),
                          ),
                          DataCell(Text('${displayQuantity(row.energy)} €')),
                          DataCell(Text(displayEuros(row.base.toString()))),
                          DataCell(Text(displayEuros(row.payment.toString()))),
                        ],
                      ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  bill.isExport ? l.exportRegister : l.statementConsumption,
                ),
                trailing: Text('${displayQuantity(bill.quantity)} kWh'),
              ),
              ListTile(
                title: Text(
                  bill.isExport ? l.statementExportEnergy : l.statementEnergy,
                ),
                trailing: Text(displayEuros(bill.energy)),
              ),
              ListTile(
                title: Text(l.baseCosts),
                trailing: Text(displayEuros(bill.base)),
              ),
              ListTile(
                title: Text(
                  bill.isExport ? l.statementExportTotal : l.statementTotal,
                ),
                trailing: Text(displayEuros(bill.total)),
              ),
              ListTile(
                title: Text(
                  bill.isExport ? l.statementReceived : l.statementPayment,
                ),
                trailing: Text(displayEuros(bill.payment)),
              ),
              ListTile(
                title: Text(
                  bill.isExport
                      ? (BigInt.parse(bill.balance).isNegative
                            ? l.statementExportOverpaid
                            : l.statementExportOutstanding)
                      : BigInt.parse(bill.balance).isNegative
                      ? l.statementCredit
                      : l.statementDue,
                ),
                trailing: Text(
                  displayEuros(BigInt.parse(bill.balance).abs().toString()),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
