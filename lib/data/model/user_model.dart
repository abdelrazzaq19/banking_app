import 'package:newtronic_banking/data/security/password_hasher.dart';

class User {
  User({required this.users});

  factory User.fromJson(Map<String, dynamic> json) => User(
        users: List<Users>.from(json['users'].map((x) => Users.fromJson(x))),
      );

  final List<Users> users;

  Map<String, dynamic> toJson() => {
        'users': List<dynamic>.from(users.map((x) => x.toJson())),
      };
}

/// A person who can sign in.
///
/// The password is held only as a hash. The seed file still ships plain text,
/// so [Users.fromJson] hashes anything that is not already hashed — which means
/// a plaintext password is converted the first time it is read and never
/// written back out in the clear.
class Users {
  const Users({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.image,
  });

  /// Builds a new user, hashing [password].
  factory Users.create({
    required int id,
    required String name,
    required String username,
    required String email,
    required String password,
    String image = '',
  }) =>
      Users(
        id: id,
        name: name,
        username: username,
        email: email,
        passwordHash: PasswordHasher.hash(password),
        image: image,
      );

  factory Users.fromJson(Map<String, dynamic> json) {
    final stored = (json['password_hash'] ?? json['password']) as String?;
    return Users(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash: PasswordHasher.isHashed(stored)
          ? stored!
          : PasswordHasher.hash(stored ?? ''),
      image: json['image'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String username;
  final String email;

  /// Encoded `pbkdf2-sha256$iterations$salt$hash`.
  final String passwordHash;

  final String image;

  /// Whether [password] is this user's password.
  bool hasPassword(String password) =>
      PasswordHasher.verify(password, passwordHash);

  /// Whether [identity] is this user's email or username, case-insensitively.
  bool matchesIdentity(String identity) {
    final needle = identity.trim().toLowerCase();
    return email.toLowerCase() == needle || username.toLowerCase() == needle;
  }

  /// [username] is deliberately not copyable: it is how an account is found at
  /// sign-in, and changing it would strand anyone who signs in by username.
  Users copyWith({
    String? name,
    String? email,
    String? image,
    String? passwordHash,
  }) =>
      Users(
        id: id,
        name: name ?? this.name,
        username: username,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        image: image ?? this.image,
      );

  /// Never writes a `password` field — only the hash.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'password_hash': passwordHash,
        'image': image,
      };
}
