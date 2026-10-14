import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';

/// Controlled register selection shared by reading and billing views.
class RegisterTabs extends StatelessWidget {
  final List<Register> registers;
  final String selectedId;
  final ValueChanged<String> onChanged;
  const RegisterTabs({
    super.key,
    required this.registers,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (registers.length < 2) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      key: ValueKey('$selectedId-${registers.map((r) => r.id).join(',')}'),
      length: registers.length,
      initialIndex: registers.indexWhere((r) => r.id == selectedId),
      child: TabBar(
        tabAlignment: TabAlignment.start,
        isScrollable: true,
        tabs: [
          for (final register in registers)
            Tab(text: registerName(l, register)),
        ],
        onTap: (index) => onChanged(registers[index].id),
      ),
    );
  }
}
