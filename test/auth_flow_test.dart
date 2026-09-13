import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/user_model.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/data/security/password_hasher.dart';
import 'package:newtronic_banking/state/session_store.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('PasswordHasher', () {
    test('a password verifies against its own hash', () {
      final encoded = PasswordHasher.hash('Passw0rd!');
      expect(PasswordHasher.verify('Passw0rd!', encoded), isTrue);
    });

    test('a wrong password does not verify', () {
      final encoded = PasswordHasher.hash('Passw0rd!');
      expect(PasswordHasher.verify('passw0rd!', encoded), isFalse);
      expect(PasswordHasher.verify('', encoded), isFalse);
    });

    test('the same password hashes differently each time', () {
      // A fresh salt per hash, so two users with the same password do not
      // share a stored value.
      final first = PasswordHasher.hash('Passw0rd!');
      final second = PasswordHasher.hash('Passw0rd!');

      expect(first, isNot(second));
      expect(PasswordHasher.verify('Passw0rd!', first), isTrue);
      expect(PasswordHasher.verify('Passw0rd!', second), isTrue);
    });

    test('the hash never contains the password', () {
      final encoded = PasswordHasher.hash('Passw0rd!');
      expect(encoded.contains('Passw0rd!'), isFalse);
    });

    test('the encoding carries its own parameters', () {
      final encoded = PasswordHasher.hash('Passw0rd!');
      final parts = encoded.split(r'$');

      expect(parts, hasLength(4));
      expect(parts[0], PasswordHasher.algorithm);
      expect(int.parse(parts[1]), PasswordHasher.iterations);
    });

    test('malformed stored values fail rather than throw', () {
      for (final broken in [
        null,
        '',
        'not-a-hash',
        r'pbkdf2-sha256$notanumber$c2FsdA==$aGFzaA==',
        r'other-algo$1000$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$1000$!!!not-base64!!!$aGFzaA==',
      ]) {
        expect(PasswordHasher.verify('Passw0rd!', broken), isFalse,
            reason: 'should reject "$broken"');
      }
    });

    test('isHashed distinguishes a hash from plain text', () {
      expect(PasswordHasher.isHashed(PasswordHasher.hash('x')), isTrue);
      expect(PasswordHasher.isHashed('password123'), isFalse);
      expect(PasswordHasher.isHashed(null), isFalse);
    });
  });

  group('seeded users', () {
    test('plain-text seed passwords are hashed before being stored', () async {
      final backend = await createTestBackend();

      final stored = backend.store.readCollection(StoreKeys.users);
      expect(stored, isNotEmpty);

      for (final row in stored) {
        // The seed file ships `"password": "password123"`; none of that may
        // survive into the store.
        expect(row.containsKey('password'), isFalse);
        expect(PasswordHasher.isHashed(row['password_hash'] as String?), isTrue);
      }

      final raw = backend.store.readCollection(StoreKeys.users).toString();
      expect(raw.contains('password123'), isFalse);
    });

    test('a seeded user can still sign in with their original password',
        () async {
      final backend = await createTestBackend();

      final user = await backend.session.signInWithCredentials(
        emailOrUsername: 'john.doe@newtronic.com',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(user!.name, 'John Doe');
    });

    test('sign-in accepts either email or username, any case', () async {
      final backend = await createTestBackend();

      expect(
        await backend.session.signInWithCredentials(
          emailOrUsername: 'JOHNDOE123',
          password: 'password123',
        ),
        isNotNull,
      );
      expect(
        await backend.session.signInWithCredentials(
          emailOrUsername: 'John.Doe@Newtronic.com',
          password: 'password123',
        ),
        isNotNull,
      );
    });
  });

  group('registration', () {
    test('creates an account, signs in, and persists it', () async {
      final backend = await createTestBackend();
      final before = backend.repository.readUsers().length;

      final result = await backend.session.register(
        name: 'Siti Rahayu',
        username: 'sitirahayu',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );

      expect(result.isSuccess, isTrue);
      expect(backend.session.isSignedIn, isTrue);
      expect(backend.repository.readUsers(), hasLength(before + 1));
      expect(result.user!.id, isNot(0));
    });

    test('the new account survives a relaunch', () async {
      final backend = await createTestBackend();
      await backend.session.register(
        name: 'Siti Rahayu',
        username: 'sitirahayu',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );

      // Rebuild the data layer over the same store, as a relaunch would.
      final reopened = Repository(store: backend.store);
      await reopened.ensureSeeded();
      final session = SessionStore(
        repository: reopened,
        store: backend.store,
      );

      final signedIn = await session.signInWithCredentials(
        emailOrUsername: 'siti@example.com',
        password: 'Passw0rd!',
      );
      expect(signedIn, isNotNull);
      expect(signedIn!.name, 'Siti Rahayu');
    });

    test('the chosen password is never stored in the clear', () async {
      final backend = await createTestBackend();
      await backend.session.register(
        name: 'Siti Rahayu',
        username: 'sitirahayu',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );

      final raw = backend.store.readCollection(StoreKeys.users).toString();
      expect(raw.contains('Passw0rd!'), isFalse);
    });

    test('a taken email is refused and named', () async {
      final backend = await createTestBackend();

      final result = await backend.session.register(
        name: 'Impostor',
        username: 'freshname',
        email: 'john.doe@newtronic.com',
        password: 'Passw0rd!',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, RegistrationFailure.emailTaken);
    });

    test('a taken username is refused and named', () async {
      final backend = await createTestBackend();

      final result = await backend.session.register(
        name: 'Impostor',
        username: 'johndoe123',
        email: 'fresh@example.com',
        password: 'Passw0rd!',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, RegistrationFailure.usernameTaken);
    });

    test('a refused registration adds nobody', () async {
      final backend = await createTestBackend();
      final before = backend.repository.readUsers().length;

      await backend.session.register(
        name: 'Impostor',
        username: 'johndoe123',
        email: 'john.doe@newtronic.com',
        password: 'Passw0rd!',
      );

      expect(backend.repository.readUsers(), hasLength(before));
    });

    test('ids do not collide with the seeded users', () async {
      final backend = await createTestBackend();
      final existingIds =
          backend.repository.readUsers().map((user) => user.id).toSet();

      final result = await backend.session.register(
        name: 'Siti Rahayu',
        username: 'sitirahayu',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );

      expect(existingIds.contains(result.user!.id), isFalse);
    });
  });

  group('the full cycle', () {
    test('sign up, sign out, sign back in, wrong password rejected', () async {
      final backend = await createTestBackend();

      // Sign up.
      final registered = await backend.session.register(
        name: 'Siti Rahayu',
        username: 'sitirahayu',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );
      expect(registered.isSuccess, isTrue);
      expect(backend.session.isSignedIn, isTrue);

      // Sign out.
      await backend.session.signOut();
      expect(backend.session.isSignedIn, isFalse);
      expect(backend.store.readDocument(StoreKeys.session), isNull);

      // Wrong password is refused.
      expect(
        await backend.session.signInWithCredentials(
          emailOrUsername: 'siti@example.com',
          password: 'not-the-password',
        ),
        isNull,
      );
      expect(backend.session.isSignedIn, isFalse);

      // The real password works.
      final signedIn = await backend.session.signInWithCredentials(
        emailOrUsername: 'siti@example.com',
        password: 'Passw0rd!',
      );
      expect(signedIn, isNotNull);
      expect(backend.session.userId, registered.user!.id);
    });
  });

  group('Users model', () {
    test('toJson never emits a plaintext password field', () {
      final user = Users.create(
        id: 1,
        name: 'Siti',
        username: 'siti',
        email: 'siti@example.com',
        password: 'Passw0rd!',
      );

      final json = user.toJson();
      expect(json.containsKey('password'), isFalse);
      expect(json['password_hash'], isNot(contains('Passw0rd!')));
    });

    test('reading a legacy plaintext record hashes it', () {
      final user = Users.fromJson({
        'id': 1,
        'name': 'Legacy',
        'username': 'legacy',
        'email': 'legacy@example.com',
        'password': 'password123',
        'image': '',
      });

      expect(PasswordHasher.isHashed(user.passwordHash), isTrue);
      expect(user.hasPassword('password123'), isTrue);
      expect(user.hasPassword('wrong'), isFalse);
    });
  });
}
