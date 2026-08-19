import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicRefreshTimer;
  Position? _lastKnownPosition;

  // ============================================================
  // KONUM İZİNLERİ
  // ============================================================
  Future<bool> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ============================================================
  // KONUM PAYLAŞIMINI BAŞLAT
  // ============================================================
  Future<void> startSharingLocation() async {
    final hasPermission = await ensurePermissions();
    if (!hasPermission) return;

    await _positionSubscription?.cancel();
    _periodicRefreshTimer?.cancel();

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.otherNavigation,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Partner Takip',
          notificationText: 'Konumunuz partnerinizle paylaşılıyor.',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _lastKnownPosition = position;
      _updateMyLocation(position);
    });

    _periodicRefreshTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _refreshLocationNow(),
    );

    _refreshLocationNow();
  }

  Future<void> _refreshLocationNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastKnownPosition = position;
      await _updateMyLocation(position);
    } catch (e) {
      if (_lastKnownPosition != null) {
        await _updateMyLocation(_lastKnownPosition!);
      }
      debugPrint('Anlık konum alınamadı: $e');
    }
  }

  // ============================================================
  // POCKETBASE'E KONUM GÖNDER
  // ============================================================
  Future<void> _updateMyLocation(Position position) async {
    final myId = PbClient.currentUserId;
    if (myId == null) return;

    try {
      await PbClient.pb.collection('users').update(myId, body: {
        'locationLat': position.latitude,
        'locationLng': position.longitude,
        'locationSpeed': position.speed,
        'locationUpdatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Konum PocketBase\'e gönderilemedi: $e');
    }
  }

  void stopSharingLocation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  // ============================================================
  // PARTNER ID
  // ============================================================
  String? getPartnerId() {
    return PbClient.pb.authStore.record?.data['partnerId'] as String?;
  }

  // ============================================================
  // PARTNER VERİSİNİ GERÇEK ZAMANLI DİNLE
  // ============================================================
  // PocketBase'in callback tabanlı realtime API'sini bir Stream'e
  // dönüştürür, böylece StatusPage'de StreamBuilder ile kullanılabilir.
  Stream<RecordModel> watchPartnerData(String partnerId) {
    late StreamController<RecordModel> controller;
    Function()? unsubscribe;

    controller = StreamController<RecordModel>(
      onListen: () async {
        // İlk açılışta mevcut veriyi bir kez hemen gönder.
        try {
          final record =
              await PbClient.pb.collection('users').getOne(partnerId);
          controller.add(record);
        } catch (e) {
          debugPrint('Partner verisi ilk okuma hatası: $e');
        }

        // Sonrasında gerçek zamanlı değişiklikleri dinle.
        unsubscribe = await PbClient.pb
            .collection('users')
            .subscribe(partnerId, (e) {
          if (e.record != null) {
            controller.add(e.record!);
          }
        });
      },
      onCancel: () async {
        await unsubscribe?.call();
      },
    );

    return controller.stream;
  }
}