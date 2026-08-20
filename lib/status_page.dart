import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocketbase/pocketbase.dart';

import 'app_theme.dart';
import 'location_service.dart';
import 'chat_service.dart';
import 'chat_page.dart';
import 'pb_client.dart';
import 'pairing_page.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final _locationService = LocationService();
  final _chatService = ChatService();
  final MapController _mapController = MapController();

  String? _partnerId;
  bool _isLoading = true;
  bool _hasCenteredMap = false;

  @override
  void initState() {
    super.initState();
    _loadPartnerId();
  }

  void _loadPartnerId() {
    final partnerId = _locationService.getPartnerId();
    setState(() {
      _partnerId = partnerId;
      _isLoading = false;
    });
  }

  Future<void> _showUnpairConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eşleşmeyi iptal et'),
        content: const Text(
          'Partnerinle olan bağlantın kaldırılacak. Konum, pil ve sohbet paylaşımı duracak. Emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerRose),
            child: const Text('Eşleşmeyi iptal et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _locationService.unpairFromPartner();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PairingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_partnerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partner Durumu')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border,
                    size: 48, color: AppColors.roseEmber.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'Henüz bir partnerle eşleşmedin',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Önce eşleştirme kodunu paylaşın',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Durumu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Sohbet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(partnerId: _partnerId!),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'unpair') {
                _showUnpairConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'unpair',
                child: Row(
                  children: [
                    Icon(Icons.link_off, color: AppColors.dangerRose, size: 20),
                    SizedBox(width: 10),
                    Text('Eşleşmeyi iptal et'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<RecordModel>(
        stream: _locationService.watchPartnerData(_partnerId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Veri alınırken hata oluştu:\n${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Partner verisi bulunamadı'));
          }

          final data = snapshot.data!.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildConnectionCard(data),
              const SizedBox(height: 20),
              _buildStatsGrid(data),
              const SizedBox(height: 16),
              _buildMap(data),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // BAĞLANTI KARTI (imza öğesi) — Sen ve Partner arasındaki
  // görsel bağlantıyı ve streak'i gösterir.
  // ============================================================
  Widget _buildConnectionCard(Map<String, dynamic> partnerData) {
    final myId = PbClient.currentUserId;

    return StreamBuilder<int>(
      stream: _chatService.watchStreak(_partnerId!),
      builder: (context, streakSnapshot) {
        final streak = streakSnapshot.data ?? 0;

        return StreamBuilder<RecordModel>(
          stream: myId != null
              ? _locationService.watchPartnerData(myId)
              : const Stream.empty(),
          builder: (context, mySnapshot) {
            final distanceText = _calculateDistanceText(
              mySnapshot.data?.data,
              partnerData,
            );

            return Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inkPlum, Color(0xFF4A2E52)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              if (distanceText != null) ...[
                Text(
                  distanceText,
                  style: const TextStyle(
                    color: AppColors.softPeach,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarDot('Sen'),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildConnectionLine(),
                    ),
                  ),
                  _buildAvatarDot('Partner'),
                ],
              ),
              if (streak > 0) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: AppColors.softPeach, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$streak günlük seri',
                      style: const TextStyle(
                        color: AppColors.softPeach,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
            );
          },
        );
      },
    );
  }

  // Kendi ve partnerin konumları arasındaki mesafeyi hesaplar.
  String? _calculateDistanceText(
    Map<String, dynamic>? myData,
    Map<String, dynamic> partnerData,
  ) {
    final myLat = _getDouble(myData?['locationLat']);
    final myLng = _getDouble(myData?['locationLng']);
    final partnerLat = _getDouble(partnerData['locationLat']);
    final partnerLng = _getDouble(partnerData['locationLng']);

    if (myLat == null || myLng == null || partnerLat == null || partnerLng == null) {
      return null;
    }

    final distanceMeters = _distanceBetween(myLat, myLng, partnerLat, partnerLng);
    final distanceKm = distanceMeters / 1000;

    if (distanceKm < 1) {
      return '${distanceMeters.toStringAsFixed(0)} m uzaktasınız';
    }
    return '${distanceKm.toStringAsFixed(1)} km uzaktasınız';
  }

  // Haversine formülü ile iki koordinat arası mesafeyi metre cinsinden hesaplar.
  double _distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // metre
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  Widget _buildAvatarDot(String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.roseEmber,
            shape: BoxShape.circle,
          ),
          child: Icon(
            label == 'Sen' ? Icons.person : Icons.favorite,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConnectionLine() {
    return SizedBox(
      height: 2,
      child: Row(
        children: List.generate(
          12,
          (index) => Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              color: AppColors.softPeach.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BENTO GRID — pil, bağlantı, hız, son güncelleme
  // ============================================================
  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildBatteryTile(data),
        _buildConnectivityTile(data),
        _buildSpeedTile(data),
        _buildLastUpdateTile(data),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkPlum.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.inkPlum,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mutedCharcoal.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryTile(Map<String, dynamic> data) {
    final hasData = data['batteryUpdatedAt'] != null &&
        data['batteryUpdatedAt'].toString().isNotEmpty;
    final level = hasData ? _getInt(data['batteryLevel']) : null;
    final isCharging = data['batteryCharging'] as bool? ?? false;

    return _statTile(
      icon: isCharging ? Icons.battery_charging_full : Icons.battery_std,
      iconColor: _batteryColor(level),
      value: level != null ? '%$level' : '—',
      label: isCharging ? 'Şarj oluyor' : 'Pil durumu',
    );
  }

  Widget _buildConnectivityTile(Map<String, dynamic> data) {
    final hasData = data['connectivityUpdatedAt'] != null &&
        data['connectivityUpdatedAt'].toString().isNotEmpty;
    final isOnline = hasData ? data['connectivityOnline'] as bool? : null;
    final type = data['connectivityType'] as String?;

    return _statTile(
      icon: isOnline == true
          ? (type == 'wifi' ? Icons.wifi : Icons.signal_cellular_alt)
          : Icons.wifi_off,
      iconColor: isOnline == true ? AppColors.mossSage : AppColors.dangerRose,
      value: isOnline == null
          ? '—'
          : (isOnline ? 'Bağlı' : 'Bağlı değil'),
      label: type == 'wifi'
          ? 'Wi-Fi'
          : type == 'mobile'
              ? 'Mobil veri'
              : 'İnternet',
    );
  }

  Widget _buildSpeedTile(Map<String, dynamic> data) {
    final speedMs = _getDouble(data['locationSpeed']);
    final speedKmh = speedMs != null ? speedMs * 3.6 : 0;

    return _statTile(
      icon: Icons.speed,
      iconColor: AppColors.roseEmber,
      value: '${speedKmh.toStringAsFixed(0)} km/h',
      label: 'Anlık hız',
    );
  }

  Widget _buildLastUpdateTile(Map<String, dynamic> data) {
    final updatedAt = _getDateTime(data['locationUpdatedAt']);

    return _statTile(
      icon: Icons.access_time,
      iconColor: AppColors.warningAmber,
      value: _formatUpdatedAtShort(updatedAt),
      label: 'Son konum',
    );
  }

  // ============================================================
  // HARİTA
  // ============================================================
  Widget _buildMap(Map<String, dynamic> data) {
    final lat = _getDouble(data['locationLat']);
    final lng = _getDouble(data['locationLng']);

    final partnerLocation = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : const LatLng(41.0082, 28.9784);

    if (lat != null && lng != null && !_hasCenteredMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(partnerLocation, 15);
        _hasCenteredMap = true;
      });
    }

    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkPlum.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: partnerLocation,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.partner_takip',
                ),
                if (lat != null && lng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: partnerLocation,
                        width: 56,
                        height: 56,
                        child: const Icon(
                          Icons.favorite,
                          color: AppColors.roseEmber,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'center_partner_location',
                backgroundColor: AppColors.cardWhite,
                foregroundColor: AppColors.inkPlum,
                elevation: 2,
                onPressed: () {
                  if (lat == null || lng == null) return;
                  _mapController.move(partnerLocation, 16);
                },
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // YARDIMCI FONKSİYONLAR
  // ============================================================
  double? _getDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _getInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime? _getDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  Color _batteryColor(int? level) {
    if (level == null) return AppColors.mutedCharcoal.withValues(alpha: 0.4);
    if (level <= 20) return AppColors.dangerRose;
    if (level <= 50) return AppColors.warningAmber;
    return AppColors.mossSage;
  }

  String _formatUpdatedAtShort(DateTime? date) {
    if (date == null) return '—';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}sn önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    return '${diff.inHours}sa önce';
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}