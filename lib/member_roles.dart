import 'l10n/app_localizations.dart';

const workspaceRoles = ['MODERATOR', 'USER', 'GUEST'];

String roleLabel(AppLocalizations l, String role) => switch (role) {
  'ADMIN' => l.adminRole,
  'MODERATOR' => l.moderatorRole,
  'GUEST' => l.guestRole,
  _ => l.userRole,
};

String roleAccess(AppLocalizations l, String role) => switch (role) {
  'ADMIN' => l.adminAccess,
  'MODERATOR' => l.moderatorAccess,
  'GUEST' => l.guestAccess,
  _ => l.userAccess,
};

String invitationStatus(AppLocalizations l, String status, DateTime expires) {
  if (status != 'ACCEPTED' &&
      status != 'REVOKED' &&
      DateTime.now().isAfter(expires)) {
    return l.expiredInvite;
  }
  return switch (status) {
    'SENT' => l.sentInvite,
    'FAILED' => l.failedInvite,
    'ACCEPTED' => l.acceptedInvite,
    'REVOKED' => l.revokedInvite,
    _ => l.pendingInvite,
  };
}
