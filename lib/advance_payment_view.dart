import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'view_model.dart';

/// Label of an estimated balance: remaining payment, credit or balanced.
String balanceLabel(AppLocalizations l, String? cents) {
  if (cents == null) return l.estimatedBalance;
  final value = BigInt.parse(cents);
  return value > BigInt.zero
      ? l.estimatedRemainingPayment
      : value < BigInt.zero
      ? l.estimatedCredit
      : l.estimatedBalanced;
}

String advancePaymentError(AppLocalizations l, String? code) => switch (code) {
  'INVALID_ADVANCE_PAYMENT' || 'VALIDATION_FAILED' => l.invalidAdvancePayment,
  'ADVANCE_PAYMENT_DUPLICATE' => l.advancePaymentDuplicate,
  'ADVANCE_PAYMENTS_UNSUPPORTED' => l.advancePaymentsUnsupported,
  'AGGREGATE_VERSION_CONFLICT' || 'IDEMPOTENCY_CONFLICT' => l.conflictError,
  'PERMISSION_DENIED' || 'MFA_REQUIRED' => l.permissionError,
  _ => l.genericError,
};

/// Draft of a complete advance payment schedule that is saved at once.
class AdvancePaymentViewModel extends ChangeNotifier {
  final ViewModel home;
  final Point point;
  final Future<void> Function(List<AdvancePayment>, String)? onSave;
  late final List<AdvancePayment> entries = [...point.advancePayments];
  String key = const Uuid().v4();
  String? error;
  bool busy = false, _disposed = false;
  AdvancePaymentViewModel(this.home, this.point, {this.onSave});

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Adds an entry; an existing entry with the same start date is replaced so
  /// that amounts can be corrected without removing them first.
  bool add(String from, String euros) {
    if (busy) return false;
    final start = from.trim();
    final cents = parsePrice(euros, base: true);
    if (cents == null ||
        !validDate(start) ||
        int.parse(start.substring(0, 4)) < 1900 ||
        int.parse(start.substring(0, 4)) > 9998) {
      error = 'INVALID_ADVANCE_PAYMENT';
      _notify();
      return false;
    }
    entries
      ..removeWhere((e) => e.from == start)
      ..add(AdvancePayment(start, cents))
      ..sort((a, b) => a.from.compareTo(b.from));
    key = const Uuid().v4();
    error = null;
    _notify();
    return true;
  }

  void remove(AdvancePayment entry) {
    if (busy) return;
    entries.remove(entry);
    key = const Uuid().v4();
    error = null;
    _notify();
  }

  Future<bool> save() async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    var ok = false;
    final schedule = List<AdvancePayment>.unmodifiable(entries);
    if (onSave != null) {
      try {
        await onSave!(schedule, key);
        ok = true;
      } on ApiException catch (e) {
        error = e.code;
      } catch (_) {
        error = 'INTERNAL_ERROR';
      }
    } else {
      ok = await home.saveAdvancePayments(point, schedule, key);
      if (!ok) error = home.error;
    }
    busy = false;
    _notify();
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AdvancePaymentTile extends StatelessWidget {
  final AdvancePayment entry;
  final VoidCallback? onRemove;
  const AdvancePaymentTile({super.key, required this.entry, this.onRemove});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final format = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return ListTile(
      title: Text(
        l.advancePaymentAmount(
          displayEuros(entry.cents.toString(), locale: l.localeName),
        ),
      ),
      subtitle: Text(
        l.advancePaymentFrom(format.format(DateTime.parse(entry.from))),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: l.removeAdvancePayment,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }
}

/// Read-only schedule shown with the meter settings.
class AdvancePaymentView extends StatelessWidget {
  final Point point;
  const AdvancePaymentView({super.key, required this.point});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExpansionTile(
      title: Text(l.advancePayments),
      children: [
        if (point.advancePayments.isEmpty)
          ListTile(title: Text(l.noAdvancePayments)),
        for (final entry in point.advancePayments.reversed)
          AdvancePaymentTile(entry: entry),
      ],
    );
  }
}

class AdvancePaymentDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  final Future<void> Function(List<AdvancePayment>, String)? onSave;
  const AdvancePaymentDialog({
    super.key,
    required this.model,
    required this.point,
    this.onSave,
  });
  @override
  State<AdvancePaymentDialog> createState() => _AdvancePaymentDialogState();
}

