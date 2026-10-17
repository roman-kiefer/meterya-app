import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'audit_model.dart';
import 'audit_view_model.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show errorText;
import 'models.dart' show displayQuantity, displayEuros;
import 'overview_frame.dart';
import 'view_model.dart';

class AuditView extends StatefulWidget {
  final ViewModel model;
  const AuditView({super.key, required this.model});
  @override
  State<AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends State<AuditView> {
  late final AuditViewModel audit;
  final horizontal = ScrollController();
  final expanded = <String>{};
  bool allWorkspaces = false;
  String? lastWorkspace;
  bool get systemAdmin =>
      widget.model.workspaces.any((w) => w.isSystemAdmin) ||
      widget.model.workspace?.isSystemAdmin == true;
  bool get allowed =>
      widget.model.signedIn &&
      widget.model.error != 'MFA_REQUIRED' &&
      (systemAdmin || widget.model.workspace?.isAdmin == true);
  @override
  void initState() {
    super.initState();
    audit = AuditViewModel(widget.model.repository);
    widget.model.addListener(sync);
    sync();
  }

  void sync() {
    if (!mounted) return;
    final ws = widget.model.workspace?.id;
    if (ws != lastWorkspace || !systemAdmin) allWorkspaces = false;
    lastWorkspace = ws;
    expanded.clear();
    audit.configure(
      allWorkspaces ? null : ws,
      allowed && (allWorkspaces || ws != null),
    );
    setState(() {});
  }

  @override
  void dispose() {
    widget.model.removeListener(sync);
    audit.dispose();
    horizontal.dispose();
    super.dispose();
  }

  String reference(AppLocalizations l, AuditReference ref) {
    if (ref.kind == 'operator') return l.auditOperator;
    if (ref.name?.isNotEmpty == true) return ref.name!;
    return l.auditReferenceState(
      ref.status ?? 'UNRESOLVED',
      l.auditObjectKind(ref.kind),
      ref.id,
    );
  }

  String actionLabel(AppLocalizations l, String action, {String? type}) {
    final label = l.auditAction(action);
    return label == l.auditAction('UnknownEvent')
        ? l.auditUnknownType(type ?? action)
        : label;
  }

  String detailValue(AppLocalizations l, AuditDetail d) {
    switch (d.format) {
      case 'date':
        final date = DateTime.tryParse(d.value);
        return date == null
            ? d.value
            : DateFormat.yMd(l.localeName).format(date);
      case 'timestamp':
        final time = DateTime.tryParse(d.value);
        return time == null
            ? d.value
            : DateFormat.yMd(l.localeName).add_Hm().format(time.toLocal());
      case 'explanation':
        return l.auditExplanation(d.value);
      case 'invitation_status':
        return l.auditInvitationStatus(d.value);
      case 'decimal':
        return displayQuantity(d.value, locale: l.localeName);
      case 'ct':
        return l.auditUnitPrice(displayQuantity(d.value, locale: l.localeName));
      case 'meter_type':
        return l.auditMeterType(d.value);
      case 'cents':
        return displayEuros(d.value, locale: l.localeName);
      case 'boolean':
        return d.value == 'true' ? l.auditActive : l.auditInactive;
      case 'role':
        return l.auditRole(d.value);
      case 'direction':
        return l.auditDirection(d.value);
      case 'register':
        final parts = d.value.split('|');
        return '${l.auditDirection(parts.first)} · ${parts.last}';
      case 'virtual_type':
        return l.auditVirtualType(d.value);
      case 'period':
        return l.auditPricePeriod(d.value);
      default:
        return d.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return WorkspaceScaffold(
      appBar: WorkspaceAppBar(
        model: widget.model,
        showBillingYear: false,
        automaticallyImplyLeading: false,
        title: Text(l.auditTitle),
      ),
      body: AppNavigationFrame(
        model: widget.model,
        selectedIndex: 7,
        child: ListenableBuilder(
          listenable: audit,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l.auditTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l.auditHelp),
                  const SizedBox(height: 24),
                  if (!allowed)
                    Text(l.settingsReadOnly)
                  else ...[
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 300,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              '${audit.workspaceId}-${audit.eventType}',
                            ),
                            initialValue: audit.eventType,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l.auditType),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(l.auditAllTypes),
                              ),
                              for (final type in {
                                ...audit.types,
                                if (audit.eventType.isNotEmpty) audit.eventType,
                              })
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    actionLabel(l, type),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              expanded.clear();
                              audit.filter(value ?? '');
                            },
                          ),
                        ),
                        if (systemAdmin)
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<bool>(
                              key: ValueKey(
                                'scope-$allWorkspaces-${widget.model.workspace?.id}',
                              ),
                              initialValue: allWorkspaces,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: l.auditScope,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text(
                                    widget.model.workspace?.name ??
                                        l.noWorkspace,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text(l.auditAllWorkspaces),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  allWorkspaces = value == true;
                                  expanded.clear();
                                });
                                audit.configure(
                                  allWorkspaces
                                      ? null
                                      : widget.model.workspace?.id,
                                  allowed &&
                                      (allWorkspaces ||
                                          widget.model.workspace != null),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (audit.busy) const LinearProgressIndicator(),
                    if (audit.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(errorText(l, audit.error!)),
                            TextButton.icon(
                              onPressed: () => audit.load(
                                more:
                                    audit.entries.isNotEmpty &&
                                    audit.next != null,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: Text(l.auditRetry),
                            ),
                          ],
                        ),
                      ),
                    if (!audit.busy &&
                        audit.error == null &&
                        audit.entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          audit.eventType.isEmpty
                              ? l.auditEmpty
                              : l.auditFilterEmpty,
                        ),
                      ),
                    if (audit.entries.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            table(context, constraints.maxWidth, l),
                      ),
                    if (audit.next != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Align(
                          alignment: Alignment.center,
                          child: OutlinedButton(
                            onPressed: audit.busy
                                ? null
                                : () => audit.load(more: true),
                            child: Text(l.auditLoadMore),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget table(BuildContext context, double viewport, AppLocalizations l) {
    final width = max(viewport, allWorkspaces ? 1110.0 : 930.0);
    final colors = Theme.of(context).colorScheme;
    Widget cell(Widget child, double width) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: child,
      ),
    );
    Widget text(String value) =>
        Text(value, maxLines: 3, overflow: TextOverflow.ellipsis);
    Widget row(List<Widget> cells) =>
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: cells);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scrollbar(
          controller: horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: row([
                      cell(Text(l.auditTime), 170),
                      if (allWorkspaces) cell(Text(l.auditWorkspace), 180),
                      cell(Text(l.auditUser), 230),
                      cell(Text(l.auditType), 220),
                      cell(
                        Text(l.auditObject),
                        width - (allWorkspaces ? 880 : 700),
                      ),
                      cell(Text(l.auditDetails), 80),
                    ]),
                  ),
                  for (final e in audit.entries) ...[
                    const Divider(height: 1),
                    row([
                      cell(
                        text(
                          DateFormat.yMd(
                            l.localeName,
                          ).add_Hms().format(e.occurredAt.toLocal()),
                        ),
                        170,
                      ),
                      if (allWorkspaces) cell(text(e.workspaceName), 180),
                      cell(text(reference(l, e.actor)), 230),
                      cell(text(actionLabel(l, e.action, type: e.type)), 220),
                      cell(
                        text(reference(l, e.object)),
                        width - (allWorkspaces ? 880 : 700),
                      ),
                      cell(
                        IconButton(
                          tooltip: expanded.contains(e.id)
                              ? l.auditHideDetails
                              : l.auditShowDetails,
                          onPressed: () {
                            setState(() {
                              if (!expanded.add(e.id)) expanded.remove(e.id);
                            });
                            horizontal.animateTo(
                              0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                            );
                          },
                          icon: Icon(
                            expanded.contains(e.id)
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                        ),
                        80,
                      ),
                    ]),
                    if (expanded.contains(e.id))
                      SizedBox(
                        width: viewport,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.auditDetails,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (e.details.isEmpty) Text(l.auditNoDetails),
                              for (final detail in e.details)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${l.auditDetailLabel(detail.field == 'date' ? 'readingDate' : detail.field)}: ${detailValue(l, detail)}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
