import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'pb_client.dart';
import 'status_page.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _codeInputController = TextEditingController();

  String? _myCode;
  bool _isLoading = true;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupMyCode();
  }

  @override
  void dispose() {
    _codeInputController.dispose();
    super.dispose();
  }

  Future<void> _setupMyCode() async {
    final myId = PbClient.currentUserId;
    if (myId == null) return;

    final record = PbClient.pb.authStore.record!;
    final existingCode = record.data['pairingCode'] as String?;

    if (existingCode != null && existingCode.isNotEmpty) {
      setState(() {
        _myCode = existingCode;
        _isLoading = false;
      });
      return;
    }

    String newCode;
    bool isUnique = false;
    do {
      newCode = _generateSixDigitCode();
      final existing = await PbClient.pb.collection('users').getList(
            filter: 'pairingCode = "$newCode"',
          );
      isUnique = existing.items.isEmpty;
    } while (!isUnique);

    await PbClient.pb.collection('users').update(myId, body: {
      'pairingCode': newCode,
    });

    setState(() {
      _myCode = newCode;
      _isLoading = false;
    });
  }

  String _generateSixDigitCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _copyCode() async {
    if (_myCode == null) return;
    await Clipboard.setData(ClipboardData(text: _myCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod kopyalandı')),
      );
    }
  }

  Future<void> _connectWithPartner() async {
    final enteredCode = _codeInputController.text.trim();

    if (enteredCode.length != 6) {
      setState(() => _errorMessage = 'Lütfen 6 haneli bir kod girin');
      return;
    }

    if (enteredCode == _myCode) {
      setState(() => _errorMessage = 'Kendi kodunu giremezsin');
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final partnerQuery = await PbClient.pb.collection('users').getList(
            filter: 'pairingCode = "$enteredCode"',
          );

      if (partnerQuery.items.isEmpty) {
        setState(() {
          _errorMessage = 'Bu koda sahip bir kullanıcı bulunamadı';
          _isConnecting = false;
        });
        return;
      }

      final partnerRecord = partnerQuery.items.first;
      final partnerId = partnerRecord.id;
      final myId = PbClient.currentUserId!;

      await PbClient.pb.collection('users').update(myId, body: {
        'partnerId': partnerId,
      });
      await PbClient.pb.collection('users').update(partnerId, body: {
        'partnerId': myId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eşleştirme başarılı! 🎉')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StatusPage()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Bir hata oluştu: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Üst simge
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.roseEmber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Partnerinle bağlan',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 28,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kodunu paylaş ya da partnerinin kodunu gir',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Kod kartı
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 28, horizontal: 20),
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
                          const Text(
                            'SENİN KODUN',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _myCode ?? '------',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    color: AppColors.softPeach, size: 22),
                                onPressed: _copyCode,
                                tooltip: 'Kopyala',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('veya',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Partnerinin kodunu gir',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeInputController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 6,
                        color: AppColors.inkPlum,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '000000',
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.dangerRose, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isConnecting ? null : _connectWithPartner,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Eşleştir'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}