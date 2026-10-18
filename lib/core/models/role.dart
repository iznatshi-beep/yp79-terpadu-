/// Peran pengguna dalam sistem sekolah terpadu.
enum Role {
  admin('Administrator'),
  guru('Guru'),
  guruPembimbing('Guru Pembimbing'),
  siswa('Siswa'),
  orangTua('Orang Tua');

  const Role(this.label);
  final String label;

  bool get isFullAccess => this == Role.admin;
  bool get isStaff => this == Role.admin || this == Role.guru || this == Role.guruPembimbing;
  bool get isStudentSide => this == Role.siswa || this == Role.orangTua;

  static Role fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Role.admin;
      case 'guru':
        return Role.guru;
      case 'guru_pembimbing':
      case 'guru pembimbing':
      case 'pembimbing':
        return Role.guruPembimbing;
      case 'siswa':
      case 'student':
        return Role.siswa;
      case 'orang_tua':
      case 'orang tua':
      case 'parent':
        return Role.orangTua;
      default:
        return Role.siswa;
    }
  }

  @override
  String toString() => label;
}
