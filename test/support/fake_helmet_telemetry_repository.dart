// A HelmetTelemetryRepository that never touches Firebase.
//
// The rider home screen watches the helmet; without this every test that
// lands on it would build the Realtime Database one and die on "no
// Firebase app".

import 'dart:async';

import 'package:novaride/features/rider/domain/entities/helmet_telemetry.dart';
import 'package:novaride/features/rider/domain/repositories/helmet_telemetry_repository.dart';

class FakeHelmetTelemetryRepository implements HelmetTelemetryRepository {
  /// Emits [telemetry] once. Null is "nothing at that id", the default.
  FakeHelmetTelemetryRepository({this.telemetry}) : _stream = null;

  /// Emits whatever the test pushes, including errors, and nothing until
  /// it does — which is the "no snapshot yet" state.
  FakeHelmetTelemetryRepository.controlled(StreamController<HelmetTelemetry?> controller)
      : telemetry = null,
        _stream = controller.stream;

  final HelmetTelemetry? telemetry;
  final Stream<HelmetTelemetry?>? _stream;

  final List<String> calls = [];

  @override
  Stream<HelmetTelemetry?> watch(String deviceId) {
    calls.add('watch:$deviceId');
    return _stream ?? Stream.value(telemetry);
  }
}
