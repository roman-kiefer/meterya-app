import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'view_model.dart';
import 'api_service.dart';

class TariffViewModel extends ChangeNotifier {
  final ViewModel home;
  final Point point;
  final Future<void> Function(Tariffs, String)? onSave;
  late final List<Price> prices = [
    ...point.tariffs.basePrices,
    ...point.tariffs.unitPrices,
  ];
  String key = const Uuid().v4();
  String? error;
  bool busy = false, _disposed = false;
  TariffViewModel(this.home, this.point, {this.onSave});
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool add(
    String category,
    String period,
    String from,
    String until,
    String euros,
  ) {
    if (busy) return false;
    final amount = parsePrice(euros, base: category == 'BASE');
    final end = until.trim();
    final start = from.trim();
    if (amount == null ||
        !validDate(start) ||
        int.parse(start.substring(0, 4)) < 1900 ||
        int.parse(start.substring(0, 4)) > 9998 ||
        (end.isNotEmpty && (!validDate(end) || end.compareTo(start) <= 0))) {
      error = 'INVALID_TARIFF';
      _notify();
      return false;
    }
    if (prices.any(
      (p) =>
          p.category == category &&
          (p.until.isEmpty || start.compareTo(p.until) < 0) &&
          (end.isEmpty || p.from.compareTo(end) < 0),
    )) {
      error = 'TARIFF_OVERLAP';
      _notify();
      return false;
    }
    prices.add(Price(start, end, amount, category, period));
    prices.sort((a, b) => b.from.compareTo(a.from));
    key = const Uuid().v4();
    error = null;
    _notify();
    return true;
  }

  void remove(Price price) {
    if (busy) return;
    prices.remove(price);
    key = const Uuid().v4();
    error = null;
    _notify();
  }

  Future<bool> save() async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    final tariffs = Tariffs(
      prices.where((p) => p.category == 'BASE').toList(),
      prices.where((p) => p.category != 'BASE').toList(),
    );
    var ok = false;
    if (onSave != null) {
      try {
        await onSave!(tariffs, key);
        ok = true;
      } on ApiException catch (e) {
        error = e.code;
      } catch (_) {
        error = 'INTERNAL_ERROR';
      }
    } else {
      ok = await home.saveTariffs(point, tariffs, key);
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
