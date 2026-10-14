import 'profile_menu.dart';
import 'audit_view.dart';
import 'app_theme.dart';
import 'brand.dart';
import 'billing_year_picker.dart';
import 'reading_entry.dart';
import 'package:flutter/material.dart';
import 'heat_view.dart';
import 'l10n/app_localizations.dart';
import 'settings_view.dart';
import 'view_model.dart';
import 'point_detail_view.dart';

/// At desktop widths the rail spans the entire window, while the workspace
/// toolbar belongs to the content pane. Mobile retains a conventional app bar.
class WorkspaceScaffold extends StatelessWidget {
  final WorkspaceAppBar appBar;
  final AppNavigationFrame body;
  const WorkspaceScaffold({
    super.key,
    required this.appBar,
    required this.body,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= 900 &&
          body.enabled &&
          body.model.signedIn &&
          body.model.error != 'MFA_REQUIRED';
      if (!desktop) {
        final navigation =
            body.enabled &&
            body.model.signedIn &&
            body.model.error != 'MFA_REQUIRED';
        return Scaffold(
          appBar: appBar,
          body: body.child,
          drawer: navigation
              ? Drawer(
                  child: SafeArea(
                    child: AppNavigationFrame(
                      model: body.model,
                      busy: body.busy,
                      selectedIndex: body.selectedIndex,
                      sectionRoot: body.sectionRoot,
                      drawerMode: true,
                      onMeterSectionSelected: body.onMeterSectionSelected,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                )
              : null,
        );
      }
      return Scaffold(
        body: AppNavigationFrame(
          model: body.model,
          enabled: body.enabled,
          busy: body.busy,
          selectedIndex: body.selectedIndex,
          sectionRoot: body.sectionRoot,
          onMeterSectionSelected: body.onMeterSectionSelected,
          child: Column(
            children: [
              SizedBox(height: appBar.preferredSize.height, child: appBar),
              Expanded(child: body.child),
            ],
          ),
        ),
      );
    },
  );
}

/// Shared primary navigation for the overview and its detail routes.
class AppNavigationFrame extends StatelessWidget {
  final ViewModel model;
  final Widget child;
  final bool enabled, busy, sectionRoot;
  final int selectedIndex;
  final bool drawerMode;
  final ValueChanged<int>? onMeterSectionSelected;
  const AppNavigationFrame({
    super.key,
    required this.model,
    required this.child,
    this.enabled = true,
    this.busy = false,
    this.selectedIndex = 0,
    this.sectionRoot = true,
    this.drawerMode = false,
    this.onMeterSectionSelected,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => _buildNavigation(context),
  );

  Widget _buildNavigation(BuildContext context) {
    if (!enabled || !model.signedIn || model.error == 'MFA_REQUIRED') {
      return child;
    }
    final l = AppLocalizations.of(context);
    final canAudit =
        model.workspace?.isAdmin == true ||
        model.workspaces.any((w) => w.isSystemAdmin);
    final sections = [
      0,
      5,
      4,
      6,
      if (model.hasHeatConfiguration) 1,
      if (canAudit) 2,
      if (canAudit) 7,
    ];
    final visibleIndex = sections.indexOf(selectedIndex);
    void select(int index) {
      final navigator = Navigator.of(context);
      if (drawerMode) navigator.pop();
      if (index == 0) {
        navigator.popUntil((route) => route.isFirst);
        return;
      }
      if (index == selectedIndex && sectionRoot) return;
      if (index >= 4 && index <= 6 && model.points.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.noPoints)));
        return;
      }
      if (index >= 4 && index <= 6 && onMeterSectionSelected != null) {
        onMeterSectionSelected!(index);
        return;
      }
      if (index == 1 && model.workspace == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.noWorkspace)));
        return;
      }
      final route = MaterialPageRoute<void>(
        builder: (_) => switch (index) {
          4 || 5 || 6 => PointDetailView(
            model: model,
            pointId: model.preferredPoint!.id,
            workspaceId: model.workspace!.id,
            initialSection: index,
          ),
          1 => HeatView(model: model),
          7 => AuditView(model: model),
          _ => SettingsView(model: model),
        },
      );
      navigator.pushAndRemoveUntil(route, (route) => route.isFirst);
    }

    void selectDestination(int index) => select(sections[index]);

    final destinations = [
      (icon: Icons.grid_view_outlined, label: l.overviewNav),
      (icon: Icons.edit_note, label: l.history),
      (icon: Icons.bolt_outlined, label: l.costsTab),
      (icon: Icons.show_chart, label: l.yearsTab),
      if (model.hasHeatConfiguration)
        (icon: Icons.heat_pump_outlined, label: l.heatTitle),
      if (canAudit) (icon: Icons.settings_outlined, label: l.settings),
      if (canAudit) (icon: Icons.receipt_long_outlined, label: l.auditTitle),
    ];
    final brand = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: const MeteryaBrand(),
    );
    final recordAction = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: FilledButton.icon(
        onPressed:
            busy ||
                model.busy ||
                model.workspace?.canRecord != true ||
                model.activePhysicalPoints.isEmpty
            ? null
            : () {
                final navigator = Navigator.of(context);
                if (drawerMode) navigator.pop();
                showReadingEntry(navigator.context, model);
              },
        icon: const Icon(Icons.add),
        label: Text(l.recordReading),
      ),
    );
    if (drawerMode) {
      return NavigationDrawer(
        selectedIndex: visibleIndex < 0 ? null : visibleIndex,
        onDestinationSelected: busy || model.busy ? null : selectDestination,
        children: [
          brand,
          recordAction,
          for (final destination in destinations)
            NavigationDrawerDestination(
              icon: Icon(destination.icon),
              label: Flexible(child: Text(destination.label)),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return child;
        return Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 220,
              leading: Column(children: [brand, recordAction]),
              selectedIndex: visibleIndex < 0 ? null : visibleIndex,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onDestinationSelected: (busy || model.busy)
                  ? null
                  : selectDestination,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Keeps workspace switching available on every main route.
class WorkspaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ViewModel model;
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool busy;
  final bool automaticallyImplyLeading;
  final bool showBillingYear;
  const WorkspaceAppBar({
    super.key,
    required this.model,
    required this.title,
    this.actions,
    this.bottom,
    this.busy = false,
    this.automaticallyImplyLeading = true,
    this.showBillingYear = true,
  });
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      return AppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading:
            MediaQuery.sizeOf(context).width < 900 &&
                Scaffold.of(context).hasDrawer
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: l.openNavigationMenu,
                  icon: const Icon(Icons.menu),
                  onPressed: busy || model.busy
                      ? null
                      : () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: !showBillingYear
            ? const SizedBox.shrink()
            : model.signedIn &&
                  model.workspace != null &&
                  model.error != 'MFA_REQUIRED'
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BillingYearPicker(
                  years: model.billingYears,
                  year: model.billingYear,
                  busy: busy || model.busy,
                  keyPrefix: 'navbar-year',
                  onChanged: model.selectBillingYear,
                ),
              )
            : title,
        titleSpacing: 4,
        bottom: bottom,
        actions: [
          if (model.signedIn &&
              model.workspace != null &&
              model.error != 'MFA_REQUIRED')
            PopupMenuButton<String>(
              key: const ValueKey('workspace-switch'),
              tooltip: l.workspace,
              enabled: !busy && !model.busy,
              initialValue: model.workspace!.id,
              onSelected: (id) {
                if (id == model.workspace!.id) return;
                final workspace = model.workspaces.firstWhere(
                  (w) => w.id == id,
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
                model.select(workspace);
              },
              itemBuilder: (_) => [
                for (final workspace in model.workspaces)
                  CheckedPopupMenuItem(
                    value: workspace.id,
                    checked: workspace.id == model.workspace!.id,
                    child: Text(workspace.name),
                  ),
              ],
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width < 600 ? 40 : 220,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (MediaQuery.sizeOf(context).width >= 600)
                      Flexible(
                        child: Text(
                          model.workspace!.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.of(context).muted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (MediaQuery.sizeOf(context).width >= 600)
                      const SizedBox(width: 4),
                    Icon(
                      MediaQuery.sizeOf(context).width < 600
                          ? Icons.home_work_outlined
                          : Icons.keyboard_arrow_down,
                      color: AppColors.of(context).muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ...?actions,
          if (model.signedIn) ProfileMenu(model: model, busy: busy),
        ],
      );
    },
  );
}
