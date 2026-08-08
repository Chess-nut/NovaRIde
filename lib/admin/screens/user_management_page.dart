import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Rider roster. Editing arrives in Phase 4 — the add button is deliberately
/// disabled and labelled so the state is obvious during the demo.
///
/// Reads the app-scoped controller so a rider flipped to `emergency` by the
/// simulation shows that status here too, not the frozen seed value.
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) => _buildTable(fleet.riders),
    );
  }

  Widget _buildTable(List<Rider> riders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NovaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Registered Riders',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${riders.length} total',
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Rider onboarding arrives in Phase 4',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.person_add_alt, size: 16),
                    label: const Text('Add Rider — Phase 4'),
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: NovaColors.background,
                      disabledForegroundColor: NovaColors.secondaryText,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: NovaColors.cardBorder),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildHeader(),
            const Divider(height: 1, color: NovaColors.cardBorder),
            ...riders.map(_buildRow),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const style = TextStyle(
      color: NovaColors.secondaryText,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('HELMET ID', style: style)),
          Expanded(flex: 3, child: Text('PHONE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  Widget _buildRow(Rider rider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NovaColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              rider.fullName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rider.helmetId,
              style: const TextStyle(color: NovaColors.secondaryText, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rider.phone,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: NovaColors.primaryText, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill.rider(rider.status),
            ),
          ),
        ],
      ),
    );
  }
}
