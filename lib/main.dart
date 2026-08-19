import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'pb_client.dart';
import 'pairing_page.dart';
import 'status_page.dart';
import 'location_service.dart';
import 'battery_service.dart';
import 'connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PocketBase kimlik doğrulaması — artık tüm veriler bunun üzerinden.
  await PbClient.ensureAuth();

  await LocationService().startSharingLocation();
  await BatteryService().startSharingBattery();
  await ConnectivityService().startSharingConnectivity();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Partner Takip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _isLoading = true;
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    _checkPairingStatus();
  }

  Future<void> _checkPairingStatus() async {
    final record = PbClient.pb.authStore.record;
    final partnerId = record?.data['partnerId'] as String?;

    if (!mounted) return;

    setState(() {
      _isPaired = partnerId != null && partnerId.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isPaired ? const StatusPage() : const PairingPage();
  }
}