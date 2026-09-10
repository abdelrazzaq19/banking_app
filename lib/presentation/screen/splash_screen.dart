import 'dart:async';

import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  void navigateToOtherScreen() {
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AuthenticationScreen.routeName);
    });
  }

  @override
  void initState() {
    super.initState();
    navigateToOtherScreen();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: Center(
        child: Image.asset(
          'lib/assets/images/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
