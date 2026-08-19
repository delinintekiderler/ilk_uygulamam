import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pb_client.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> startSharingConnectivity() async {
    final initialResult = await _connectivity.checkConnectivity();
    await _updateConnectivity(initialResult);

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateConnectivity(results),
    );
  }

  Future<void> _updateConnectivity(List<ConnectivityResult> results) async {
    final myId = PbClient.currentUserId;
    if (myId == null) return;

    final isOnline = results.any((r) => r != ConnectivityResult.none);

    String connectionType = 'none';
    if (results.contains(ConnectivityResult.wifi)) {
      connectionType = 'wifi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      connectionType = 'mobile';
    } else if (isOnline) {
      connectionType = 'other';
    }

    await PbClient.pb.collection('users').update(myId, body: {
      'connectivityOnline': isOnline,
      'connectivityType': connectionType,
      'connectivityUpdatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void stopSharingConnectivity() {
    _subscription?.cancel();
    _subscription = null;
  }
}