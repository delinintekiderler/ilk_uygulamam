import 'dart:math';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================================================================
// POCKETBASE SUNUCU ADRESİ — kendi domainine göre değiştir
// ================================================================
const String pocketbaseUrl = 'https://deneme.delinintekiderler.uk';

class PbClient {
  // Uygulama genelinde tek bir PocketBase bağlantısı kullanılır.
  static final PocketBase pb = PocketBase(pocketbaseUrl);

  static const _prefsEmailKey = 'pb_device_email';
  static const _prefsPasswordKey = 'pb_device_password';

  // Uygulama açıldığında çağrılır. Bu cihaz için daha önce
  // oluşturulmuş bir hesap varsa onunla giriş yapar, yoksa
  // rastgele bilgilerle yeni bir hesap oluşturup giriş yapar.
  // Firebase'deki "anonim giriş"e benzer bir davranış sağlar.
  static Future<void> ensureAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_prefsEmailKey);
    final savedPassword = prefs.getString(_prefsPasswordKey);

    if (savedEmail != null && savedPassword != null) {
      // Daha önce oluşturulmuş hesap var, onunla giriş yap.
      await pb
          .collection('users')
          .authWithPassword(savedEmail, savedPassword);
      return;
    }

    // İlk açılış — yeni bir hesap oluştur.
    final randomId = _generateRandomId();
    final email = '$randomId@device.local';
    final password = _generateRandomId(length: 20);

    await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });

    await pb.collection('users').authWithPassword(email, password);

    await prefs.setString(_prefsEmailKey, email);
    await prefs.setString(_prefsPasswordKey, password);
  }

  static String _generateRandomId({int length = 16}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Şu an giriş yapmış kullanıcının id'si.
  static String? get currentUserId => pb.authStore.record?.id;
}