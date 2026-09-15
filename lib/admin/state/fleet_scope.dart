import 'package:flutter/material.dart';
import 'package:novaride/admin/data/fleet_repository.dart';
import 'package:novaride/admin/data/mock_fleet_repository.dart';
import 'package:novaride/admin/state/fleet_controller.dart';

/// App-scoped access to the live fleet state.
///
/// Every admin page reads the same [FleetController] through this scope,
/// so a crash arriving from the data source lands in the dashboard feed, the
/// alerts page and the roster in the same frame. Before this existed the
/// dashboard owned a private controller and the other pages read the frozen
/// `MockData` statics, which is why the two disagreed during a demo.
///
/// Repository pattern: the controller never talks to a store directly. It is
/// handed one [FleetRepository] — `MockFleetRepository` for the in-process
/// simulation, `FirestoreFleetRepository` for Cloud Firestore — and reads
/// everything through that repository's streams. [FleetHost] decides which
/// repository to construct; the pages only ever see the controller's getters
/// and mutations, so nothing below here changes when the source does.
class FleetScope extends InheritedNotifier<FleetController> {
  const FleetScope({
    super.key,
    required FleetController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller for the enclosing [FleetHost]. Registers the calling
  /// context as a dependent, so it rebuilds when the fleet state changes.
  static FleetController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FleetScope>();
    assert(
      scope != null,
      'FleetScope.of() found no FleetHost ancestor. Admin pages must be '
      'mounted below the FleetHost that owns the FleetController.',
    );
    return scope!.notifier!;
  }
}

/// Builds the repository a [FleetHost] hands to its controller.
typedef FleetRepositoryFactory = FleetRepository Function();

/// Owns the controller's lifecycle for as long as the console is signed in.
///
/// Deliberately a [StatefulWidget]: the controller is constructed once in
/// [initState] and disposed in [dispose], so switching tabs — which rebuilds
/// pages — can never cancel the data subscriptions out from under the app.
///
/// This is the single injection point for the data source. Pass
/// [createRepository] to choose one explicitly (tests do, to stay on the
/// simulation); otherwise the host uses the in-process mock.
class FleetHost extends StatefulWidget {
  final Widget child;
  final FleetRepositoryFactory? createRepository;

  const FleetHost({super.key, required this.child, this.createRepository});

  @override
  State<FleetHost> createState() => _FleetHostState();
}

class _FleetHostState extends State<FleetHost> {
  late final FleetController _fleet;

  @override
  void initState() {
    super.initState();
    final create = widget.createRepository ?? MockFleetRepository.new;
    _fleet = FleetController(create());
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
