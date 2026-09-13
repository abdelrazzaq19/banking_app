import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/data/media/profile_picture.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/profile_avatar_editor.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

/// A real PNG of [width] by [height], painted in two halves.
///
/// The halves are what make the crop assertions meaningful: a centred square
/// cut out of a wide image keeps different proportions of each colour than a
/// squashed one would.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFF0000FF),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();

  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The decoded dimensions of a stored picture.
Future<(int, int)> _sizeOf(String stored) async {
  final image = await decodeImageFromList(ProfilePicture.decode(stored)!);
  final size = (image.width, image.height);
  image.dispose();
  return size;
}

void main() {
  group('preparing a picture', () {
    testWidgets('a wide photo comes out square at the stored size',
        (tester) async {
      await tester.runAsync(() async {
        final (stored, failure) =
            await ProfilePicture.prepare(await _png(800, 400));

        expect(failure, isNull);
        expect(stored, isNotNull);
        expect(
          await _sizeOf(stored!),
          (ProfilePicture.size, ProfilePicture.size),
        );
      });
    });

    testWidgets('a tall photo comes out square too', (tester) async {
      await tester.runAsync(() async {
        final (stored, failure) =
            await ProfilePicture.prepare(await _png(300, 900));

        expect(failure, isNull);
        expect(
          await _sizeOf(stored!),
          (ProfilePicture.size, ProfilePicture.size),
        );
      });
    });

    testWidgets('a small photo is scaled up rather than left tiny',
        (tester) async {
      // Otherwise a 40px avatar would be re-stretched by every widget that
      // shows it, at whatever quality that widget happens to use.
      await tester.runAsync(() async {
        final (stored, _) = await ProfilePicture.prepare(await _png(40, 40));

        expect(
          await _sizeOf(stored!),
          (ProfilePicture.size, ProfilePicture.size),
        );
      });
    });

    testWidgets('a large photo is cut down, not stored whole', (tester) async {
      await tester.runAsync(() async {
        final raw = await _png(1600, 1600);
        final (stored, _) = await ProfilePicture.prepare(raw);

        // The stored string is base64, so it carries a third more bytes than
        // the image it holds — and is still far smaller than the original.
        expect(stored!.length, lessThan(raw.length));
      });
    });

    test('a file that is not an image is refused', () async {
      final (stored, failure) = await ProfilePicture.prepare(
        Uint8List.fromList(utf8.encode('this is a text file')),
      );

      expect(stored, isNull);
      expect(failure, PictureFailure.notAnImage);
      expect(failure!.message, contains('not an image'));
    });

    test('a file past the size ceiling is refused before decoding', () async {
      final huge = Uint8List(ProfilePicture.maxSourceBytes + 1);

      final (stored, failure) = await ProfilePicture.prepare(huge);

      expect(stored, isNull);
      expect(failure, PictureFailure.tooLarge);
      expect(failure!.message, contains('12MB'));
    });
  });

  group('stored pictures', () {
    test('a data URI is recognised and a URL is not', () {
      expect(ProfilePicture.isStored('data:image/png;base64,AAAA'), isTrue);
      expect(
        ProfilePicture.isStored('https://example.com/face.png'),
        isFalse,
      );
      expect(ProfilePicture.isStored(''), isFalse);
    });

    test('decoding a URL gives nothing', () {
      expect(ProfilePicture.decode('https://example.com/face.png'), isNull);
    });

    test('a corrupt stored value degrades instead of throwing', () {
      // A truncated or hand-edited store should cost the avatar, not the
      // screen it sits on.
      expect(ProfilePicture.decode('data:image/png;base64,!!!not base64'),
          isNull);
      expect(ProfilePicture.decode('data:image/png;base64'), isNull);
    });

    testWidgets('the avatar renders stored bytes rather than fetching them',
        (tester) async {
      late String stored;
      await tester.runAsync(() async {
        final (encoded, _) = await ProfilePicture.prepare(await _png(200, 200));
        stored = encoded!;
      });

      await tester.pumpWidget(MaterialApp(
        home: RemoteImage(
          url: stored,
          size: 84,
          fallback: (context) => const ProfilePhotoFallback(size: 84),
        ),
      ));
      await tester.pump();

      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a corrupt stored value falls back to the placeholder',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RemoteImage(
          url: 'data:image/png;base64,!!!',
          size: 84,
          fallback: (context) => const ProfilePhotoFallback(size: 84),
        ),
      ));
      await tester.pump();

      expect(find.byType(ProfilePhotoFallback), findsOneWidget);
    });
  });

  group('changing it from the profile screen', () {
    Future<TestBackend> signedIn() async {
      final backend = await createTestBackend();
      final registration = await backend.session.register(
        name: 'Ahmad Yusuf',
        username: 'ahmadyusuf',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
      );
      expect(registration.isSuccess, isTrue,
          reason: registration.failure?.name);
      return backend;
    }

    testWidgets('the avatar offers the change', (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      expect(find.byType(ProfileAvatarEditor), findsOneWidget);
      expect(
        find.bySemanticsLabel('Add a profile photo'),
        findsOneWidget,
      );
    });

    testWidgets('nobody signed in gets no way to change a picture',
        (tester) async {
      // There is no record to write one to.
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      expect(find.byType(ProfileAvatarEditor), findsNothing);
      expect(find.byType(ProfilePhotoFallback), findsOneWidget);
    });

    testWidgets('choosing a picture stores it against the user',
        (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      late Uint8List chosen;
      await tester.runAsync(() async => chosen = await _png(600, 400));

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: ProfileScreen(pickImage: () async => chosen),
      ));
      await tester.pump();

      await tester.tap(find.byType(ProfileAvatarEditor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tapped inside runAsync: preparing the picture decodes and re-encodes
      // through the engine, and the engine completes those futures on the real
      // clock, not the test's fake one.
      // Tapped inside runAsync: preparing the picture decodes and re-encodes
      // through the engine, and the engine completes those futures on the real
      // clock, not the test's fake one. Pumped in a loop rather than waited on
      // once, because the work needs frames as well as time.
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose a photo'));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (backend.session.currentUser!.image.isNotEmpty) break;
        }
      });
      await tester.pump();

      final image = backend.session.currentUser!.image;
      expect(ProfilePicture.isStored(image), isTrue);
      expect(ProfilePicture.decode(image), isNotEmpty);
    });

    testWidgets('the picture survives a relaunch', (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      late String stored;
      await tester.runAsync(() async {
        final (encoded, _) = await ProfilePicture.prepare(await _png(200, 200));
        stored = encoded!;
      });

      expect(await backend.session.setProfileImage(stored), isTrue);

      // A second session over the same store, as a restart would build.
      final relaunched = await createReloadedSession(backend);
      expect(relaunched.currentUser!.image, stored);
    });

    testWidgets('removing the picture clears it', (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      late String stored;
      await tester.runAsync(() async {
        final (encoded, _) = await ProfilePicture.prepare(await _png(200, 200));
        stored = encoded!;
      });
      await backend.session.setProfileImage(stored);

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const ProfileScreen(),
      ));
      await tester.pump();

      await tester.tap(find.byType(ProfileAvatarEditor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The wording changes once there is something to replace.
      expect(find.text('Change photo'), findsOneWidget);

      await tester.tap(find.text('Remove photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(backend.session.currentUser!.image, isEmpty);
    });

    testWidgets('cancelling the picker says nothing and changes nothing',
        (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: ProfileScreen(pickImage: () async => null),
      ));
      await tester.pump();

      await tester.tap(find.byType(ProfileAvatarEditor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Choose a photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(backend.session.currentUser!.image, isEmpty);
      // Cancelling is a decision, not an error worth a message.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a file that is not an image says so', (tester) async {
      useMobileSurface(tester);
      final backend = await signedIn();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: ProfileScreen(
          pickImage: () async =>
              Uint8List.fromList(utf8.encode('not an image')),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(ProfileAvatarEditor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        await tester.tap(find.text('Choose a photo'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.textContaining('not an image'), findsOneWidget);
      expect(backend.session.currentUser!.image, isEmpty);
    });
  });
}
