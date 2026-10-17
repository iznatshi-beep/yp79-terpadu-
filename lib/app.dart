import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';

class Yp79App extends StatelessWidget {
  const Yp79App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthBootstrapPage(),
    );
  }
}