class _AdvancePaymentDialogState extends State<AdvancePaymentDialog> {
  late final draft = AdvancePaymentViewModel(
    widget.model,
    widget.point,
    onSave: widget.onSave,
  );
  final from = TextEditingController(
    text: DateFormat('yyyy-MM-01').format(DateTime.now()),
  );
  final amount = TextEditingController();

  @override
  void dispose() {
    draft.dispose();
    from.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateTime(1900), last = DateTime(9998, 12, 31);
    final typed = DateTime.tryParse(from.text.trim()) ?? DateTime.now();
    // showDatePicker asserts that the initial date lies within its bounds.
    final initial = typed.isBefore(first)
        ? first
        : typed.isAfter(last)
        ? last
        : typed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      from.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  bool _addPending() {
    if (amount.text.trim().isEmpty) return true;
    if (!draft.add(from.text, amount.text)) return false;
    amount.clear();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => AlertDialog(
        title: Text(l.manageAdvancePayments),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.advancePaymentHelp),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('advance-from'),
                  controller: from,
                  enabled: !draft.busy,
                  decoration: InputDecoration(
                    labelText: l.validFrom,
                    helperText: l.advancePaymentDateHint,
                    suffixIcon: IconButton(
                      tooltip: l.advancePaymentPickDate,
                      onPressed: draft.busy ? null : _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ),
                TextField(
                  key: const Key('advance-amount'),
                  controller: amount,
                  enabled: !draft.busy,
                  decoration: InputDecoration(labelText: l.advancePaymentEuros),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('advance-add'),
                    onPressed: draft.busy ? null : _addPending,
                    child: Text(l.addAdvancePayment),
                  ),
                ),
                if (draft.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      advancePaymentError(l, draft.error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const Divider(),
                if (draft.entries.isEmpty) Text(l.noAdvancePayments),
                for (final entry in draft.entries.reversed)
                  AdvancePaymentTile(
                    entry: entry,
                    onRemove: draft.busy ? null : () => draft.remove(entry),
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
            key: const Key('advance-save'),
            onPressed: draft.busy
                ? null
                : () async {
                    if (!_addPending()) return;
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

/// Costs, applicable advance payments and the estimated balance of a period.
/// All amounts come from the API; nothing is recalculated here.
class AdvanceBalanceCard extends StatelessWidget {
  final AnnualSummary summary;
  const AdvanceBalanceCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final paid = summary.advancePaymentCents;
    if (paid == null) return const SizedBox.shrink();
    String money(String? cents) =>
        cents == null ? '—' : displayEuros(cents, locale: l.localeName);
    final balance = summary.estimatedBalanceCents;
    final value = balance == null ? null : BigInt.parse(balance);
    final label = balanceLabel(l, balance);
    final colors = Theme.of(context).colorScheme;
    final color = value == null || value == BigInt.zero
        ? null
        : value > BigInt.zero
        ? colors.error
        : colors.primary;
    final text = Theme.of(context).textTheme;
    Widget row(String name, String amount, {TextStyle? style, Key? key}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(name, style: style)),
              Text(amount, key: key, style: style),
            ],
          ),
        );
    return Card(
      key: const Key('advance-balance'),
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.advanceBalanceTitle(summary.year.toString()),
              style: text.titleMedium,
            ),
            const SizedBox(height: 12),
            row(
              summary.complete ? l.advanceCosts : l.partialCosts,
              money(summary.netCents),
            ),
            row(l.advancePaid, money(paid)),
            const Divider(),
            row(
              label,
              value == null
                  ? '—'
                  : displayEuros(value.abs().toString(), locale: l.localeName),
              key: const Key('advance-balance-amount'),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            if (balance == null)
              Text(l.advanceBalanceUnavailable, style: text.bodySmall)
            else if (!summary.complete)
              Text(l.advanceIncomplete, style: text.bodySmall),
            Text(l.advanceEstimateNotice, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
