import 'package:flutter/material.dart';
import 'package:novaride/admin/console_format.dart';
import 'package:novaride/admin/state/fleet_scope.dart';
import 'package:novaride/admin/state/fleet_controller.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/admin/widgets/dashboard/dash_panel.dart';
import 'package:novaride/admin/widgets/dashboard/simple_bar_chart.dart';
import 'package:novaride/admin/widgets/filter_controls.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/admin/widgets/weekly_alerts_chart.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

enum ReportRange { today, week, month, all }

extension ReportRangeLabel on ReportRange {
  String get label => switch (this) {
        ReportRange.today => 'Today',
        ReportRange.week => '7 days',
        ReportRange.month => '30 days',
        ReportRange.all => 'All',
      };

  /// Cut-off for the range, or null for "everything".
  Duration? get window => switch (this) {
        ReportRange.today => const Duration(days: 1),
        ReportRange.week => const Duration(days: 7),
        ReportRange.month => const Duration(days: 30),
        ReportRange.all => null,
      };
}

/// Reports and response-time analytics.
///
/// The dashboard answers "what is happening now". This page answers "what has
/// the system told us" — where incidents cluster, which types dominate, and
/// how long the operator actually took to respond.
///
/// Data-range caveat: the simulation seeds alerts only minutes to hours old
/// and the controller caps the board at 40 alerts, so in practice almost
/// everything falls inside "Today". The narrower ranges therefore filter real
/// data but rarely change the picture — they are wired correctly rather than
/// faked, and will separate properly once Firestore supplies real history.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportRange _range = ReportRange.all;

  @override
  Widget build(BuildContext context) {
    final fleet = FleetScope.of(context);

    return ListenableBuilder(
      listenable: fleet,
      builder: (context, _) {
        final alerts = _inRange(fleet.alerts);

        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1100;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(fleet, alerts),
                  const SizedBox(height: 12),
                  _buildResponseSummary(alerts),
                  const SizedBox(height: 12),
                  SizedBox(height: 260, child: _buildWeeklyPanel(alerts)),
                  const SizedBox(height: 12),
                  if (narrow) ...[
                    SizedBox(height: 300, child: _buildDistrictPanel(alerts)),
                    const SizedBox(height: 12),
                    SizedBox(height: 260, child: _buildTypePanel(alerts)),
                  ] else
                    SizedBox(
                      height: 300,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: _buildDistrictPanel(alerts)),
                          const SizedBox(width: 12),
                          Expanded(flex: 4, child: _buildTypePanel(alerts)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildIncidentTable(fleet, alerts),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<AlertEvent> _inRange(List<AlertEvent> alerts) {
    final window = _range.window;
    if (window == null) return List.of(alerts);
    final cutoff = DateTime.now().subtract(window);
    return alerts.where((a) => a.timestamp.isAfter(cutoff)).toList();
  }

  // ----------------------------------------------------------------- header

  Widget _buildHeader(FleetController fleet, List<AlertEvent> alerts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Operations report',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${alerts.length} incidents in range',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const FilterGroupLabel('RANGE'),
          for (final range in ReportRange.values)
            FilterChipButton(
              label: range.label,
              color: NovaColors.cyan,
              selected: _range == range,
              onTap: () => setState(() => _range = range),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showExport(fleet, alerts),
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export CSV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: NovaColors.cyan,
              side: const BorderSide(color: NovaColors.cardBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- response summary

  Widget _buildResponseSummary(List<AlertEvent> alerts) {
    final ackTimes = _elapsedTo(alerts, AlertStatus.acknowledged);
    final resolveTimes = _elapsedTo(alerts, AlertStatus.resolved);

    final stats = <_Stat>[
      _Stat('Avg. acknowledge', _mean(ackTimes), NovaColors.cyan),
      _Stat('Avg. resolve', _mean(resolveTimes), NovaColors.green),
      _Stat('Fastest acknowledge', _min(ackTimes), NovaColors.green),
      _Stat('Slowest acknowledge', _max(ackTimes), NovaColors.amber),
      _Stat('Acted on', null, NovaColors.purple, override: '${ackTimes.length}'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESPONSE TIME',
            style: TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Measured from the helmet raising the alert to the operator '
            'acting on it — the Golden Hour number this console exists to '
            'shrink.',
            style: TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final stat in stats) _StatTile(stat: stat)],
          ),
          if (ackTimes.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No alerts have been acted on yet — acknowledge one on the '
              'Alerts tab and these fill in.',
              style: TextStyle(
                color: NovaColors.secondaryText,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Duration> _elapsedTo(List<AlertEvent> alerts, AlertStatus status) {
    final durations = <Duration>[];
    for (final alert in alerts) {
      final at = alert.reachedAt(status);
      if (at == null) continue;
      durations.add(at.difference(alert.timestamp));
    }
    return durations;
  }

  Duration? _mean(List<Duration> values) {
    if (values.isEmpty) return null;
    final total = values.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: total ~/ values.length);
  }

  Duration? _min(List<Duration> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);

  Duration? _max(List<Duration> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

  // ----------------------------------------------------------- alerts / day

  Widget _buildWeeklyPanel(List<AlertEvent> alerts) {
    final today = DateTime.now();
    final counts = <int>[];
    final labels = <String>[];

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Last seven calendar days, oldest first.
    for (var offset = 6; offset >= 0; offset--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: offset));
      final next = day.add(const Duration(days: 1));
      counts.add(
        alerts
            .where((a) => !a.timestamp.isBefore(day) && a.timestamp.isBefore(next))
            .length,
      );
      labels.add(weekdays[day.weekday - 1]);
    }

    return DashPanel(
      title: 'Alerts over time',
      trailing: Text(
        'last 7 days',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
      ),
      child: counts.every((c) => c == 0)
          ? const _PanelEmpty('No alerts in this range')
          : WeeklyAlertsChart(values: counts, labels: labels),
    );
  }

  // -------------------------------------------------------------- districts

  Widget _buildDistrictPanel(List<AlertEvent> alerts) {
    final counts = <String, int>{};
    for (final alert in alerts) {
      final name = FleetController.nearestDistrict(alert.lat, alert.lng).name;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final ranked = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (ranked.isEmpty) {
      return const DashPanel(
        title: 'Alerts by district',
        child: _PanelEmpty('No alerts in this range'),
      );
    }

    final shares = _percentages([for (final e in ranked) e.value]);

    return DashPanel(
      title: 'Alerts by district',
      trailing: Text(
        '${ranked.length} areas',
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SimpleBarChart(
              values: [for (final e in ranked) e.value],
              labels: [for (final e in ranked) _shortLabel(e.key)],
              barColor: NovaColors.cyan,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (var i = 0; i < ranked.length; i++)
                _SharePill(
                  label: ranked[i].key,
                  count: ranked[i].value,
                  percent: shares[i],
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortLabel(String districtName) {
    for (final district in kFleetDistricts) {
      if (district.name == districtName) return district.shortLabel;
    }
    return districtName;
  }

  // ------------------------------------------------------------ alert types

  Widget _buildTypePanel(List<AlertEvent> alerts) {
    final counts = {for (final t in AlertType.values) t: 0};
    for (final alert in alerts) {
      counts[alert.type] = counts[alert.type]! + 1;
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const DashPanel(
        title: 'Alert type distribution',
        child: _PanelEmpty('No alerts in this range'),
      );
    }

    final types = AlertType.values.toList();
    final shares = _percentages([for (final t in types) counts[t]!]);

    return DashPanel(
      title: 'Alert type distribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SimpleBarChart(
              values: [for (final t in types) counts[t]!],
              labels: [for (final t in types) _typeShort(t)],
              barColor: NovaColors.pink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (var i = 0; i < types.length; i++)
                _SharePill(
                  label: _typeShort(types[i]),
                  count: counts[types[i]]!,
                  percent: shares[i],
                  color: AlertFeedTile.colorFor(types[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _typeShort(AlertType type) => switch (type) {
        AlertType.crash => 'Crash',
        AlertType.sos => 'SOS',
        AlertType.alcoholWarning => 'Alcohol',
        AlertType.lowBattery => 'Battery',
      };

  /// Largest-remainder rounding, so the printed shares always total exactly
  /// 100% instead of 99% or 101% after independent rounding.
  List<int> _percentages(List<int> values) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return List.filled(values.length, 0);

    final exact = [for (final v in values) v * 100 / total];
    final floors = [for (final e in exact) e.floor()];
    var remaining = 100 - floors.fold<int>(0, (a, b) => a + b);

    // Hand out the leftover points to the largest fractional parts first.
    final order = List.generate(values.length, (i) => i)
      ..sort((a, b) => (exact[b] - floors[b]).compareTo(exact[a] - floors[a]));

    for (final index in order) {
      if (remaining <= 0) break;
      floors[index]++;
      remaining--;
    }
    return floors;
  }

  // --------------------------------------------------------- incident table

  Widget _buildIncidentTable(
    FleetController fleet,
    List<AlertEvent> alerts,
  ) {
    // Severity first, then newest — the table reads as a triage list.
    final sorted = List.of(alerts)
      ..sort((a, b) {
        final byPriority = FleetController.priorityOf(a)
            .index
            .compareTo(FleetController.priorityOf(b).index);
        if (byPriority != 0) return byPriority;
        return b.timestamp.compareTo(a.timestamp);
      });

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
                'Incident log',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'sorted by severity · ${sorted.length} rows',
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _incidentHeader(),
          const Divider(height: 1, color: NovaColors.cardBorder),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No incidents in this range',
                  style: TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            for (final alert in sorted) _incidentRow(fleet, alert),
        ],
      ),
    );
  }

  Widget _incidentHeader() {
    const style = TextStyle(
      color: NovaColors.secondaryText,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('ALERT', style: style)),
          Expanded(flex: 3, child: Text('TYPE', style: style)),
          Expanded(flex: 3, child: Text('RIDER', style: style)),
          Expanded(flex: 3, child: Text('DISTRICT', style: style)),
          Expanded(flex: 3, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('ACK', style: style)),
          Expanded(flex: 2, child: Text('RESOLVE', style: style)),
        ],
      ),
    );
  }

  Widget _incidentRow(FleetController fleet, AlertEvent alert) {
    final district = FleetController.nearestDistrict(alert.lat, alert.lng);
    final ack = alert.reachedAt(AlertStatus.acknowledged);
    final resolved = alert.reachedAt(AlertStatus.resolved);

    Widget cell(String text, {Color color = NovaColors.primaryText}) => Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 12.5),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NovaColors.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: cell(alert.id, color: NovaColors.secondaryText)),
          Expanded(
            flex: 3,
            child: cell(alert.type.label, color: AlertFeedTile.colorFor(alert.type)),
          ),
          Expanded(flex: 3, child: cell(alert.riderName)),
          Expanded(
            flex: 3,
            child: cell(district.name, color: NovaColors.secondaryText),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill.alert(alert.status),
            ),
          ),
          Expanded(
            flex: 2,
            child: cell(
              ack == null ? '—' : formatDuration(ack.difference(alert.timestamp)),
              color: ack == null ? NovaColors.secondaryText : NovaColors.cyan,
            ),
          ),
          Expanded(
            flex: 2,
            child: cell(
              resolved == null
                  ? '—'
                  : formatDuration(resolved.difference(alert.timestamp)),
              color: resolved == null
                  ? NovaColors.secondaryText
                  : NovaColors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- export

  /// Builds the CSV and shows it in a selectable dialog.
  ///
  /// Deliberately not a file save or share sheet — both need a plugin, and
  /// the project stays dependency-free. Select-all and copy is enough to get
  /// the data into a spreadsheet for the written report.
  void _showExport(FleetController fleet, List<AlertEvent> alerts) {
    final csv = buildIncidentCsv(fleet, alerts);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NovaColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: NovaColors.cardBorder),
        ),
        title: const Text(
          'Incident export (CSV)',
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 620,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select all and copy into a spreadsheet.',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NovaColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NovaColors.cardBorder),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csv,
                      style: const TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
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
              'Close',
              style: TextStyle(color: NovaColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// One CSV row per alert, including the response times the report is about.
/// Top-level so it can be unit-tested without a widget tree.
String buildIncidentCsv(FleetController fleet, List<AlertEvent> alerts) {
  const header = [
    'alert_id',
    'type',
    'rider_id',
    'rider_name',
    'helmet_id',
    'district',
    'address',
    'status',
    'raised_at',
    'acknowledged_at',
    'dispatched_at',
    'resolved_at',
    'ack_seconds',
    'resolve_seconds',
  ];

  final rows = <String>[header.join(',')];

  for (final alert in alerts) {
    final district = FleetController.nearestDistrict(alert.lat, alert.lng);
    final ack = alert.reachedAt(AlertStatus.acknowledged);
    final dispatched = alert.reachedAt(AlertStatus.dispatched);
    final resolved = alert.reachedAt(AlertStatus.resolved);

    rows.add([
      alert.id,
      alert.type.label,
      alert.riderId,
      alert.riderName,
      fleet.riderFor(alert.riderId)?.helmetId ?? '',
      district.name,
      alert.address,
      alert.status.label,
      formatIso(alert.timestamp),
      formatIso(ack),
      formatIso(dispatched),
      formatIso(resolved),
      ack == null ? '' : '${ack.difference(alert.timestamp).inSeconds}',
      resolved == null
          ? ''
          : '${resolved.difference(alert.timestamp).inSeconds}',
    ].map(_csvField).join(','));
  }

  return rows.join('\n');
}

/// Quotes a field only when it contains a comma, quote or newline, and
/// doubles any embedded quotes — RFC 4180.
String _csvField(String value) {
  if (!value.contains(RegExp('[,"\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

// ------------------------------------------------------------- small widgets

class _Stat {
  final String label;
  final Duration? duration;
  final Color color;
  final String? override;

  const _Stat(this.label, this.duration, this.color, {this.override});
}

class _StatTile extends StatelessWidget {
  final _Stat stat;

  const _StatTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: NovaColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            stat.override ?? formatDuration(stat.duration),
            style: TextStyle(
              color: stat.color,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  final String label;
  final int count;
  final int percent;
  final Color color;

  const _SharePill({
    required this.label,
    required this.count,
    required this.percent,
    this.color = NovaColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count · $percent%',
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  final String message;

  const _PanelEmpty(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
      ),
    );
  }
}
