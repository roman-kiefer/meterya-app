import 'package:web/web.dart' as web;

void downloadReportURL(String url, String name) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  try {
    web.document.body!.append(anchor);
    anchor.click();
  } finally {
    anchor.remove();
  }
}
