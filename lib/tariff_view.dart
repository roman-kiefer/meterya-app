import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'tariff_view_model.dart';
import 'view_model.dart';

String priceCategory(AppLocalizations l, String category) => switch (category) {
  'BASE' => l.basePrice,
  'IMPORT' => l.importRegister,
  'EXPORT' => l.exportRegister,
  _ => l.consumptionRegister,
};
String tariffError(AppLocalizations l, String? code) => switch (code) {
  'TARIFF_OVERLAP' => l.tariffOverlap,
  'INVALID_TARIFF' || 'VALIDATION_FAILED' => l.invalidTariff,
  'AGGREGATE_VERSION_CONFLICT' || 'IDEMPOTENCY_CONFLICT' => l.conflictError,
  'PERMISSION_DENIED' || 'MFA_REQUIRED' => l.permissionError,
  _ => l.genericError,
};

class PriceTile extends StatelessWidget {
  final Price price;
  final String unit;
  final VoidCallback? onRemove;
  const PriceTile({
    super.key,
    required this.price,
    required this.unit,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final format = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final amount = price.category == 'BASE'
        ? l.basePriceAmount(
            displayEuros(price.cents.toString()),
            price.period == 'MONTH' ? l.perMonth : l.perYear,
          )
        : l.unitPriceAmount(displayUnitPrice(price.cents), unit);
    final validity = price.until.isEmpty
        ? l.priceFrom(format.format(DateTime.parse(price.from)))
        : l.pricePeriod(
            format.format(DateTime.parse(price.from)),
            format.format(DateTime.parse(price.until)),
          );
    return ListTile(
      title: Text('${priceCategory(l, price.category)} · $amount'),
      subtitle: Text(validity),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: l.removePrice,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }
}

class TariffView extends StatelessWidget {
  final ViewModel model;
  final Point point;
  final bool allowManage;
  const TariffView({
    super.key,
    required this.model,
    required this.point,
    this.allowManage = true,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prices = [...point.tariffs.basePrices, ...point.tariffs.unitPrices];
    return ExpansionTile(
      title: Text(l.tariffs),
      children: [
        if (prices.isEmpty) ListTile(title: Text(l.noTariffs)),
        for (final price in prices)
          PriceTile(price: price, unit: point.registers.first.unit),
        if (allowManage && !point.archived && model.workspace?.isAdmin == true)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: model.busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => TariffDialog(model: model, point: point),
                    ),
              child: Text(l.manageTariffs),
            ),
          ),
      ],
    );
  }
}

class TariffDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  final Future<void> Function(Tariffs, String)? onSave;
  const TariffDialog({
    super.key,
    required this.model,
    required this.point,
    this.onSave,
  });
  @override
  State<TariffDialog> createState() => _TariffDialogState();
}

class _TariffDialogState extends State<TariffDialog> {
  late final draft = TariffViewModel(
    widget.model,
    widget.point,
    onSave: widget.onSave,
  );
  final from = TextEditingController(text: '${DateTime.now().year}-01-01');
  final until = TextEditingController(), amount = TextEditingController();
  String category = 'BASE', period = 'MONTH';
  @override
  void dispose() {
    draft.dispose();
    from.dispose();
    until.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => AlertDialog(
        title: Text(l.manageTariffs),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.tariffHelp),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: l.priceKind),
                  items: [
                    for (final value in [
                      'BASE',
                      ...widget.point.registers.map((r) => r.direction),
                    ])
                      DropdownMenuItem(
                        value: value,
                        child: Text(priceCategory(l, value)),
                      ),
                  ],
                  onChanged: draft.busy
                      ? null
                      : (v) => setState(() => category = v!),
                ),
                if (category == 'BASE')
                  DropdownButtonFormField<String>(
                    initialValue: period,
                    decoration: InputDecoration(labelText: l.basePeriod),
                    items: [
                      DropdownMenuItem(value: 'MONTH', child: Text(l.perMonth)),
                      DropdownMenuItem(value: 'YEAR', child: Text(l.perYear)),
                    ],
                    onChanged: draft.busy
                        ? null
                        : (v) => setState(() => period = v!),
                  ),
                TextField(
                  key: const Key('price-from'),
                  controller: from,
                  enabled: !draft.busy,
                  decoration: InputDecoration(labelText: l.validFrom),
                ),
                TextField(
                  key: const Key('price-until'),
                  controller: until,
                  enabled: !draft.busy,
                  decoration: InputDecoration(
                    labelText: l.validUntil,
                    helperText: l.endDateHint,
                    helperMaxLines: 2,
                  ),
                ),
                TextField(
                  key: const Key('price-amount'),
                  controller: amount,
                  enabled: !draft.busy,
                  decoration: InputDecoration(
                    labelText: category == 'BASE'
                        ? l.baseEuros
                        : l.unitEuros(widget.point.registers.first.unit),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: draft.busy
                      ? null
                      : () {
                          if (draft.add(
                            category,
                            period,
                            from.text,
                            until.text,
                            amount.text,
                          )) {
                            amount.clear();
                          }
                        },
                  child: Text(l.addPrice),
                ),
                if (draft.error != null)
                  Text(
                    tariffError(l, draft.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Divider(),
                if (draft.prices.isEmpty) Text(l.noTariffs),
                for (final price in draft.prices)
                  PriceTile(
                    price: price,
                    unit: widget.point.registers.first.unit,
                    onRemove: draft.busy ? null : () => draft.remove(price),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: draft.busy ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: draft.busy
                ? null
                : () async {
                    if (amount.text.trim().isNotEmpty &&
                        !draft.add(
                          category,
                          period,
                          from.text,
                          until.text,
                          amount.text,
                        )) {
                      return;
                    }
                    amount.clear();
                    if (await draft.save() && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
