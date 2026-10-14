import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'backup_files.dart';
import 'backup_view_model.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'navigation.dart';
import 'report_delivery.dart';
import 'view_model.dart';
import 'overview_frame.dart';

class BackupView extends StatefulWidget {
  final ViewModel model;
  final Future<({String name, String contents})?> Function()? pickFile;
  const BackupView({super.key, required this.model, this.pickFile});
  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  late final backup = BackupViewModel(widget.model.repository.api);
  final confirmation = TextEditingController();
  String? fileError;
  @override
  void dispose() {
    backup.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: backup,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final preview = backup.preview;
      final needsLogin =
          backup.error == 'AUTHENTICATION_REQUIRED' ||
          backup.error == 'MFA_REQUIRED';
      return PopScope(
        canPop: !backup.busy,
        child: WorkspaceScaffold(
          appBar: WorkspaceAppBar(
            showBillingYear: false,
            model: widget.model,
            busy: backup.busy,
            title: Text(l.backupTitle),
          ),
          body: AppNavigationFrame(
            model: widget.model,
            selectedIndex: 2,
            sectionRoot: false,
            busy: backup.busy,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(l.backupScope),
                    const SizedBox(height: 16),
                    if (backup.busy) const LinearProgressIndicator(),
                    if (backup.busy)
                      Text(
                        backup.total > 0
                            ? '${l.backupPreparing} ${backup.completed} / ${backup.total}'
                            : l.backupPreparing,
                      ),
                    if (backup.error != null || fileError != null)
                      Text(
                        errorText(l, backup.error ?? fileError!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (needsLogin)
                      FilledButton(
                        onPressed: () => navigate('/auth/login?mfa=1'),
                        child: Text(l.login),
                      ),
                    if (backup.restored) ...[
                      Text(l.backupRestored),
                      FilledButton(
                        onPressed: () => navigate('/auth/login?mfa=1'),
                        child: Text(l.login),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: backup.busy
                            ? null
                            : () async {
                                final url = await backup.prepareDownload();
                                if (url != null && context.mounted) {
                                  downloadReportURL(
                                    widget.model.repository.api.base
                                        .resolve(url)
                                        .toString(),
                                    'meterya-backup.zip',
                                  );
                                }
                              },
                        icon: const Icon(Icons.download),
                        label: Text(l.backupDownload),
                      ),
                      Text(l.backupZIPHint),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: backup.busy
                            ? null
                            : () async {
                                setState(() {
                                  fileError = null;
                                });
                                backup.clearSelection();
                                try {
                                  if (widget.pickFile == null) {
                                    final file = await pickBackupArchive();
                                    if (file == null || !mounted) return;
                                    confirmation.clear();
                                    await backup.validateArchive(file);
                                    return;
                                  }
                                  final file =
                                      await (widget.pickFile ??
                                          pickBackupFile)();
                                  if (file == null || !mounted) return;
                                  confirmation.clear();
                                  await backup.validate(
                                    file.name,
                                    file.contents,
                                  );
                                } on ApiException catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      fileError = e.code;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() {
                                      fileError = 'BACKUP_INVALID';
                                    });
                                  }
                                }
                              },
                        icon: const Icon(Icons.upload_file),
                        label: Text(l.backupSelect),
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 16),
                        Text(backup.filename!),
                        Text(
                          l.backupSummary(
                            DateFormat.yMd(l.localeName).add_Hm().format(
                              DateTime.parse(
                                preview['created_at'] as String,
                              ).toLocal(),
                            ),
                            preview['workspaces'] as int,
                            preview['points'] as int,
                            preview['readings'] as int,
                            preview['events'] as int,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (preview['contains_photos'] == true)
                          Text(
                            l.backupPhotoCount(preview['photos'] as int? ?? 0),
                          )
                        else
                          Text(l.backupNoPhotos),
                        Text(l.backupReplaceWarning),
                        TextField(
                          controller: confirmation,
                          decoration: InputDecoration(
                            labelText: l.backupConfirmLabel,
                          ),
                          onChanged: (_) => setState(() {}),
                          enabled: !backup.busy,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              backup.busy ||
                                  confirmation.text != l.backupConfirmWord
                              ? null
                              : () async {
                                  if (await backup.restore()) {
                                    widget.model.signedIn = false;
                                    widget.model.workspaces = [];
                                    widget.model.workspace = null;
                                    widget.model.points = [];
                                    widget.model.repository.isOperator = false;
                                    await widget.model.refresh();
                                  }
                                },
                          child: Text(l.backupRestore),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
