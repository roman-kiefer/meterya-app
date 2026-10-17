import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Existing UI fixtures assert German text. Locale tests override this value.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('de')];
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
