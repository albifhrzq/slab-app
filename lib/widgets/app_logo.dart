import 'package:flutter/material.dart';

/// Widget logo aplikasi kustom
/// Gunakan widget ini sebagai pengganti FlutterLogo di seluruh aplikasi
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({Key? key, this.size = 24.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
