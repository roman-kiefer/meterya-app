import 'dart:async';
import 'version_footer.dart';
import 'profile_menu.dart';
import 'profile_view.dart';
import 'login_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'navigation.dart';
import 'repository.dart';
import 'view_model.dart';
import 'overview_dashboard.dart';
import 'overview_frame.dart';
import 'app_theme.dart';

void main() {
  final model = ViewModel(Repository(ApiService(http.Client(), Uri.base)));
  runApp(MeteryaApp(model: model));
  unawaited(model.loadVersion());
  final invitation = Uri.base.path == '/invitations/accept'
      ? Uri.base.queryParameters['token']
      : null;
  initializeSession(model, invitation);
}

Future<void> initializeSession(
  ViewModel model,
  String? invitation, {
  void Function(String) redirect = navigate,
}) async {
  await model.initialize(invitationToken: invitation);
  if (invitation == null) return;
  if (model.error == 'MFA_REQUIRED') {
    redirect(
      Uri(
        path: '/auth/login',
        queryParameters: {
          'mfa': '1',
          'return_to': Uri(
            path: '/invitations/accept',
            queryParameters: {'token': invitation},
          ).toString(),
        },
      ).toString(),
    );
  } else if (model.signedIn && model.error == null) {
    redirect('/');
  }
}

class MeteryaApp extends StatelessWidget {
  final ViewModel model;
  const MeteryaApp({super.key, required this.model});
  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: meteryaTheme(),
    darkTheme: meteryaTheme(brightness: Brightness.dark),
    themeMode: ThemeMode.system,
    initialRoute: Uri.base.path == '/profile' ? '/profile' : '/',
    routes: {'/profile': (_) => ProfileView(model: model)},
    home: Home(model: model),
  );
}

String errorText(AppLocalizations l, String code) => switch (code) {
  'PHOTO_TOO_LARGE' ||
  'PHOTO_INVALID' ||
  'PHOTO_FORMAT_UNSUPPORTED' ||
  'PHOTO_UNAVAILABLE' ||
  'PHOTO_DRAFT_LIMIT' ||
  'PHOTO_READING_MISMATCH' ||
  'PHOTO_OCR_BUSY' ||
  'PHOTO_ARCHIVE_REQUIRED' ||
  'BACKUP_BUSY' ||
  'BACKUP_NOT_READY' ||
  'BACKUP_PHOTO_INVALID' ||
  'PHOTO_MISSING' => l.photoError(code),
  'TRANSITION_READING_REQUIRED' => l.transitionMissingError,
  'READING_OUTSIDE_METER_PERIOD' => l.transitionPeriodError,
  'TRANSITION_ALREADY_LINKED' => l.transitionLinkedError,
  'BACKUP_INVALID' => l.backupInvalid,
  'BACKUP_SCHEMA_MISMATCH' => l.backupSchemaMismatch,
  'BACKUP_TOO_LARGE' => l.backupTooLarge,
  'BACKUP_CONFIRMATION_REQUIRED' => l.backupReplaceWarning,
  'AUTHENTICATION_REQUIRED' => l.sessionExpired,
  'LAST_WORKSPACE_ADMIN' => l.lastWorkspaceAdmin,
  'MFA_REQUIRED' => l.mfaRequired,
  'PERMISSION_DENIED' => l.permissionError,
  'READING_ALREADY_EXISTS' => l.duplicateError,
  'CONFLICT' ||
  'AGGREGATE_VERSION_CONFLICT' ||
  'IDEMPOTENCY_CONFLICT' => l.conflictError,
  'VALIDATION_FAILED' ||
  'INVALID_DECIMAL' ||
  'INVALID_DATE' ||
  'READING_NOT_MONOTONIC' ||
  'READING_DECREASES' ||
  'REGISTER_NOT_FOUND' => l.validationError,
  'INVITATION_INVALID' ||
  'INVITATION_EXPIRED' ||
  'INVITATION_UNAVAILABLE' ||
  'INVITATION_EMAIL_MISMATCH' => l.invitationError,
  'INVALID_TARIFF' => l.invalidTariff,
  'POINT_ARCHIVED' => l.pointArchivedError,
  'POINT_LINKED' => l.movePointLinked,
  'VIRTUAL_SOURCE_IN_USE' => l.virtualSourceInUse,
  'VIRTUAL_ALREADY_EXISTS' => l.virtualAlreadyExists,
  'VIRTUAL_AMBIGUOUS' || 'VIRTUAL_CONTINUATION_REQUIRED' => l.virtualAmbiguous,
  'VIRTUAL_INCOMPATIBLE' || 'VIRTUAL_CYCLE' => l.virtualIncompatible,
  'VIRTUAL_TRANSITION_REQUIRED' => l.virtualTransitionRequired,
  'SOURCE_MISSING' => l.virtualSourceMissing,
  'MEASUREMENT_GAP' => l.measurementGap,
  'NEGATIVE_BALANCE' => l.heatNegative,
  'INSUFFICIENT_READINGS' => l.noBillingReadings,
  'MISSING_COMMON_EXPORT_READINGS' => l.heatMissingAll,
  'SERIAL_ALREADY_ACTIVE' => l.serialAlreadyActive,
  'RESOURCE_NOT_FOUND' => l.settingsUnavailable,
  'TARIFF_OVERLAP' => l.tariffOverlap,
  _ => l.genericError,
};
String registerName(AppLocalizations l, Register register) =>
    switch (register.direction) {
      'IMPORT' => l.importRegister,
      'EXPORT' => l.exportRegister,
      'SELF' => l.virtualPV,
      _ => l.consumptionRegister,
    };

