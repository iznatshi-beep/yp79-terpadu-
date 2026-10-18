import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../shell/shell_page.dart';

/// Dashboard utama; merender konten sesuai peran pengguna.
class BerandaPage extends StatelessWidget {
  const BerandaPage({required this.profile, super.key});
  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    return ShellPage(profile: profile);
  }
}
