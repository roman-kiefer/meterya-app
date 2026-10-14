import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'navigation.dart';
import 'view_model.dart';
import 'profile_view.dart';

/// End the app session and the identity provider session through the API.
Future<void> signOut(BuildContext context, ViewModel model) async {
  try {
    final data =
        await model.repository.api.request('/auth/logout', body: {})
            as Map<String, dynamic>;
    navigate(data['logout_url'] as String);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).genericError)),
      );
    }
  }
}

enum _ProfileAction { edit, logout }

/// The same account actions appear on every workspace route.
class ProfileMenu extends StatelessWidget {
  final ViewModel model;
  final bool busy;
  const ProfileMenu({super.key, required this.model, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<_ProfileAction>(
      key: const ValueKey('profile-menu'),
      tooltip: l.profile,
      icon: const ProfileIcon(),
      enabled: !busy && !model.busy,
      onSelected: (action) {
        switch (action) {
          case _ProfileAction.edit:
            if (ModalRoute.of(context)?.settings.name != '/profile') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/profile'),
                  builder: (_) => ProfileView(model: model),
                ),
              );
            }
          case _ProfileAction.logout:
            signOut(context, model);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: _ProfileAction.edit, child: Text(l.editProfile)),
        PopupMenuItem(value: _ProfileAction.logout, child: Text(l.logout)),
      ],
    );
  }
}

/// Draw the account glyph locally, independently of web icon font caching.
class ProfileIcon extends StatelessWidget {
  const ProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final color = (theme.color ?? Theme.of(context).colorScheme.onSurface)
        .withValues(alpha: theme.opacity ?? 1);
    return SizedBox.square(
      dimension: theme.size ?? 24,
      child: CustomPaint(painter: _ProfilePainter(color)),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  const _ProfilePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(12, 12), 9, stroke);
    canvas.drawCircle(const Offset(12, 9), 2.5, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(6.5, 18)
        ..cubicTo(7.5, 12.5, 16.5, 12.5, 17.5, 18),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProfilePainter oldDelegate) => color != oldDelegate.color;
}
