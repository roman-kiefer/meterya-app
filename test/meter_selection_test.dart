import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/meter_selection_store.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  test(
    'meter selection survives a new model and stays scoped to user and workspace',
    () {
      final browser = <String, String>{};
      ViewModel model(String subject, String workspace) {
        final repository = Repository(
          ApiService(
            MockClient((r) async => http.Response('{}', 200)),
            Uri.parse('http://localhost'),
          ),
        )..subject = subject;
        return ViewModel(
            repository,
            meterSelections: MeterSelectionStore(
              read: (key) => browser[key],
              write: (key, value) => browser[key] = value,
            ),
          )
          ..workspace = Workspace(workspace, 'House', 'USER')
          ..points = [
            Point('first', 'First', 'one', 1, [], []),
            Point('second', 'Second', 'two', 1, [], []),
          ];
      }

      final original = model('alice', 'house');
      original.rememberPoint('second');
      expect(model('alice', 'house').preferredPoint!.id, 'second');
      expect(model('alice', 'other').preferredPoint!.id, 'first');
      expect(model('bob', 'house').preferredPoint!.id, 'first');
      final afterRemoval = model('alice', 'house')..points.removeLast();
      expect(afterRemoval.preferredPoint!.id, 'first');
      afterRemoval.points.clear();
      expect(afterRemoval.preferredPoint, isNull);
    },
  );
  test('blocked browser storage keeps selection in memory', () {
    final storage = MeterSelectionStore(
      read: (_) => throw StateError('blocked'),
      write: (_, _) => throw StateError('blocked'),
    );
    expect(storage.selected('scope'), isNull);
    storage.select('scope', 'second');
    expect(storage.selected('scope'), 'second');
  });
}
