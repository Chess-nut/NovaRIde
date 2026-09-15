import 'package:flutter/material.dart';
import 'package:novaride/admin/state/mock_fleet_controller.dart';

/// App-scoped access to the live fleet state.
///
/// Every admin page reads the same [MockFleetController] through this scope,
/// so a crash spawned by the simulation lands in the dashboard feed, the
/// alerts page and the roster in the same frame. Before this existed the
/// dashboard owned a private controller and the other pages read the frozen
/// [MockData] statics, which is why the two disagreed during a demo.
///
/// Firebase seam: this is the single injection point for the later phase.
/// A `FirestoreFleetController` implementing the same surface gets constructed
/// in [FleetHost] instead of [MockFleetController] and nothing below here
/// changes — the pages only ever see the getters and mutations.
class FleetScope extends InheritedNotifier<MockFleetController> {
  const FleetScope({
    super.key,
    required MockFleetController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller for the enclosing [FleetHost]. Registers the calling
  /// context as a dependent, so it rebuilds when the simulation ticks.
  static MockFleetController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FleetScope>();
    assert(
      scope != null,
      'FleetScope.of() found no FleetHost ancestor. Admin pages must be '
      'mounted below the FleetHost that owns the MockFleetController.',
    );
    return scope!.notifier!;
  }
}

/// Owns the controller's lifecycle for as long as the console is signed in.
///
/// Deliberately a [StatefulWidget]: the controller is constructed once in
/// [initState] and disposed in [dispose], so switching tabs — which rebuilds
/// pages — can never cancel the simulation timers out from under the app.
class FleetHost extends StatefulWidget {
  final Widget child;

  const FleetHost({super.key, required this.child});

  @override
  State<FleetHost> createState() => _FleetHostState();
}

class _FleetHostState extends State<FleetHost> {
  late final MockFleetController _fleet;

  @override
  void initState() {
    super.initState();
    _fleet = MockFleetController();
  }

  @override
  void dispose() {
    _fleet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FleetScope(controller: _fleet, child: widget.child);
  }
}
