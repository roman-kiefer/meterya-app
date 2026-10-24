import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

const uiVersion = String.fromEnvironment('UI_VERSION', defaultValue: 'dev');

/// Build and server versions are independent, including their loading state.
class VersionFooter extends StatelessWidget {
  final String ui;
  final String? apiVersion;
  final bool loading;

  const VersionFooter({
    super.key,
    this.ui = uiVersion,
    this.apiVersion,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UI: $ui'),
            Text('API: ${loading ? '…' : apiVersion ?? l.versionUnavailable}'),
          ],
        ),
      ),
    );
  }
}
