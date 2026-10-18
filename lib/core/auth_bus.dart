import 'package:flutter/foundation.dart';

/// Dinaikkan setiap kali Supabase memancarkan perubahan status autentikasi
/// (login, logout, refresh token).
///
/// Kenapa terpisah dari `onAuthStateChange`: di perangkat tertentu event
/// pertama stream itu tidak pernah datang, sehingga gerbang sesi yang hanya
/// mendengarkan stream akan berhenti di layar "Memuat data sesi...".
/// Pemantau ini dipasang di `main()` pada titik yang PASTI berjalan, lalu
/// gerbang sesi tinggal membaca ulang profil saat nilainya berubah.
final ValueNotifier<int> authChanged = ValueNotifier<int>(0);
