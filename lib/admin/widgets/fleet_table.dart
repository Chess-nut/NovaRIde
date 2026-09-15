import 'package:flutter/material.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Live fleet telemetry table.
///
/// Emergency rows are tinted red with a NovaColors.red border, and any
/// alcohol reading above the warning threshold is shown in amber.
///
/// Telemetry is passed in rather than read from the mock statics, so the
/// table shows the same live values as the map beside it.
class FleetTable extends StatelessWidget {
  final List<Rider> riders;
  final List<HelmetTelemetry> telemetry;

  /// Shared with the map through the controller — clicking a row and clicking
  /// a dot are the same action.
  final String? selectedRiderId;
  final ValueChanged<String>? onSelect;

  const FleetTable({
    super.key,
    required this.riders,
    required this.telemetry,
    this.selectedRiderId,
    this.onSelect,
  });

  static const _columns = <_Col>[
    _Col('RIDER', 3),
    _Col('HELMET ID', 2),
    _Col('SPEED', 2),
    _Col('ALCOHOL', 2),
    _Col('BATTERY', 2),
    _Col('GPS', 1),
    _Col('STATUS', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const Divider(height: 1, color: NovaColors.cardBorder),
        ...riders.map(_buildRow),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          for (final col in _columns)
            Expanded(
              flex: col.flex,
              child: Text(
                col.label,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  HelmetTelemetry? _telemetryFor(String riderId) {
    for (final t in telemetry) {
      if (t.riderId == riderId) return t;
    }
    return null;
  }

  Widget _buildRow(Rider rider) {
    final t = _telemetryFor(rider.id);
    final isEmergency = rider.status == RiderStatus.emergency;
    final selected = rider.id == selectedRiderId;
    final overLimit = (t?.alcoholLevel ?? 0) > kAlcoholWarningLevel;
    final lowBattery = (t?.batteryPct ?? 100) < 20;

    // Selection outranks the emergency tint so the operator never loses track
    // of which row they drilled into.
    final Border border;
    if (selected) {
      border = Border.all(color: NovaColors.cyan, width: 1.5);
    } else if (isEmergency) {
      border = Border.all(color: NovaColors.red.withValues(alpha: 0.55));
    } else {
      border = const Border(
        bottom: BorderSide(color: NovaColors.cardBorder, width: 0.5),
      );
    }

    final row = Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: selected
            ? NovaColors.cyan.withValues(alpha: 0.10)
            : isEmergency
                ? NovaColors.red.withValues(alpha: 0.10)
                : Colors.transparent,
        border: border,
        borderRadius: (isEmergency || selected) ? BorderRadius.circular(8) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _columns[0].flex,
            child: Text(
              rider.fullName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isEmergency ? NovaColors.red : NovaColors.primaryText,
                fontSize: 13,
                fontWeight: isEmergency ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: _columns[1].flex,
            child: _cell(rider.helmetId, color: NovaColors.secondaryText),
          ),
          Expanded(
            flex: _columns[2].flex,
            child: _cell('${(t?.speedKmh ?? 0).toStringAsFixed(1)} km/h'),
          ),
          Expanded(
            flex: _columns[3].flex,
            child: _cell(
              (t?.alcoholLevel ?? 0).toStringAsFixed(2),
              color: overLimit ? NovaColors.amber : NovaColors.primaryText,
              bold: overLimit,
            ),
          ),
          Expanded(
            flex: _columns[4].flex,
            child: _cell(
              '${t?.batteryPct ?? 0}%',
              color: lowBattery ? NovaColors.amber : NovaColors.primaryText,
            ),
          ),
          Expanded(
            flex: _columns[5].flex,
            child: Icon(
              (t?.gpsFix ?? false) ? Icons.gps_fixed : Icons.gps_off,
              size: 15,
              color: (t?.gpsFix ?? false) ? NovaColors.green : NovaColors.secondaryText,
            ),
          ),
          Expanded(
            flex: _columns[6].flex,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill.rider(rider.status),
            ),
          ),
        ],
      ),
    );

    if (onSelect == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect!(rider.id),
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }

  Widget _cell(String text, {Color color = NovaColors.primaryText, bool bold = false}) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, this.flex);
}
