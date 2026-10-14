import 'meter_preference.dart';

/// Optional browser persistence; selection remains usable if storage is blocked.
class MeterSelectionStore {
  final String? Function(String) read;
  final void Function(String, String) write;
  final _memory = <String, String>{};
  MeterSelectionStore({
    this.read = readMeterPreference,
    this.write = writeMeterPreference,
  });
  String? selected(String scope) {
    if (_memory.containsKey(scope)) return _memory[scope];
    try {
      return read(scope);
    } catch (_) {
      return null;
    }
  }

  void select(String scope, String id) {
    _memory[scope] = id;
    try {
      write(scope, id);
    } catch (_) {
      /* Browser privacy settings may disable storage. */
    }
  }
}
