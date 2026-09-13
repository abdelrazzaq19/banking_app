import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashes and verifies passwords with PBKDF2-HMAC-SHA256.
///
/// **What this does and does not buy.** Storing a salted hash means the local
/// store never holds a readable password, so someone who opens the app's data
/// cannot read it back or try it on the user's other accounts. It is *not* a
/// security boundary: anything on the device can still call this code. Real
/// protection needs a server that never ships the hash to the client. The
/// seed data previously stored passwords in plain text, which this replaces.
abstract final class PasswordHasher {
  static const String algorithm = 'pbkdf2-sha256';

  /// Iteration count.
  ///
  /// Deliberately modest: this runs on the UI isolate on web as well as mobile,
  /// and a count high enough to matter against a serious offline attack would
  /// stall sign-in noticeably. Raising it is worthwhile only alongside moving
  /// the work off the main isolate.
  static const int iterations = 10000;

  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  static final Random _random = Random.secure();

  /// Hashes [password] with a fresh random salt.
  ///
  /// Returns a self-describing string — `pbkdf2-sha256$iterations$salt$hash` —
  /// so a stored credential carries the parameters it was made with and the
  /// cost can be raised later without invalidating existing ones.
  static String hash(String password) {
    final salt = _randomBytes(_saltBytes);
    final derived = _pbkdf2(password, salt, iterations, _keyBytes);
    return [
      algorithm,
      '$iterations',
      base64Url.encode(salt),
      base64Url.encode(derived),
    ].join(r'$');
  }

  /// Whether [password] produces [encoded].
  ///
  /// Returns false for anything malformed rather than throwing, so a corrupt
  /// stored credential fails the sign-in instead of crashing it.
  static bool verify(String password, String? encoded) {
    if (encoded == null || encoded.isEmpty) return false;

    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts[0] != algorithm) return false;

    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds <= 0) return false;

    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Url.decode(parts[2]);
      expected = base64Url.decode(parts[3]);
    } on FormatException {
      return false;
    }

    final actual = _pbkdf2(password, salt, rounds, expected.length);
    return _constantTimeEquals(actual, expected);
  }

  /// Whether [value] is already a hash this class produced.
  ///
  /// Used when seeding, where the bundled users still carry plain text.
  static bool isHashed(String? value) =>
      value != null && value.startsWith('$algorithm\$');

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int rounds,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final blockCount = (keyLength / 32).ceil();
    final output = BytesBuilder();

    for (var block = 1; block <= blockCount; block++) {
      // U1 = HMAC(password, salt || INT_BE(block))
      final blockIndex = Uint8List(4)
        ..[0] = block >> 24 & 0xff
        ..[1] = block >> 16 & 0xff
        ..[2] = block >> 8 & 0xff
        ..[3] = block & 0xff;

      var u = Uint8List.fromList(
        hmac.convert(<int>[...salt, ...blockIndex]).bytes,
      );
      final accumulated = Uint8List.fromList(u);

      // Un = HMAC(password, Un-1), XOR-folded into the accumulator.
      for (var round = 1; round < rounds; round++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var i = 0; i < accumulated.length; i++) {
          accumulated[i] ^= u[i];
        }
      }
      output.add(accumulated);
    }

    return Uint8List.fromList(output.takeBytes().sublist(0, keyLength));
  }

  /// Compares without an early exit, so the time taken does not leak how much
  /// of the hash matched.
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
