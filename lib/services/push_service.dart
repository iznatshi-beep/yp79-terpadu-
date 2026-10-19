import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

/// Registrasi perangkat untuk push notification (Firebase Cloud Messaging).
///
/// Token disimpan di tabel `push_tokens` (unique per token) supaya server tahu
/// perangkat mana yang harus dikirim notif. Gagal di sini TIDAK boleh
/// membuat aplikasi tidak bisa dipakai - push hanya telemetri tambahan.
class PushService {
  PushService._();

  /// Dipanggil sekali setelah pengguna masuk.
  static Future<void> daftarkan() async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      final token = await fcm.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM: token kosong, push tidak diaktifkan.');
        return;
      }
      await _simpan(token);

      // Token bisa berubah (reinstall/update) - simpan ulang tiap berubah.
      FirebaseMessaging.instance.onTokenRefresh.listen(_simpan);

      // Notif saat app di foreground.
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        debugPrint('FCM push (foreground): ${m.notification?.title}');
      });
      // Notif ditekan saat app background/tertutup.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
        debugPrint('Push dibuka: ${m.notification?.title}');
      });
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m?.notification != null) debugPrint('Push dibuka (initial).');
      });

      debugPrint('FCM siap: token tersimpan.');
    } catch (e) {
      debugPrint('FCM tidak aktif: $e');
    }
  }

  /// Simpan token untuk pengguna yang sedang login (RPC server-side).
  static Future<void> _simpan(String token) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.rpc('simpan_push_token', params: {'p_token': token});
    } catch (e) {
      debugPrint('Simpan FCM token gagal (diabaikan): $e');
    }
  }
}
