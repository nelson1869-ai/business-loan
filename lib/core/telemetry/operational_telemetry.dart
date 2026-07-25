import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sink for anonymous operational events. No borrower or financial values are
/// accepted by this API.
abstract interface class OperationalTelemetry {
  /// Records a bounded event name and non-sensitive numeric measurements.
  void record(String event, {Map<String, num> measurements = const {}});

  /// Records a scrubbed crash category without uploading application data.
  void recordCrash(String category, StackTrace stackTrace);
}

/// Default privacy-preserving sink used until an approved telemetry backend is
/// configured. Events are intentionally not persisted or transmitted.
class DisabledOperationalTelemetry implements OperationalTelemetry {
  const DisabledOperationalTelemetry();

  @override
  void record(String event, {Map<String, num> measurements = const {}}) {}

  @override
  void recordCrash(String category, StackTrace stackTrace) {}
}

/// Runtime-selected privacy-safe telemetry sink.
class OperationalTelemetryRegistry {
  OperationalTelemetryRegistry._();

  static OperationalTelemetry current = const DisabledOperationalTelemetry();
}

final operationalTelemetryProvider = Provider<OperationalTelemetry>((ref) {
  return OperationalTelemetryRegistry.current;
});
