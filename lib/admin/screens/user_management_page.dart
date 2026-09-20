import 'package:flutter/material.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/screens/admin_shell.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/state/rider_validation.dart';
import 'package:novaride/admin/widgets/filter_controls.dart';
import 'package:novaride/admin/widgets/kpi_card.dart';
import 'package:novaride/admin/widgets/rider_form_dialog.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Sortable roster columns. Sorting is driven by clicking the column header
/// rather than a separate dropdown, so there is no label extension here.
enum _RosterSort { name, helmetId, registered }

/// Rider roster and onboarding.
///
/// Riders are never hard-deleted — alert history references rider IDs, so
/// taking somebody off the road flags them inactive and parks them offline
/// instead. Past incidents stay readable and the dashboard counts stay
/// internally consistent.
///
/// Every change shows on the roster the moment it is saved and is confirmed
/// or withdrawn when the store answers (`FleetController`). A refused or
/// unanswered write is reported in a sentence that stays on screen until
/// dismissed — a rider the operator believes is saved and is not would be
/// worse than any error.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  final Set<RiderStatus> _statusFilter = {};
  String _query = '';
  _RosterSort _sort = _RosterSort.name;
  bool _ascending = true;

  /// Re-checked here rather than trusting that the nav item was hidden —
  /// hiding a tab is convenience, this is the actual gate.
  AdminRole get _role => AdminSessionScope.of(context).role;
  bool get _canManage => _role.canManageRiders;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) {
        final roster = _applyFilters(fleet);

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildKpiRow(fleet, constraints.maxWidth - 32),
                  const SizedBox(height: 12),
                  _buildRosterCard(fleet, roster),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------- KPIs

  Widget _buildKpiRow(FleetController fleet, double width) {
    final riders = fleet.riders;
    final active = riders.where((r) => r.isActive).length;
    final riding = riders.where((r) => r.status == RiderStatus.riding).length;
    final offline = riders.where((r) => r.status == RiderStatus.offline).length;
    final helmets =
        riders.where((r) => r.isActive && r.helmetId.isNotEmpty).length;

    final cards = <Widget>[
      KpiCard(
        label: 'Total Riders',
        value: '${riders.length}',
        caption: 'on the roster',
        icon: Icons.groups_outlined,
        accent: NovaColors.cyan,
      ),
      KpiCard(
        label: 'Active',
        value: '$active',
        caption: '${riders.length - active} deactivated',
        icon: Icons.verified_user_outlined,
        accent: NovaColors.green,
      ),
      KpiCard(
        label: 'Currently Riding',
        value: '$riding',
        caption: 'helmets in motion',
        icon: Icons.two_wheeler_outlined,
        accent: NovaColors.green,
      ),
      KpiCard(
        label: 'Offline',
        value: '$offline',
        caption: 'no telemetry',
        icon: Icons.cloud_off_outlined,
        accent: NovaColors.secondaryText,
      ),
      KpiCard(
        label: 'Helmets Assigned',
        value: '$helmets',
        caption: 'active pairings',
        icon: Icons.sports_motorsports_outlined,
        accent: NovaColors.purple,
      ),
    ];

    final perRow = kpiCardsPerRow(width);
    const spacing = 10.0;
    final cardWidth = (width - spacing * (perRow - 1)) / perRow;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final card in cards) SizedBox(width: cardWidth, child: card),
      ],
    );
  }

  // ------------------------------------------------------------------ roster

  Widget _buildRosterCard(FleetController fleet, List<Rider> roster) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
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
                '${roster.length} of ${fleet.riders.length}',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: _canManage ? '' : _role.restrictionMessage,
                child: ElevatedButton.icon(
                  onPressed: _canManage ? () => _openRiderForm(fleet) : null,
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Add Rider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.cyan,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: NovaColors.background,
                    disabledForegroundColor: NovaColors.secondaryText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _canManage
                            ? Colors.transparent
                            : NovaColors.cardBorder,
                      ),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFilters(),
          const SizedBox(height: 14),
          _buildHeader(),
          const Divider(height: 1, color: NovaColors.cardBorder),
          if (roster.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No riders match this search',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            for (final rider in roster) _buildRow(fleet, rider),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name, helmet ID or phone',
              hintStyle: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: NovaColors.secondaryText,
              ),
              filled: true,
              fillColor: NovaColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              border: _border(NovaColors.cardBorder),
              enabledBorder: _border(NovaColors.cardBorder),
              focusedBorder: _border(NovaColors.cyan),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const FilterGroupLabel('STATUS'),
        for (final status in RiderStatus.values)
          FilterChipButton(
            label: status.label,
            color: StatusPill.colorForRider(status),
            selected: _statusFilter.contains(status),
            onTap: () => setState(() {
              _statusFilter.contains(status)
                  ? _statusFilter.remove(status)
                  : _statusFilter.add(status);
            }),
          ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  // ------------------------------------------------------------ table header

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: _sortableHeader('NAME', _RosterSort.name)),
          Expanded(
            flex: 2,
            child: _sortableHeader('HELMET ID', _RosterSort.helmetId),
          ),
          const Expanded(flex: 3, child: _HeaderLabel('PHONE')),
          Expanded(
            flex: 2,
            child: _sortableHeader('REGISTERED', _RosterSort.registered),
          ),
          const Expanded(flex: 2, child: _HeaderLabel('STATUS')),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, _RosterSort column) {
    final active = _sort == column;

    return InkWell(
      onTap: () => setState(() {
        if (_sort == column) {
          _ascending = !_ascending;
        } else {
          _sort = column;
          _ascending = true;
        }
      }),
      child: Row(
        children: [
          Flexible(child: _HeaderLabel(label, highlighted: active)),
          const SizedBox(width: 4),
          Icon(
            active
                ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 12,
            color: active ? NovaColors.cyan : NovaColors.secondaryText,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- table row

  Widget _buildRow(FleetController fleet, Rider rider) {
    final inactive = !rider.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NovaColors.cardBorder, width: 0.5),
        ),
      ),
      // Deactivated riders stay visible but recede, so the roster reads as a
      // full history rather than hiding people who once rode.
      child: Opacity(
        opacity: inactive ? 0.55 : 1,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
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
                  if (inactive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: NovaColors.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: NovaColors.cardBorder),
                      ),
                      child: const Text(
                        'INACTIVE',
                        style: TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                rider.helmetId,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                rider.phone,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(rider.registeredAt),
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12.5,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill.rider(rider.status),
              ),
            ),
            SizedBox(width: 40, child: _buildRowMenu(fleet, rider)),
          ],
        ),
      ),
    );
  }

  Widget _buildRowMenu(FleetController fleet, Rider rider) {
    return PopupMenuButton<String>(
      tooltip: 'Rider actions',
      color: NovaColors.card,
      icon: const Icon(
        Icons.more_vert,
        size: 17,
        color: NovaColors.secondaryText,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openRiderForm(fleet, rider: rider);
          case 'toggle':
            _setActive(fleet, rider, !rider.isActive);
          case 'alerts':
            AdminNavScope.of(context).openAlertsForRider(rider.fullName);
        }
      },
      itemBuilder: (context) => [
        // Mutating entries are disabled — not hidden — for roles that cannot
        // use them, so the capability is visible and explained.
        PopupMenuItem(
          value: 'edit',
          enabled: _canManage,
          child: _MenuRow(
            Icons.edit_outlined,
            'Edit',
            disabled: !_canManage,
            tooltip: _canManage ? null : _role.restrictionMessage,
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          enabled: _canManage,
          child: _MenuRow(
            rider.isActive
                ? Icons.person_off_outlined
                : Icons.person_add_alt_1_outlined,
            rider.isActive ? 'Deactivate' : 'Reactivate',
            disabled: !_canManage,
            tooltip: _canManage ? null : _role.restrictionMessage,
          ),
        ),
        const PopupMenuItem(
          value: 'alerts',
          child: _MenuRow(Icons.notifications_none, 'View alerts'),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- filter + sort

  List<Rider> _applyFilters(FleetController fleet) {
    final matches = fleet.riders.where((rider) {
      if (_statusFilter.isNotEmpty && !_statusFilter.contains(rider.status)) {
        return false;
      }
      if (_query.isEmpty) return true;
      return '${rider.fullName} ${rider.helmetId} ${rider.phone}'
          .toLowerCase()
          .contains(_query);
    }).toList();

    matches.sort((a, b) {
      final comparison = switch (_sort) {
        _RosterSort.name =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        _RosterSort.helmetId => a.helmetId.compareTo(b.helmetId),
        _RosterSort.registered => a.registeredAt.compareTo(b.registeredAt),
      };
      return _ascending ? comparison : -comparison;
    });

    return matches;
  }

  // ---------------------------------------------------------------- actions

  Future<void> _openRiderForm(
    FleetController fleet, {
    Rider? rider,
  }) async {
    final result = await showDialog<Rider>(
      context: context,
      builder: (_) => RiderFormDialog(
        existingRiders: fleet.riders,
        rider: rider,
        suggestedRiderId: RiderValidation.nextRiderId(fleet.riders),
        suggestedHelmetId: RiderValidation.nextHelmetId(fleet.riders),
      ),
    );
    if (result == null || !mounted) return;

    if (rider == null) {
      // The saved id can move forward if another operator claimed the
      // suggested one first, so the confirmation names the id that stuck.
      _run(
        () => fleet.addRider(result),
        success: (saved) =>
            '${saved.fullName} registered as ${saved.id} — helmet '
            '${saved.helmetId} paired',
      );
    } else {
      _run(
        () => fleet.updateRider(result),
        success: (_) => '${result.fullName} updated',
      );
    }
  }

  void _setActive(FleetController fleet, Rider rider, bool active) {
    _run(
      () => fleet.setRiderActive(rider.id, active),
      success: (_) => active
          ? '${rider.fullName} is back on active duty'
          : '${rider.fullName} deactivated — alert history kept',
    );
  }

  /// Runs one roster write and reports the outcome.
  ///
  /// The controller rejects a rule violation with a [StateError] before
  /// anything is written, and the store's refusal (or silence) arrives as a
  /// [FleetWriteException] after the roster has already been rolled back;
  /// both carry a sentence for the operator and are shown as written. The
  /// success message waits for the store to accept the write, so it never
  /// claims a save the backend then refused. Anything else is a bug: logged
  /// for the developer, one sentence for the operator, never the exception.
  Future<void> _run<T>(
    Future<T> Function() action, {
    required String Function(T result) success,
  }) async {
    try {
      final result = await action();
      _toast(success(result), NovaColors.green);
    } on StateError catch (error) {
      _toast(error.message, NovaColors.red, sticky: true);
    } on FleetWriteException catch (error) {
      _toast(error.message, NovaColors.red, sticky: true);
    } catch (error, stack) {
      debugPrint('UserManagementPage: roster write threw $error\n$stack');
      _toast(
        'The change was not saved. Try again, and tell a Super Admin if it '
        'keeps happening.',
        NovaColors.red,
        sticky: true,
      );
    }
  }

  /// A confirmation clears itself; a failure stays until dismissed, so a
  /// write that did not land cannot be missed by an operator who looked
  /// away for three seconds.
  void _toast(String message, Color color, {bool sticky = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: sticky ? const Duration(days: 1) : const Duration(seconds: 3),
        action: sticky
            ? SnackBarAction(
                label: 'DISMISS',
                textColor: NovaColors.primaryText,
                onPressed: messenger.hideCurrentSnackBar,
              )
            : null,
      ),
    );
  }

  /// "12 Mar 2025" — hand-rolled to stay dependency-free.
  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _HeaderLabel(this.text, {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: highlighted ? NovaColors.cyan : NovaColors.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool disabled;

  /// Explains why the entry is unavailable for the current role.
  final String? tooltip;

  const _MenuRow(
    this.icon,
    this.label, {
    this.disabled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(
          disabled ? Icons.lock_outline : icon,
          size: 15,
          color: NovaColors.secondaryText,
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color:
                disabled ? NovaColors.secondaryText : NovaColors.primaryText,
            fontSize: 13,
          ),
        ),
      ],
    );

    if (tooltip == null) return row;
    return Tooltip(message: tooltip!, child: row);
  }
}
