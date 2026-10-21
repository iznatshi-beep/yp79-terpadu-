import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'repositories.dart';

/// Tracker GPS bus: kirim posisi HP pengemudi ke `vehicle_locations`
/// tiap ~20 detik selama mode mengemudi aktif.
///
/// Pemakaian:
/// ```dart
/// await TrackerBus.start(vehicleId);   // sopir tekan "Mulai"
/// await TrackerBus.stop();             // sopir tekan "Selesai"
/// final aktif = TrackerBus.berjalan;   // indikator UI
/// ```
///
/// Catatan desain:
/// - **Foreground-first**: tracker berjalan selama halaman terbuka.
///   Android mematikan timer saat app dibunuh — itu batas tanpa
///   foreground service (butuh penjelasan & izin khusus; belum dipakai).
/// - Error GPS / jaringan tidak melempar — sekadar log & coba lagi
///   di tick berikutnya. Mode ini pelengkap, bukan fitur kritikal.
class TrackerBus {
  TrackerBus._();

  static Timer? _timer;
  static String? _vehicleId;
  static DateTime? _mulai;
  static int _terkirim = 0;
  static String? _errorTerakhir;

  /// Apakah tracker sedang aktif untuk [vehicleId] tertentu (atau apapun).
  static bool get berjalan => _timer != null;

  static String? get vehicleIdAktif => _vehicleId;

  static DateTime? get mulaiPada => _mulai;

  static int get jumlahTerkirim => _terkirim;

  static String? get errorTerakhir => _errorTerakhir;

  /// Mulai kirim posisi. Return null jika sukses, atau pesan error
  /// (mis. izin lokasi ditolak / GPS mati).
  static Future<String?> start(String vehicleId) async {
    if (_timer != null) {
      if (_vehicleId == vehicleId) return null;
      stop(); // ganti bus — matikan dulu
    }
    final izin = await _pastikanIzin();
    if (izin != null) return izin;

    _vehicleId = vehicleId;
    _mulai = DateTime.now();
    _terkirim = 0;
    _errorTerakhir = null;

    // Kirim posisi pertama segera, lalu periodik.
    await _kirim();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _kirim());
    return null;
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _vehicleId = null;
    _mulai = null;
  }

  static Future<String?> _pastikanIzin() async {
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      return 'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan '
          'untuk melacak posisi bus.';
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Lokasi (GPS) mati. Nyalakan GPS di perangkat ini.';
    }
    return null;
  }

  static Future<void> _kirim() async {
    final vid = _vehicleId;
    if (vid == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final err = await Repos.kirimLokasiBus(
        vehicleId: vid,
        lat: pos.latitude,
        lng: pos.longitude,
        heading: pos.heading >= 0 ? pos.heading : null,
        kecepatanKph:
            pos.speed >= 0 ? pos.speed * 3.6 : null, // m/s → km/jam
      );
      if (err == null) {
        _terkirim++;
        _errorTerakhir = null;
      } else {
        _errorTerakhir = err;
      }
    } catch (e) {
      _errorTerakhir = e.toString();
    }
  }
}
