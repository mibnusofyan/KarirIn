import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network connection (Wi-Fi, mobile data, …).
abstract interface class NetworkStatus {
  /// Emits on every change: true when offline.
  Stream<bool> get offlineChanges;
  Future<bool> isOffline();
}

class NoNetworkStatus implements NetworkStatus {
  const NoNetworkStatus();

  @override
  Stream<bool> get offlineChanges => const Stream.empty();

  @override
  Future<bool> isOffline() async => false;
}

class DeviceNetworkStatus implements NetworkStatus {
  final _connectivity = Connectivity();

  static bool _none(List<ConnectivityResult> r) => r.isEmpty || r.every((x) => x == ConnectivityResult.none);

  @override
  Stream<bool> get offlineChanges => _connectivity.onConnectivityChanged.map(_none).distinct();

  @override
  Future<bool> isOffline() async => _none(await _connectivity.checkConnectivity());
}
