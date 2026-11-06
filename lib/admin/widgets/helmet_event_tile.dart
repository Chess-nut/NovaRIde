import 'package:flutter/material.dart';
import 'package:novaride/admin/console_format.dart';
import 'package:novaride/admin/widgets/alert_feed_tile.dart';
import 'package:novaride/shared/models/models.dart';
import 'package:novaride/shared/theme.dart';

/// The tag every helmet-reported event carries until an operator opens it
/// as an alert: it came from the helmet's own Realtime Database writes, and
/// nobody has confirmed it. One constant so the feed, the alerts page and
/// the tests all say exactly the same thing.
const String kUnconfirmedFromHelmet = 'Unconfirmed — from helmet';

/// One [HelmetEvent] on the board.
///
/// Deliberately not an [AlertFeedTile]: it has no status, no workflow and
/// no response timeline — only "the helmet said this" and, for an operator
/// allowed to, a way to make it a real alert. Amber border and tag so it
/// never reads as a confirmed alert at a glance.
class HelmetEventTile extends StatelessWidget {
  final HelmetEvent event;

  /// "Open as alert". Null hides the button (the dashboard feed, or a role
  /// that cannot act on alerts).
  final VoidCallback? onOpen;

  /// Why the action is unavailable, shown in place of it — e.g. a helmet
  /// with no rider paired, or a read-only role.
  final String? disabledReason;

  /// Single-line form for the dashboard's narrow feed.
  final bool compact;

  const HelmetEventTile({
    super.key,
    required this.event,
    this.onOpen,
    this.disabledReason,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AlertFeedTile.colorFor(event.kind.alertType);
    final who = event.riderName ?? event.riderId ?? 'No rider paired';
    final where = event.hasPosition
        ? '${event.lat!.toStringAsFixed(5)}, ${event.lng!.toStringAsFixed(5)}'
        : 'Location unavailable';

    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: NovaColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NovaColors.amber.withValues(alpha: 0.5)),
      ),
      child: const Text(
        kUnconfirmedFromHelmet,
        style: TextStyle(
          color: NovaColors.amber,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 12,
        vertical: compact ? 9 : 11,
      ),
      decoration: compact
          ? null
          : BoxDecoration(
              color: NovaColors.amber.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NovaColors.amber.withValues(alpha: 0.45),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AlertFeedTile.iconFor(event.kind.alertType),
                size: compact ? 15 : 17,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.kind.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 14 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: formatManila(event.at),
                child: Text(
                  formatAgo(event.at),
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          tag,
          const SizedBox(height: 4),
          Text(
            '$who · ${event.deviceId} · $where',
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: NovaColors.secondaryText,
              fontSize: 11,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(
              event.detail,
              style: const TextStyle(
                color: NovaColors.primaryText,
                fontSize: 11.5,
              ),
            ),
          ],
          if (onOpen != null || disabledReason != null) ...[
            const SizedBox(height: 8),
            if (onOpen != null)
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.add_alert_outlined, size: 15),
                label: const Text('Open as alert'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NovaColors.amber,
                  side: BorderSide(
                    color: NovaColors.amber.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              )
            else
              Text(
                disabledReason!,
                style: const TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
