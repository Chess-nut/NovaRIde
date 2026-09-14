import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Helmet Settings" screen — device info for the paired smart helmet plus
/// toggles for detection features. Opened from the Profile screen's
/// ACCOUNT card.
class HelmetSettingsPage extends StatefulWidget {
  const HelmetSettingsPage({super.key});

  @override
  State<HelmetSettingsPage> createState() => _HelmetSettingsPageState();
}

class _HelmetSettingsPageState extends State<HelmetSettingsPage> {
  bool _autoConnect = true;
  bool _impactDetection = true;
  bool _alcoholDetection = true;
  bool _ledIndicator = true;
  bool _soundAlerts = false;
  double _sensitivity = 1; // 0 = Low, 1 = Medium, 2 = High

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('CONNECTION'),
                    const SizedBox(height: 12),
                    _buildToggleCard([
                      _ToggleRow(
                        icon: Icons.bluetooth,
                        iconColor: NovaColors.cyan,
                        title: 'Auto-Connect',
                        subtitle: 'Connect automatically when helmet is nearby',
                        value: _autoConnect,
                        onChanged: (v) => setState(() => _autoConnect = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('DETECTION'),
                    const SizedBox(height: 12),
                    _buildToggleCard([
                      _ToggleRow(
                        icon: Icons.warning_amber_rounded,
                        iconColor: NovaColors.pink,
                        title: 'Impact Detection',
                        subtitle: 'Detect crashes using onboard accelerometer',
                        value: _impactDetection,
                        onChanged: (v) => setState(() => _impactDetection = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.local_bar_outlined,
                        iconColor: NovaColors.amber,
                        title: 'Alcohol Detection',
                        subtitle: 'Warn when breath alcohol exceeds safe limit',
                        value: _alcoholDetection,
                        onChanged: (v) => setState(() => _alcoholDetection = v),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSensitivityCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('FEEDBACK'),
                    const SizedBox(height: 12),
                    _buildToggleCard([
                      _ToggleRow(
                        icon: Icons.lightbulb_outline,
                        iconColor: NovaColors.green,
                        title: 'LED Indicator',
                        subtitle: 'Show status light on the helmet',
                        value: _ledIndicator,
                        onChanged: (v) => setState(() => _ledIndicator = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.volume_up_outlined,
                        iconColor: NovaColors.purple,
                        title: 'Sound Alerts',
                        subtitle: 'Play a beep on warnings and alerts',
                        value: _soundAlerts,
                        onChanged: (v) => setState(() => _soundAlerts = v),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildUnpairButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back, color: NovaColors.primaryText, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Helmet Settings',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your connected smart helmet',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Connected device summary ----
  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: NovaColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_motorsports, color: NovaColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NovaRide Smart Helmet',
                      style: TextStyle(
                        color: NovaColors.primaryText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ESP32 · Firmware v4.2',
                      style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: NovaColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, color: NovaColors.green, size: 7),
                    SizedBox(width: 5),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: NovaColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _DeviceStat(icon: Icons.battery_charging_full, label: '78%', sub: 'BATTERY')),
              Expanded(child: _DeviceStat(icon: Icons.podcasts, label: '-62 dBm', sub: 'SIGNAL')),
              Expanded(child: _DeviceStat(icon: Icons.tag, label: 'NV-08567', sub: 'HELMET ID')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildToggleCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  // ---- Impact sensitivity slider ----
  Widget _buildSensitivityCard() {
    const labels = ['Low', 'Medium', 'High'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impact Sensitivity',
            style: TextStyle(
              color: NovaColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${labels[_sensitivity.round()]} sensitivity — higher may trigger more false alerts',
            style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: NovaColors.cyan,
              inactiveTrackColor: NovaColors.cardBorder,
              thumbColor: NovaColors.cyan,
              overlayColor: NovaColors.cyan.withValues(alpha: 0.15),
              valueIndicatorColor: NovaColors.cyan,
            ),
            child: Slider(
              value: _sensitivity,
              min: 0,
              max: 2,
              divisions: 2,
              label: labels[_sensitivity.round()],
              onChanged: (v) => setState(() => _sensitivity = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpairButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _confirmUnpair(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: NovaColors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.link_off, color: NovaColors.red, size: 18),
        label: const Text(
          'UNPAIR HELMET',
          style: TextStyle(
            color: NovaColors.red,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _confirmUnpair(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NovaColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unpair Helmet',
          style: TextStyle(color: NovaColors.primaryText, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your helmet will stop sending telemetry and safety alerts until '
          'you pair it again. Continue?',
          style: TextStyle(color: NovaColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: NovaColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Unpair', style: TextStyle(color: NovaColors.red)),
          ),
        ],
      ),
    );
  }
}

class _DeviceStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _DeviceStat({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: NovaColors.secondaryText, size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.primaryText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: const TextStyle(color: NovaColors.secondaryText, fontSize: 9.5, letterSpacing: 0.4),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NovaColors.cyan,
            activeTrackColor: NovaColors.cyan.withValues(alpha: 0.3),
            inactiveThumbColor: NovaColors.secondaryText,
            inactiveTrackColor: NovaColors.cardBorder,
          ),
        ],
      ),
    );
  }
}