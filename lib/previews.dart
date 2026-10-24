import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'version_footer.dart';

@Preview(name: 'Version footer', size: Size(280, 140))
Widget versionFooterPreview() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: meteryaTheme(),
  home: const Scaffold(
    body: VersionFooter(ui: 'v1.2.3', apiVersion: 'v1.2.1'),
  ),
);
