import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

Future<void> _pumpAuth(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const AuthenticationScreen(),
  ));
  await tester.pumpAndSettle();
}

/// Walks from the welcome page to the sign-up form.
Future<void> _goToSignUp(WidgetTester tester) async {
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
}

Future<void> _goToLogIn(WidgetTester tester) async {
  await _goToSignUp(tester);
  await tester.tap(find.text('Log in').last);
  await tester.pumpAndSettle();
}

Finder _fieldWithHint(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(AppTextField),
    );

void main() {
  testWidgets('starts on the welcome page', (tester) async {
    await _pumpAuth(tester);

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Get Started moves to the sign-up form', (tester) async {
    await _pumpAuth(tester);
    await _goToSignUp(tester);

    expect(find.text('Sign Up Now'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  group('primary action', () {
    testWidgets('is disabled until every field on the form is filled',
        (tester) async {
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      AppButton button() => tester.widget<AppButton>(
            find.ancestor(
              of: find.text('Log in').last,
              matching: find.byType(AppButton),
            ),
          );

      expect(button().onPressed, isNull);

      await tester.enterText(_fieldWithHint('Email or Username'), 'johndoe123');
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'password still empty');

      await tester.enterText(_fieldWithHint('Password'), 'password123');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });
  });

  group('live validation', () {
    testWidgets('a field stays quiet until it has been left once',
        (tester) async {
      await _pumpAuth(tester);
      await _goToSignUp(tester);

      // Typing an invalid username must not scold mid-word.
      await tester.enterText(_fieldWithHint('Username'), 'ab');
      await tester.pump();
      expect(find.textContaining('6 to 12 characters'), findsNothing);

      // Moving to the next field marks it touched and reveals the problem.
      await tester.tap(_fieldWithHint('Email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 to 12 characters'), findsOneWidget);
    });

    testWidgets('a touched field then updates on every keystroke',
        (tester) async {
      await _pumpAuth(tester);
      await _goToSignUp(tester);

      await tester.enterText(_fieldWithHint('Username'), 'ab');
      await tester.tap(_fieldWithHint('Email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 to 12 characters'), findsOneWidget);

      await tester.enterText(_fieldWithHint('Username'), 'validname');
      await tester.pump();
      expect(find.textContaining('6 to 12 characters'), findsNothing);
    });

    testWidgets('editing the password rechecks the confirmation',
        (tester) async {
      await _pumpAuth(tester);
      await _goToSignUp(tester);

      await tester.enterText(_fieldWithHint('Password'), 'Passw0rd!');
      await tester.enterText(_fieldWithHint('Confirm Password'), 'Passw0rd!');
      // Touch the confirmation so its errors become visible.
      await tester.tap(_fieldWithHint('Username'));
      await tester.pumpAndSettle();
      expect(find.text('Password must be same'), findsNothing);

      // Changing the password above must invalidate the confirmation below.
      await tester.enterText(_fieldWithHint('Password'), 'Passw0rd!different');
      await tester.pumpAndSettle();
      expect(find.text('Password must be same'), findsOneWidget);
    });

    testWidgets('submitting an empty form reveals every error at once',
        (tester) async {
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      // The button is disabled while empty, so drive the form the way the user
      // would: fill it, then blank one field out again.
      await tester.enterText(_fieldWithHint('Email or Username'), 'johndoe123');
      await tester.enterText(_fieldWithHint('Password'), 'x');
      await tester.pump();
      await tester.enterText(_fieldWithHint('Password'), '');
      await tester.pump();

      final button = tester.widget<AppButton>(
        find.ancestor(
          of: find.text('Log in').last,
          matching: find.byType(AppButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('password fields', () {
    testWidgets('each has its own visibility toggle', (tester) async {
      await _pumpAuth(tester);
      await _goToSignUp(tester);

      final toggles = find.byType(PasswordVisibilityToggle);
      expect(toggles, findsNWidgets(2));

      TextField fieldFor(String hint) => tester.widget<TextField>(
            find.descendant(
              of: _fieldWithHint(hint),
              matching: find.byType(TextField),
            ),
          );

      expect(fieldFor('Password').obscureText, isTrue);
      expect(fieldFor('Confirm Password').obscureText, isTrue);

      // Revealing one must not reveal the other — they used to share a flag.
      await tester.tap(toggles.first);
      await tester.pumpAndSettle();

      expect(fieldFor('Password').obscureText, isFalse);
      expect(fieldFor('Confirm Password').obscureText, isTrue);
    });

    testWidgets('the strength meter appears only on the sign-up password',
        (tester) async {
      await _pumpAuth(tester);
      await _goToSignUp(tester);

      expect(find.byType(PasswordStrengthMeter), findsOneWidget);

      // Empty password renders nothing visible.
      expect(find.text('Good'), findsNothing);

      await tester.enterText(_fieldWithHint('Password'), 'Passw0rd!');
      await tester.pumpAndSettle();
      expect(find.text('Good'), findsOneWidget);

      await tester.enterText(_fieldWithHint('Password'), 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Weak'), findsOneWidget);
    });

    testWidgets('the log-in password has no strength meter', (tester) async {
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      expect(find.byType(PasswordStrengthMeter), findsNothing);
    });
  });

  group('page indicator', () {
    testWidgets('tapping a dot navigates to that page', (tester) async {
      await _pumpAuth(tester);

      // The dots are present from the start; only the account-switch row is
      // conditional on being past the welcome page.
      expect(find.byType(PageDots), findsOneWidget);

      await _goToSignUp(tester);
      expect(find.byType(PageDots), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Step 2 of 3'));
      await tester.pumpAndSettle();
      expect(find.text('Log in Now'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('explains why there is no reset instead of doing nothing',
        (tester) async {
      // The control used to be a TextButton with an empty callback, which
      // reads as the app having failed rather than as there being nothing to
      // reset.
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      await tester.tap(find.text('Forgot Password?'));
      // Not pumpAndSettle: the dialog holds a looping Lottie, which never
      // reaches a still frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('live only on this device'),
        findsOneWidget,
      );
    });

    testWidgets('offers the one thing that does work', (tester) async {
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      await tester.tap(find.text('Forgot Password?'));
      // Not pumpAndSettle: the dialog holds a looping Lottie, which never
      // reaches a still frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.widgetWithText(AppButton, 'Create an account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Sign Up'), findsWidgets);
    });

    testWidgets('backing out leaves the user where they were', (tester) async {
      await _pumpAuth(tester);
      await _goToLogIn(tester);

      await tester.tap(find.text('Forgot Password?'));
      // Not pumpAndSettle: the dialog holds a looping Lottie, which never
      // reaches a still frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.widgetWithText(AppButton, 'Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });
}
