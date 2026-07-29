import 'package:flutter/material.dart';
import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/widgets/status_pill.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// Live fleet telemetry table.
///
/// Emergency rows are tinted red with a NovaColors.red border, and any
/// alcohol reading above the warning threshold is shown in amber.
class FleetTable extends StatelessWidget {
  final List<Rider> riders;

  const FleetTable({super.key, required this.riders});

  static const _amber = Color(0xFFFFB020);

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

  Widget _buildRow(Rider rider) {
    final t = MockData.telemetryFor(rider.id);
    final isEmergency = rider.status == RiderStatus.emergency;
    final overLimit = (t?.alcoholLevel ?? 0) > kAlcoholWarningLevel;
    final lowBattery = (t?.batteryPct ?? 100) < 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isEmergency ? NovaColors.red.withValues(alpha: 0.10) : Colors.transparent,
        border: isEmergency
            ? Border.all(color: NovaColors.red.withValues(alpha: 0.55))
            : const Border(bottom: BorderSide(color: NovaColors.cardBorder, width: 0.5)),
        borderRadius: isEmergency ? BorderRadius.circular(8) : null,
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
              color: overLimit ? _amber : NovaColors.primaryText,
              bold: overLimit,
            ),
          ),
          Expanded(
            flex: _columns[4].flex,
            child: _cell(
              '${t?.batteryPct ?? 0}%',
              color: lowBattery ? _amber : NovaColors.primaryText,
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
