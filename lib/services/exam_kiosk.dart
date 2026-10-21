import 'package:flutter/services.dart';

/// Jembatan ke native Android untuk mode ujian (anti-cheat).
///
/// Versi "tidak terlalu hard" (sesuai permintaan):
/// - FLAG_SECURE: screenshot & thumbnail recents diblokir saat ujian
/// - Immersive sticky + enforcer: status bar otomatis disembunyikan lagi
/// - Fokus hilang (overlay/pindah app): alarm bunyi (stream alarm saja,
///   volume media tidak disentuh) + app balik sendiri ke depan
/// - Back/Home/Recents fisik diblokir selama ujian
/// - Lock task (pinning) dicoba — di HP biasa muncul dialog "Got it";
///   tanpa device owner pun semuanya tetap berfungsi.
class ExamKiosk {
  static const _channel = MethodChannel('com.yp79terpadu.yp79_terpadu/exam');

  /// Event dari native: fokus hilang / overlay terdeteksi.
  static void onIntrusion(void Function()? cb) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntrusion') cb?.call();
    });
  }

  static void detach() {
    _channel.setMethodCallHandler(null);
  }

  /// Aktifkan/nonaktifkan anti-screenshot (FLAG_SECURE).
  static Future<bool> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Masuk mode ujian (soft kiosk).
  static Future<bool> enterKiosk() async {
    try {
      final ok = await _channel.invokeMethod('enterKiosk');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Keluar mode kiosk.
  static Future<bool> exitKiosk() async {
    try {
      await _channel.invokeMethod('exitKiosk');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mulai alarm peringatan (stream alarm + getar).
  static Future<bool> alarmStart() async {
    try {
      await _channel.invokeMethod('alarmStart');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> alarmStop() async {
    try {
      await _channel.invokeMethod('alarmStop');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDeviceOwner() async {
    try {
      final ok = await _channel.invokeMethod('isDeviceOwner');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}
