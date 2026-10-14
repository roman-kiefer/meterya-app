import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

/// Offers recovery only when another change made the loaded version stale.
class ConflictReload extends StatelessWidget {
  final String? error;
  final bool busy;
  final VoidCallback onReload;

  const ConflictReload({
    super.key,
    required this.error,
    required this.busy,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    if (error != 'AGGREGATE_VERSION_CONFLICT') {
      return const SizedBox.shrink();
    }
    final label = AppLocalizations.of(context).refresh;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: label,
        child: TextButton.icon(
          onPressed: busy ? null : onReload,
          icon: const Icon(Icons.sync),
          label: Text(label),
        ),
      ),
    );
  }
}
