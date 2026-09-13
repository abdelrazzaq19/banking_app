import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/data/utils/identity_rules.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/session_store.dart';

import 'support/test_harness.dart';

Future<TestBackend> _signedIn() async {
  final backend = await createTestBackend();
  final registration = await backend.session.register(
    name: 'Ahmad Yusuf',
    username: 'ahmadyusuf',
    email: 'ahmad@example.com',
    password: 'Passw0rd!',
  );
  expect(registration.isSuccess, isTrue, reason: registration.failure?.name);
  return backend;
}

/// Pumps past the staggered reveal.
///
/// The rows fade in through an `Opacity`, and an opacity of zero drops its
/// subtree from the semantics tree — so until the animation has run, the rows
/// cannot be found by their label.
Future<void> _revealed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

/// Opens the editor behind the row labelled [label].
Future<void> _openEditor(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(RegExp('Change your $label')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _sheetField(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(AppTextField),
    );

void main() {
  group('the rules are shared with sign-up', () {
    test('a name has to be text, of a sensible length', () {
      expect(validateFullName('Ahmad Yusuf'), isNull);
      expect(validateFullName(''), 'Full Name is required');
      expect(validateFullName('Al'), contains('3 to 50'));
      expect(validateFullName('Ahmad 3'), contains('text only'));
    });

    test('an email has to look like one', () {
      expect(validateEmail('ahmad@example.com'), isNull);
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail('ahmad@example'), contains('format'));
      expect(validateEmail('not an email'), contains('format'));
    });

    test('a username is still checked, even though it cannot be edited', () {
      // Kept in the shared rules because sign-up uses it; the profile screen
      // deliberately does not offer it.
      expect(validateUsername('ahmadyusuf'), isNull);
      expect(validateUsername('short'), contains('6 to 12'));
    });
  });

  group('updateProfile', () {
    test('changes the name and writes it', () async {
      final backend = await _signedIn();

      expect(await backend.session.updateProfile(name: 'Ahmad Yusuf Wijaya'),
          isNull);

      expect(backend.session.currentUser!.name, 'Ahmad Yusuf Wijaya');
      final relaunched = await createReloadedSession(backend);
      expect(relaunched.currentUser!.name, 'Ahmad Yusuf Wijaya');
    });

    test('changes the email and writes it', () async {
      final backend = await _signedIn();

      expect(await backend.session.updateProfile(email: 'new@example.com'),
          isNull);

      final relaunched = await createReloadedSession(backend);
      expect(relaunched.currentUser!.email, 'new@example.com');
    });

    test('leaves the other field alone', () async {
      final backend = await _signedIn();

      await backend.session.updateProfile(name: 'Ahmad Yusuf Wijaya');

      expect(backend.session.currentUser!.email, 'ahmad@example.com');
      expect(backend.session.currentUser!.username, 'ahmadyusuf');
    });

    test('saving an unchanged email is not a collision with oneself',
        () async {
      // The obvious way to write the check — "is this email taken?" — would
      // refuse this, because the answer is yes, by the person asking.
      final backend = await _signedIn();

      expect(
        await backend.session.updateProfile(email: 'ahmad@example.com'),
        isNull,
      );
    });

    test('refuses an email another account already uses', () async {
      final backend = await _signedIn();
      // The seeded users are already in the store; take one of their emails.
      final other = backend.repository
          .readUsers()
          .firstWhere((user) => user.username != 'ahmadyusuf');

      expect(
        await backend.session.updateProfile(email: other.email),
        ProfileUpdateFailure.emailTaken,
      );
      expect(backend.session.currentUser!.email, 'ahmad@example.com');
    });

    test('refuses a name or email the rules reject', () async {
      final backend = await _signedIn();

      expect(await backend.session.updateProfile(name: 'A'),
          ProfileUpdateFailure.invalidName);
      expect(await backend.session.updateProfile(email: 'nope'),
          ProfileUpdateFailure.invalidEmail);
      expect(backend.session.currentUser!.name, 'Ahmad Yusuf');
    });

    test('trims what it is given', () async {
      final backend = await _signedIn();

      await backend.session.updateProfile(
        name: '  Ahmad Yusuf Wijaya  ',
        email: '  spaced@example.com  ',
      );

      expect(backend.session.currentUser!.name, 'Ahmad Yusuf Wijaya');
      expect(backend.session.currentUser!.email, 'spaced@example.com');
    });

    test('refuses everything when nobody is signed in', () async {
      final backend = await createTestBackend();

      expect(await backend.session.updateProfile(name: 'Ahmad Yusuf'),
          ProfileUpdateFailure.notSignedIn);
    });

    test('every failure says something a person can act on', () {
      for (final failure in ProfileUpdateFailure.values) {
        expect(failure.message, isNotEmpty);
        expect(failure.message, endsWith('.'));
      }
    });
  });

  group('editing from the profile screen', () {
    testWidgets('the editable rows say they are editable', (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      expect(find.bySemanticsLabel(RegExp('Change your name')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Change your email')),
        findsOneWidget,
      );
      // Username is shown, and deliberately not offered.
      expect(
        find.bySemanticsLabel(RegExp('Change your username')),
        findsNothing,
      );
    });

    testWidgets('changing the name updates the screen', (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'name');
      expect(find.text('Your name'), findsOneWidget);

      await tester.enterText(_sheetField('Full Name'), 'Ahmad Yusuf Wijaya');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.currentUser!.name, 'Ahmad Yusuf Wijaya');
      // The header shows it too, not just the row.
      expect(find.text('Ahmad Yusuf Wijaya'), findsWidgets);
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('changing the email updates the screen', (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'email');
      await tester.enterText(_sheetField('Email'), 'new@example.com');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.currentUser!.email, 'new@example.com');
      expect(find.text('new@example.com'), findsOneWidget);
    });

    testWidgets('Save stays disabled while the value breaks a rule',
        (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'email');

      AppButton save() =>
          tester.widget<AppButton>(find.widgetWithText(AppButton, 'Save'));

      // Unchanged: nothing to save.
      expect(save().onPressed, isNull);

      await tester.enterText(_sheetField('Email'), 'not an email');
      await tester.pump();
      expect(save().onPressed, isNull);
      expect(find.textContaining('format'), findsOneWidget);

      await tester.enterText(_sheetField('Email'), 'fine@example.com');
      await tester.pump();
      expect(save().onPressed, isNotNull);
    });

    testWidgets('the sheet does not scold before anything is typed',
        (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'name');

      expect(find.textContaining('required'), findsNothing);
      expect(find.textContaining('3 to 50'), findsNothing);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'name');
      await tester.enterText(_sheetField('Full Name'), 'Someone Else');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(backend.session.currentUser!.name, 'Ahmad Yusuf');
    });

    testWidgets('a collision is reported, since the field cannot know',
        (tester) async {
      useMobileSurface(tester);
      final backend = await _signedIn();
      final other = backend.repository
          .readUsers()
          .firstWhere((user) => user.username != 'ahmadyusuf');

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await _revealed(tester);

      await _openEditor(tester, 'email');
      await tester.enterText(_sheetField('Email'), other.email);
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text(ProfileUpdateFailure.emailTaken.message),
        findsOneWidget,
      );
      expect(backend.session.currentUser!.email, 'ahmad@example.com');
    });
  });
}