class Home extends StatelessWidget {
  final ViewModel model;
  const Home({super.key, required this.model});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final invitation = Uri.base.path == '/invitations/accept'
            ? Uri.base.queryParameters['token']
            : null;
        final needsMfa = model.error == 'MFA_REQUIRED';

        if (!model.signedIn || needsMfa) {
          return LoginView(
            footer: VersionFooter(
              apiVersion: model.apiVersion,
              loading: model.versionLoading,
            ),
            busy: model.busy,
            onLogout: model.signedIn ? () => signOut(context, model) : null,
            error:
                model.error == null || model.error == 'AUTHENTICATION_REQUIRED'
                ? null
                : errorText(l, model.error!),
            onLogin: () {
              final login = Uri(
                path: '/auth/login',
                queryParameters: {
                  if (needsMfa) 'mfa': '1',
                  if (invitation != null)
                    'return_to':
                        Uri.base.path +
                        (Uri.base.hasQuery ? '?${Uri.base.query}' : ''),
                },
              );
              navigate(login.toString());
            },
          );
        }

        return WorkspaceScaffold(
          appBar: WorkspaceAppBar(model: model, title: const SizedBox.shrink()),
          body: AppNavigationFrame(
            model: model,
            enabled: model.signedIn && !needsMfa,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (model.busy) const LinearProgressIndicator(),
                    if (model.error != null &&
                        model.error != 'AUTHENTICATION_REQUIRED')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          errorText(l, model.error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ...[
                      if (invitation != null)
                        if (model.error == null)
                          Text(l.invitationActivating)
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: model.busy
                                  ? null
                                  : () => initializeSession(model, invitation),
                              child: Text(l.retryInvitationActivation),
                            ),
                          )
                      else if (model.workspaces.isEmpty)
                        Text(l.noWorkspace),
                      if (model.workspace != null) ...[
                        OverviewDashboard(
                          key: ValueKey('dashboard-${model.workspace!.id}'),
                          model: model,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PointDialog extends StatefulWidget {
  final ViewModel model;
  const PointDialog({super.key, required this.model});
  @override
  State<PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<PointDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), serial = TextEditingController();
  String type = 'ELECTRICITY';
  String? error;
  String key = const Uuid().v4();
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    serial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.createPoint),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          onChanged: () {
            if (!saving) key = const Uuid().v4();
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  maxLength: 200,
                  decoration: InputDecoration(labelText: l.name),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l.required : null,
                ),
                TextFormField(
                  controller: serial,
                  enabled: !saving,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l.serial),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l.required : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: l.type),
                  items: [
                    DropdownMenuItem(value: 'WATER', child: Text(l.water)),
                    DropdownMenuItem(
                      value: 'ELECTRICITY',
                      child: Text(l.electricity),
                    ),
                    DropdownMenuItem(
                      value: 'BIDIRECTIONAL',
                      child: Text(l.bidirectional),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          type = v!;
                          key = const Uuid().v4();
                        },
                ),
                if (error != null) Text(errorText(l, error!)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  final success = await widget.model.create(
                    name.text.trim(),
                    serial.text.trim(),
                    type,
                    key,
                  );
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      saving = false;
                      error = widget.model.error;
                    });
                  }
                },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class ReadingDialog extends StatefulWidget {
  final ViewModel model;
  final Point point;
  const ReadingDialog({super.key, required this.model, required this.point});
  @override
  State<ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<ReadingDialog> {
  final form = GlobalKey<FormState>();
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final value = TextEditingController();
  late Register register = widget.point.registers.first;
  String? error;
  String key = const Uuid().v4();
  bool saving = false;
  @override
  void dispose() {
    date.dispose();
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.recordReading),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          onChanged: () {
            if (!saving) key = const Uuid().v4();
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: register.id,
                  decoration: InputDecoration(labelText: l.register),
                  items: widget.point.registers
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text('${registerName(l, r)} (${r.unit})'),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (id) {
                          register = widget.point.registers.firstWhere(
                            (r) => r.id == id,
                          );
                          key = const Uuid().v4();
                        },
                ),
                TextFormField(
                  controller: date,
                  enabled: !saving,
                  decoration: InputDecoration(labelText: l.date),
                  validator: (v) =>
                      v != null && validDate(v) ? null : l.invalidDate,
                ),
                TextFormField(
                  controller: value,
                  enabled: !saving,
                  decoration: InputDecoration(labelText: l.value),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      normalizeReading(v ?? '') == null ? l.invalidValue : null,
                ),
                if (error != null) Text(errorText(l, error!)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  final success = await widget.model.record(
                    widget.point,
                    register,
                    date.text,
                    normalizeReading(value.text)!,
                    key,
                  );
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      saving = false;
                      error = widget.model.error;
                    });
                  }
                },
          child: Text(l.save),
        ),
      ],
    );
  }
}
