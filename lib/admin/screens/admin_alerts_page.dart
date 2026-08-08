import 'package:flutter/material.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/state/mock_fleet_controller.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/kpi_card.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

enum _AlertSort { newest, oldest, priority }

extension _AlertSortLabel on _AlertSort {
  String get label => switch (this) {
        _AlertSort.newest => 'Newest',
        _AlertSort.oldest => 'Oldest',
        _AlertSort.priority => 'Priority',
      };
}

/// Alert triage — where the console stops being a monitor and becomes a
/// response tool.
///
/// The research problem is time-to-response, so this page is built around
/// moving an alert through open → acknowledged → dispatched → resolved and
/// recording who did it. Filters exist because an operator with forty alerts
/// on the board needs the three that matter.
class AdminAlertsPage extends StatefulWidget {
  const AdminAlertsPage({super.key});

  @override
  State<AdminAlertsPage> createState() => _AdminAlertsPageState();
}

class _AdminAlertsPageState extends State<AdminAlertsPage> {
  /// Matches the dashboard's breakpoint: below this the detail panel stops
  /// sitting beside the list and reflows above it in one scrolling column.
  static const _stackBreakpoint = 1100.0;

  /// Phase 6 replaces this with the signed-in admin's name.
  static const _operator = 'Ops Admin';

  final TextEditingController _searchController = TextEditingController();

  /// Empty means "no filter" rather than "match nothing" — an empty set is
  /// the natural state and avoids seeding every enum value up front.
  final Set<AlertStatus> _statusFilter = {};
  final Set<AlertType> _typeFilter = {};

  String _query = '';
  _AlertSort _sort = _AlertSort.newest;
  String? _selectedId;

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
        final visible = _applyFilters(fleet);

        // The selection survives the simulation ageing an alert off the
        // board, so resolve the id every build instead of holding the object.
        final selected = _selectedId == null
            ? null
            : fleet.alerts.where((a) => a.id == _selectedId).firstOrNull;

        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < _stackBreakpoint;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: stacked
                  ? _buildStacked(fleet, visible, selected, constraints.maxWidth)
                  : _buildWide(fleet, visible, selected, constraints.maxWidth),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------------- layout

