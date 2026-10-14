import 'package:web/web.dart' as web;

String? readMeterPreference(String key) => web.window.localStorage.getItem(key);
void writeMeterPreference(String key, String value) =>
    web.window.localStorage.setItem(key, value);
