import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/presentation/screen/main/account_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/balance_card.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

const _account = Balances(
  cardName: 'BlueSky',
  cardNumber: '1234 5678 9012 3456',
  balance: Money(5000000),
  expiryDate: '12/25',
  id: '001',
);

void main() {
  group('the profile screen', () {
    testWidgets('says so when nobody is signed in', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      expect(find.text('Not signed in'), findsOneWidget);
      // Nothing to sign out of, so the action is not offered either.
      expect(find.widgetWithText(AppButton, 'Sign out'), findsNothing);
    });

    testWidgets('shows the signed-in user and what they hold',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      final registration = await backend.session.register(
        name: 'Ahmad Yusuf',
        username: 'ahmadyusuf',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
      );
      expect(registration.isSuccess, isTrue,
          reason: registration.failure?.name);
      await backend.accounts.load();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      expect(find.text('Ahmad Yusuf'), findsWidgets);
      expect(find.text('ahmadyusuf'), findsOneWidget);
      expect(find.text('ahmad@example.com'), findsOneWidget);
      expect(find.text('Total balance'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Sign out'), findsOneWidget);
    });

    testWidgets('signing out clears the session', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      await backend.session.register(
        name: 'Ahmad Yusuf',
        username: 'ahmadyusuf',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
      );

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
        // Signing out clears the stack and lands on auth, so that route has
        // to exist or the navigation throws before the assertion is reached.
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('auth')),
          settings: settings,
        ),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      // Signing out asks first. Not pumpAndSettle: the dialog holds a looping
      // Lottie and never reaches a still frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sign out of Newtronic Banking?'), findsOneWidget);
      expect(backend.session.userId, isNotNull,
          reason: 'nothing happens until the question is answered');

      // Confirm, on the dialog's own button rather than the one behind it.
      await tester.tap(find.descendant(
        of: find.byType(AppDialog),
        matching: find.widgetWithText(AppButton, 'Sign out'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.userId, isNull);
      expect(find.text('auth'), findsOneWidget);
    });

    testWidgets('the theme choice is offered and takes effect',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      await backend.session.register(
        name: 'Ahmad Yusuf',
        username: 'ahmadyusuf',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
      );

      final controller = await ThemeController.load();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        themeController: controller,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(controller.mode, ThemeMode.dark);
    });
  });

  group('the account detail screen', () {
    testWidgets('shows the account it was opened for', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const AccountDetailScreen(
          balance: _account,
          label: 'Account',
          userId: 1,
        ),
      ));
      await tester.pump();

      expect(find.byType(BalanceCard), findsOneWidget);
      expect(find.text('Rp 5.000.000'), findsWidgets);
      expect(find.text('BlueSky'), findsWidgets);
    });

    testWidgets('offers both ways to move money', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const AccountDetailScreen(
          balance: _account,
          label: 'Account',
          userId: 1,
        ),
      ));
      await tester.pump();

      expect(find.widgetWithText(AppButton, 'Transfer'), findsOneWidget);
      // QRIS used to be a button with an empty callback.
      final qris =
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'QRIS'));
      expect(qris.onPressed, isNotNull);
    });

    testWidgets('the card here does not count its balance up', (tester) async {
      // It arrives as a Hero from the carousel, already showing the figure;
      // counting from zero on landing would read as the balance changing.
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const AccountDetailScreen(
          balance: _account,
          label: 'Account',
          userId: 1,
        ),
      ));
      await tester.pump();

      final card = tester.widget<BalanceCard>(find.byType(BalanceCard));
      expect(card.animateBalance, isFalse);
      expect(card.showActions, isFalse);
    });
  });
}

