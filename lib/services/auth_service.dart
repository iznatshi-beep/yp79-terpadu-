// Impor dari supabase_flutter, bukan package:gotrue. `gotrue` bukan dependency
// langsung di pubspec dan `AuthStateChange` sudah tidak ada di gotrue 2.27
// (analyzer: undefined_shown_name) sehingga impor lama rapuh terhadap upgrade.
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, Session, Supabase;

import '../core/models/role.dart';
import '../core/models/session_profile.dart';

/// Layanan autentikasi: login, logout, refresh session.
///
/// SessionProfile dihydrate dari Supabase Auth + profiles +
/// parent_student / student_profiles tergantung role.
class AuthService {
  static Future<SessionProfile?> currentProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;
    return await _toProfile(session);
  }

  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  /// Stream perubahan session (login/logout/refresh).
  static Stream<SessionProfile?> sessionStream() {
    return Supabase.instance.client.auth.onAuthStateChange
        .asyncMap((data) async {
      if (data.event == AuthChangeEvent.signedOut) return null;
      if (data.session == null) return null;
      return await _toProfile(data.session!);
    }).asBroadcastStream();
  }

  static Future<SessionProfile> _toProfile(Session session) async {
    final user = session.user;
    final roleRaw = user.appMetadata['role'] as String? ??
        user.userMetadata?['role'] as String?;
    final name = user.userMetadata?['nama'] as String? ?? user.email;
    final role = Role.fromString(roleRaw);

    List<String> parentIds = const [];
    String? studentId;

    if (role == Role.orangTua) {
      parentIds = await _fetchParentStudentIds(user.id);
    } else if (role == Role.siswa) {
      studentId = user.id;
    }

    return SessionProfile(
      role: role,
      name: name,
      sub: user.id,
      email: user.email,
      studentId: studentId,
      parentStudentIds: parentIds,
    );
  }

  static Future<List<String>> _fetchParentStudentIds(String parentUserId) async {
    final rows = await Supabase.instance.client
        .from('parent_student')
        .select('student_user_id')
        .eq('parent_user_id', parentUserId)
        .eq('diverifikasi', true);
    return [
      for (final r in rows)
        r['student_user_id'] as String? ?? ''
    ].where((v) => v.isNotEmpty).toList();
  }
}
