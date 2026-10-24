import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

/// Shared wordmark for the navigation and sign-in header.
class MeteryaBrand extends StatelessWidget {
  const MeteryaBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/branding/logo.png',
        width: 36,
        height: 36,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.high,
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          AppLocalizations.of(context).appTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ],
  );
}
