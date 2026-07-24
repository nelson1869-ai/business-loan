import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/network/server_health_service.dart';

class FakeConnectivity implements Connectivity {
  FakeConnectivity(this.results);

  final List<ConnectivityResult> results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(results);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerHealthService Tests', () {
    test(
      'returns offline status when no physical network interface is present',
      () async {
        final fakeConnectivity = FakeConnectivity([ConnectivityResult.none]);
        final service = ServerHealthService(fakeConnectivity);
        final status = await service.checkStatus();

        expect(status, equals(ServerStatus.offline));
      },
    );

    test(
      'returns serverReady when server reachability override returns true',
      () async {
        final fakeConnectivity = FakeConnectivity([ConnectivityResult.wifi]);
        final service = ServerHealthService(
          fakeConnectivity,
          isServerReachableOverride: () async => true,
        );
        final status = await service.checkStatus();

        expect(status, equals(ServerStatus.serverReady));
      },
    );

    test(
      'returns serverUnavailable when server reachability override returns false',
      () async {
        final fakeConnectivity = FakeConnectivity([ConnectivityResult.mobile]);
        final service = ServerHealthService(
          fakeConnectivity,
          isServerReachableOverride: () async => false,
        );
        final status = await service.checkStatus();

        expect(status, equals(ServerStatus.serverUnavailable));
      },
    );
  });
}
