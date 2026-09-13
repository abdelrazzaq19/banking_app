import 'dart:async';

import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// How long the logo is held on screen before handing over. Shorter than the
  /// old flat three seconds, because the entrance animation now gives the wait
  /// something to do rather than staring at a static image.
  static const Duration _holdDuration = Duration(milliseconds: 2200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  /// The logo fades in over the first half, then holds.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Motion.enter),
  );

  /// A slight overshoot on the way in, so the mark lands rather than appears.
  late final Animation<double> _scale = Tween<double>(begin: 0.86, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Motion.spring),
  );

  /// The glow behind the logo trails the mark slightly.
  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 1, curve: Motion.enter),
  );

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _navigationTimer = Timer(_holdDuration, _goToNextScreen);
  }

  /// Sends a returning user straight to their accounts.
  ///
  /// Reading the session here is what stops the login screen flashing at
  /// someone who never signed out.
  void _goToNextScreen() {
    if (!mounted) return;

    final session = context.read<SessionStore?>();
    final userId = session?.userId;

    if (userId == null) {
      Navigator.pushReplacementNamed(context, AuthenticationScreen.routeName);
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      HomeScreen.routeName,
      arguments: userId,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              // A soft brand-coloured wash behind the mark, so the screen is not
              // a flat field with a logo dropped on it.
              Opacity(
                opacity: _glow.value * 0.5,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.35),
                        colors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: _fade.value,
                child: Transform.scale(scale: _scale.value, child: child),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Image.asset(
              'lib/assets/images/logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'Newtronic Banking',
            ),
          ),
        ),
      ),
    );
  }
}
