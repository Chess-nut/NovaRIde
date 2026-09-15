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

/// Names the data source for every [FleetHost] below it.
///
/// `main_admin.dart` resolves the source once, before `runApp`, and mounts
/// this above the app so the host can pick it up without the login page
/// having to carry it. Absent — as in the widget tests, which pump
/// `AdminApp()` bare — the host falls back to the simulation.
class FleetSourceScope extends InheritedWidget {
  final FleetRepositoryFactory createRepository;

  const FleetSourceScope({
    super.key,
    required this.createRepository,
    required super.child,
  });

  static FleetRepositoryFactory? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FleetSourceScope>()?.createRepository;

  @override
  bool updateShouldNotify(FleetSourceScope oldWidget) =>
      oldWidget.createRepository != createRepository;
}

/// Owns the controller's lifecycle for as long as the console is signed in.
///
/// Deliberately a [StatefulWidget]: the controller is constructed once in
/// [initState] and disposed in [dispose], so switching tabs — which rebuilds
/// pages — can never cancel the data subscriptions out from under the app.
///
/// This is the single injection point for the data source. The repository
/// comes from, in order: [createRepository] if given, the enclosing
/// [FleetSourceScope] if any, else the in-process simulation. The controller
/// owns the repository it is given and disposes it with itself.
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
    final create = widget.createRepository ??
        FleetSourceScope.maybeOf(context) ??
        MockFleetRepository.new;
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
