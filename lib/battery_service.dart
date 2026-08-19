import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'pb_client.dart';

class BatteryService {
  final _battery = Battery();

  Timer? _periodicTimer;
  StreamSubscription<BatteryState>? _stateSubscription;

  // Pil durumunu paylaşmaya başlar:
  // - Şarj durumu her değiştiğinde anında günceller
  // - Pil yüzdesini de her 60 saniyede bir günceller
  Future<void> startSharingBattery() async {
    await _updateBatteryInfo();

    _stateSubscription = _battery.onBatteryStateChanged.listen((_) {
      _updateBatteryInfo();
    });

    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _updateBatteryInfo();
    });
  }

  Future<void> _updateBatteryInfo() async {
    final myId = PbClient.currentUserId;
    if (myId == null) return;

    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;

    await PbClient.pb.collection('users').update(myId, body: {
      'batteryLevel': level,
      'batteryCharging':
          state == BatteryState.charging || state == BatteryState.full,
      'batteryUpdatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void stopSharingBattery() {
    _periodicTimer?.cancel();
    _stateSubscription?.cancel();
  }
}