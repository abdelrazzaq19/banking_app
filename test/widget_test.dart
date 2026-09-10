import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/main.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/splash_screen.dart';

void main() {
  testWidgets('app starts on the splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(AuthenticationScreen), findsNothing);
  });

  testWidgets('splash advances to authentication after its delay',
      (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AuthenticationScreen), findsOneWidget);
  });

  testWidgets('splash cancels its timer when torn down early', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Replacing the tree disposes SplashScreen before its 3s timer fires. If the
    // timer were not cancelled, the test would fail with a pending-timer error.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(SplashScreen), findsNothing);
  });
}
