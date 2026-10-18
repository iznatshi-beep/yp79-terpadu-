import '../../../core/models/role.dart';

/// Informasi profil pengguna yang sedang login.
class SessionProfile {
  const SessionProfile({
    required this.role,
    this.name,
    this.sub,
    this.email,
    this.studentId,
    this.parentStudentIds = const [],
  });

  final Role role;
  final String? name;
  final String? sub;
  final String? email;

  /// ID siswa terkait (untuk role siswa / penghubung).
  final String? studentId;

  /// Untuk role orang tua: daftar siswa yang terhubung.
  final List<String> parentStudentIds;

  bool get isParent => role == Role.orangTua;
  bool get isStudent => role == Role.siswa;
  bool get isAdmin => role == Role.admin;
  bool get isStaff => role.isStaff;

  /// Apakah sesi ini terkait dengan siswa tertentu (untuk fetch data siswa).
  bool get hasStudentScope =>
      isStudent || (isParent && parentStudentIds.isNotEmpty);
}
