import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'view_model.dart';
import 'photo_entry_view.dart';
import 'overview_frame.dart';

Future<void> showReadingEntry(BuildContext context, ViewModel model) async {
  if (!model.signedIn || model.workspace?.canRecord != true) return;
  final workspaceId = model.workspace?.id;
  final points = model.activePhysicalPoints.toList();
  if (points.isEmpty) return;
  final l = AppLocalizations.of(context);
  final method = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (context) => WorkspaceScaffold(
        appBar: WorkspaceAppBar(
          model: model,
          title: const SizedBox.shrink(),
          automaticallyImplyLeading: false,
          showBillingYear: false,
        ),
        body: AppNavigationFrame(
          model: model,
          selectedIndex: -1,
          sectionRoot: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l.recordReading,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l.readingEntryHelp),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(24),
                      leading: const Icon(Icons.camera_alt_outlined),
                      title: Text(l.photoEntryTitle),
                      subtitle: Text(l.readingPhotoHelp),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, 'photo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(24),
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l.photoManual),
                      subtitle: Text(l.readingManualHelp),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, 'manual'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (!context.mounted ||
      method == null ||
      model.workspace?.id != workspaceId) {
    return;
  }
  if (method == 'photo') {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PhotoEntryView(model: model)),
    );
    return;
  }
  final id = points.length == 1
      ? points.single.id
      : await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l.chooseReadingMeter),
            children: [
              for (final point in points)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(point.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${point.name} · ${point.serial}'),
                  ),
                ),
            ],
          ),
        );
  if (!context.mounted ||
      id == null ||
      model.workspace?.id != workspaceId ||
      model.busy) {
    return;
  }
  final point = model.activePhysicalPoints.where((p) => p.id == id).firstOrNull;
  if (point == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ReadingDialog(model: model, point: point),
  );
}
