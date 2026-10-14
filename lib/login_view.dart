import 'package:flutter/material.dart';
import 'brand.dart';
import 'l10n/app_localizations.dart';

/// Compact sign-in surface; authentication remains in the existing flow.
class LoginView extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onLogin;
  final VoidCallback? onLogout;
  const LoginView({
    super.key,
    required this.busy,
    required this.onLogin,
    this.error,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 360,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MeteryaBrand(),
                    const SizedBox(height: 32),
                    if (error != null) ...[
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    FilledButton(
                      onPressed: busy ? null : onLogin,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).login,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (onLogout != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: busy ? null : onLogout,
                        child: Text(AppLocalizations.of(context).logout),
                      ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