  Widget _buildWide(
    MockFleetController fleet,
    List<AlertEvent> visible,
    AlertEvent? selected,
    double width,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKpiRow(fleet, width),
        const SizedBox(height: 12),
        _buildFilterBar(),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildListCard(visible, scrollable: true)),
              if (selected != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    child: _AlertDetailPanel(
                      alert: selected,
                      fleet: fleet,
                      onClose: () => setState(() => _selectedId = null),
                      onAcknowledge: () => _acknowledge(fleet, selected),
                      onDispatch: () => _promptDispatch(fleet, selected),
                      onResolve: () => _resolve(fleet, selected),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStacked(
    MockFleetController fleet,
    List<AlertEvent> visible,
    AlertEvent? selected,
    double width,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiRow(fleet, width),
          const SizedBox(height: 12),
          _buildFilterBar(),
          const SizedBox(height: 12),
          if (selected != null) ...[
            _AlertDetailPanel(
              alert: selected,
              fleet: fleet,
              onClose: () => setState(() => _selectedId = null),
              onAcknowledge: () => _acknowledge(fleet, selected),
              onDispatch: () => _promptDispatch(fleet, selected),
              onResolve: () => _resolve(fleet, selected),
            ),
            const SizedBox(height: 12),
          ],
          _buildListCard(visible, scrollable: false),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- KPIs

  Widget _buildKpiRow(MockFleetController fleet, double width) {
    final counts = {for (final s in AlertStatus.values) s: 0};
    for (final a in fleet.alerts) {
      counts[a.status] = counts[a.status]! + 1;
    }

    final now = DateTime.now();
    final resolvedToday = fleet.alerts.where((a) {
      final at = a.reachedAt(AlertStatus.resolved);
      return at != null &&
          at.year == now.year &&
          at.month == now.month &&
          at.day == now.day;
    }).length;

    final cards = <Widget>[
      KpiCard(
        label: 'Open',
        value: '${counts[AlertStatus.open]}',
        caption: '${fleet.openCriticalCount} critical active',
        icon: Icons.error_outline,
        accent: NovaColors.red,
        alarmed: counts[AlertStatus.open]! > 0,
      ),
      KpiCard(
        label: 'Acknowledged',
        value: '${counts[AlertStatus.acknowledged]}',
        caption: 'operator has the call',
        icon: Icons.visibility_outlined,
        accent: NovaColors.cyan,
      ),
      KpiCard(
        label: 'Dispatched',
        value: '${counts[AlertStatus.dispatched]}',
        caption: 'responders en route',
        icon: Icons.local_shipping_outlined,
        accent: NovaColors.pink,
      ),
      KpiCard(
        label: 'Resolved Today',
        value: '$resolvedToday',
        caption: 'closed this session',
        icon: Icons.check_circle_outline,
        accent: NovaColors.green,
      ),
      KpiCard(
        label: 'Avg. Response',
        value: formatDuration(fleet.averageAcknowledgeTime),
        caption: 'alert → acknowledged',
        icon: Icons.timer_outlined,
        accent: NovaColors.amber,
      ),
    ];

    final perRow = width >= 1100
        ? 5
        : width >= 760
            ? 3
            : 2;
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

  // ------------------------------------------------------------- filter bar

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 260, child: _buildSearchField()),
              _buildSortControl(),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _FilterGroupLabel('STATUS'),
              for (final status in AlertStatus.values)
                _FilterChip(
                  label: status.label,
                  color: StatusPill.colorForAlert(status),
                  selected: _statusFilter.contains(status),
                  onTap: () => setState(() {
                    _statusFilter.contains(status)
                        ? _statusFilter.remove(status)
                        : _statusFilter.add(status);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _FilterGroupLabel('TYPE'),
              for (final type in AlertType.values)
                _FilterChip(
                  label: type.label,
                  color: AlertFeedTile.colorFor(type),
                  selected: _typeFilter.contains(type),
                  onTap: () => setState(() {
                    _typeFilter.contains(type)
                        ? _typeFilter.remove(type)
                        : _typeFilter.add(type);
                  }),
                ),
              if (_statusFilter.isNotEmpty ||
                  _typeFilter.isNotEmpty ||
                  _query.isNotEmpty)
                _FilterChip(
                  label: 'Clear filters',
                  color: NovaColors.secondaryText,
                  selected: false,
                  onTap: () => setState(() {
                    _statusFilter.clear();
                    _typeFilter.clear();
                    _searchController.clear();
                    _query = '';
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      style: const TextStyle(color: NovaColors.primaryText, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Rider, helmet ID, alert ID, address',
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
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: _searchBorder(NovaColors.cardBorder),
        enabledBorder: _searchBorder(NovaColors.cardBorder),
        focusedBorder: _searchBorder(NovaColors.cyan),
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );

  Widget _buildSortControl() {
    return PopupMenuButton<_AlertSort>(
      initialValue: _sort,
      color: NovaColors.card,
      tooltip: 'Sort alerts',
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final option in _AlertSort.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: NovaColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NovaColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 16, color: NovaColors.secondaryText),
            const SizedBox(width: 7),
            Text(
              'Sort: ${_sort.label}',
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- alert list

  Widget _buildListCard(List<AlertEvent> visible, {required bool scrollable}) {
    final header = Row(
      children: [
        const Text(
          'Alert queue',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '${visible.length} shown',
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
        ),
      ],
    );

    final Widget body;
    if (visible.isEmpty) {
      body = const _EmptyState();
    } else if (scrollable) {
      body = ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: visible.length,
        itemBuilder: (context, i) => _tileFor(visible[i]),
      );
    } else {
      body = Column(children: [for (final alert in visible) _tileFor(alert)]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: 12),
          if (scrollable) Expanded(child: body) else body,
        ],
      ),
    );
  }

  Widget _tileFor(AlertEvent alert) => AlertFeedTile(
        key: ValueKey(alert.id),
        alert: alert,
        selected: alert.id == _selectedId,
        onTap: () => setState(
          () => _selectedId = _selectedId == alert.id ? null : alert.id,
        ),
      );

  // ----------------------------------------------------------- filter + sort

  List<AlertEvent> _applyFilters(MockFleetController fleet) {
    final matches = fleet.alerts.where((alert) {
      if (_statusFilter.isNotEmpty && !_statusFilter.contains(alert.status)) {
        return false;
      }
      if (_typeFilter.isNotEmpty && !_typeFilter.contains(alert.type)) {
        return false;
      }
      if (_query.isEmpty) return true;

      final helmetId = fleet.riderFor(alert.riderId)?.helmetId ?? '';
      final haystack = [
        alert.riderName,
        helmetId,
        alert.id,
        alert.address,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();

    matches.sort(switch (_sort) {
      _AlertSort.newest => (a, b) => b.timestamp.compareTo(a.timestamp),
      _AlertSort.oldest => (a, b) => a.timestamp.compareTo(b.timestamp),
      // Critical first; ties keep newest-first so the freshest crash leads.
      _AlertSort.priority => (a, b) {
          final byPriority = MockFleetController.priorityOf(a)
              .index
              .compareTo(MockFleetController.priorityOf(b).index);
          if (byPriority != 0) return byPriority;
          return b.timestamp.compareTo(a.timestamp);
        },
    });

    return matches;
  }

  // ---------------------------------------------------------------- actions

  /// Every mutation goes through here: the controller rejects an illegal
  /// transition with a descriptive [StateError], and the operator sees why
  /// instead of watching a button do nothing.
  void _run(VoidCallback action) {
    try {
      action();
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: NovaColors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _acknowledge(MockFleetController fleet, AlertEvent alert) {
    _run(() => fleet.acknowledgeAlert(alert.id, actor: _operator));
  }

  void _resolve(MockFleetController fleet, AlertEvent alert) {
    _run(() => fleet.resolveAlert(alert.id, actor: _operator));
  }

  Future<void> _promptDispatch(
    MockFleetController fleet,
    AlertEvent alert,
  ) async {
    final result = await showDialog<_DispatchChoice>(
      context: context,
      builder: (_) => _DispatchDialog(alert: alert),
    );
    if (result == null || !mounted) return;

    _run(
      () => fleet.dispatchAlert(
        alert.id,
        actor: _operator,
        responder: result.responder,
        note: result.note,
      ),
    );
  }
}

/// "1m 04s" / "2h 13m" / "—". Hand-rolled: intl would be a dependency for
/// one format string.
String formatDuration(Duration? duration) {
  if (duration == null) return '—';
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${duration.inMinutes}m ${seconds}s';
  }
  return '${duration.inSeconds}s';
}

String _clock(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final second = t.second.toString().padLeft(2, '0');
  return '$hour12:$minute:$second ${t.hour < 12 ? 'AM' : 'PM'}';
}

// ---------------------------------------------------------------- detail pane

/// Everything an operator needs to act on one alert: who and where, what the
/// helmet was reporting, what has been done so far, and what can be done next.
class _AlertDetailPanel extends StatelessWidget {
  final AlertEvent alert;
  final MockFleetController fleet;
  final VoidCallback onClose;
  final VoidCallback onAcknowledge;
  final VoidCallback onDispatch;
  final VoidCallback onResolve;

  const _AlertDetailPanel({
    required this.alert,
    required this.fleet,
    required this.onClose,
    required this.onAcknowledge,
    required this.onDispatch,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final rider = fleet.riderFor(alert.riderId);
    final telemetry = fleet.telemetryFor(alert.riderId);
    final district = MockFleetController.nearestDistrict(alert.lat, alert.lng);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _section('RIDER'),
          _row('Name', rider?.fullName ?? alert.riderName),
          _row('Rider ID', alert.riderId),
          _row('Helmet ID', rider?.helmetId ?? 'unassigned'),
          _row('Phone', rider?.phone ?? '—'),
          if (rider != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StatusPill.rider(rider.status),
            ),
          const SizedBox(height: 14),
          _section('TELEMETRY SNAPSHOT'),
          if (telemetry == null)
            _muted('No helmet telemetry for this rider.')
          else ...[
            _row('Speed', '${telemetry.speedKmh.toStringAsFixed(1)} km/h'),
            _row('Battery', '${telemetry.batteryPct}%'),
            _row(
              'Alcohol',
              telemetry.alcoholLevel.toStringAsFixed(2),
              valueColor: telemetry.alcoholLevel > kAlcoholWarningLevel
                  ? NovaColors.amber
                  : null,
            ),
            _row('GPS fix', telemetry.gpsFix ? 'Locked' : 'No fix'),
          ],
          const SizedBox(height: 14),
          _section('LOCATION'),
          _row('Address', alert.address),
          _row('District', district.name),
          _row(
            'Coordinates',
            '${alert.lat.toStringAsFixed(5)}, ${alert.lng.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 14),
          _section('RESPONSE TIMELINE'),
          _AlertTimeline(alert: alert),
          const SizedBox(height: 14),
          _section('ACTIONS'),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final color = AlertFeedTile.colorFor(alert.type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(AlertFeedTile.iconFor(alert.type), color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.type.label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${alert.id} · raised ${_clock(alert.timestamp)}',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              StatusPill.alert(alert.status),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close panel',
          icon: const Icon(
            Icons.close,
            size: 18,
            color: NovaColors.secondaryText,
          ),
        ),
      ],
    );
  }

  /// All three lifecycle actions stay tappable, with the legal next step
  /// filled and the rest muted. Attempting an out-of-order action surfaces
  /// the controller's rejection in a SnackBar — the protocol is enforced and
  /// visible, rather than hidden behind a disabled button.
  Widget _buildActions() {
    if (alert.status == AlertStatus.resolved) {
      return _muted('This incident is closed. No further action available.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
          label: 'Acknowledge',
          icon: Icons.visibility_outlined,
          color: NovaColors.cyan,
          primary: alert.status.canTransitionTo(AlertStatus.acknowledged),
          onPressed: onAcknowledge,
        ),
        _ActionButton(
          label: 'Dispatch',
          icon: Icons.local_shipping_outlined,
          color: NovaColors.pink,
          primary: alert.status.canTransitionTo(AlertStatus.dispatched),
          onPressed: onDispatch,
        ),
        _ActionButton(
          label: 'Resolve',
          icon: Icons.check_circle_outline,
          color: NovaColors.green,
          primary: alert.status.canTransitionTo(AlertStatus.resolved),
          onPressed: onResolve,
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? NovaColors.primaryText,
                  fontSize: 12.5,
                  fontWeight:
                      valueColor == null ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _muted(String text) => Text(
        text,
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
      );
}

/// Vertical audit trail. The first node is the alert firing itself — it has
/// no [AlertAction] behind it, but a timeline that starts at "acknowledged"
/// hides the number that matters most.
class _AlertTimeline extends StatelessWidget {
  final AlertEvent alert;

  const _AlertTimeline({required this.alert});

  @override
  Widget build(BuildContext context) {
    final nodes = <Widget>[
      _node(
        color: AlertFeedTile.colorFor(alert.type),
        title: 'Alert raised',
        subtitle: 'Helmet ${alert.type.label.toLowerCase()}',
        at: alert.timestamp,
        isLast: alert.history.isEmpty,
      ),
    ];

    for (var i = 0; i < alert.history.length; i++) {
      final action = alert.history[i];
      final elapsed = action.at.difference(alert.timestamp);
      final detail = <String>[
        action.actorName,
        if (action.responder != null) action.responder!.label,
        '+${formatDuration(elapsed)}',
      ].join(' · ');

      nodes.add(
        _node(
          color: StatusPill.colorForAlert(action.toStatus),
          title: action.toStatus.label,
          subtitle: detail,
          note: action.note,
          at: action.at,
          isLast: i == alert.history.length - 1,
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: nodes);
  }

  Widget _node({
    required Color color,
    required String title,
    required String subtitle,
    required DateTime at,
    required bool isLast,
    String? note,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: NovaColors.cardBorder),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: NovaColors.primaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _clock(at),
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 11.5,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '“$note”',
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- dispatch flow

class _DispatchChoice {
  final ResponderType responder;
  final String? note;
  const _DispatchChoice(this.responder, this.note);
}

class _DispatchDialog extends StatefulWidget {
  final AlertEvent alert;

  const _DispatchDialog({required this.alert});

  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  ResponderType _responder = ResponderType.medical;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NovaColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NovaColors.cardBorder),
      ),
      title: Text(
        'Dispatch responder — ${widget.alert.id}',
        style: const TextStyle(
          color: NovaColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.alert.riderName} · ${widget.alert.address}',
              style: const TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'RESPONDER',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final responder in ResponderType.values)
                  _FilterChip(
                    label: responder.label,
                    color: NovaColors.pink,
                    selected: _responder == responder,
                    onTap: () => setState(() => _responder = responder),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Optional note for the audit trail',
                hintStyle: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12.5,
                ),
                filled: true,
                fillColor: NovaColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: NovaColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: NovaColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: NovaColors.cyan),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: NovaColors.secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final note = _noteController.text.trim();
            Navigator.of(context).pop(
              _DispatchChoice(_responder, note.isEmpty ? null : note),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: NovaColors.pink,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Dispatch'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- small widgets

class _FilterGroupLabel extends StatelessWidget {
  final String text;
  const _FilterGroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: NovaColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

/// Hand-rolled rather than Material's FilterChip, which needs a pile of
/// theme overrides to sit correctly on the dark console palette.
class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : NovaColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.65)
                  : NovaColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : NovaColors.secondaryText,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  /// True when this is the legal next step — filled instead of outlined.
  final bool primary;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: primary ? color : NovaColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: primary ? Colors.black : NovaColors.secondaryText,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.black : NovaColors.secondaryText,
                  fontSize: 12.5,
                  fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NovaColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NovaColors.cardBorder),
            ),
            child: const Icon(
              Icons.filter_alt_off_outlined,
              color: NovaColors.secondaryText,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No alerts match these filters',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Clear a status or type chip, or widen the search.',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
