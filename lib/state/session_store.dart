import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/user_model.dart';
import 'package:newtronic_banking/data/repository/repository.dart';

/// Why a registration was refused.
enum RegistrationFailure { emailTaken, usernameTaken }

/// The outcome of [SessionStore.register].
class RegistrationResult {
  const RegistrationResult.success(this.user) : failure = null;
  const RegistrationResult.failure(this.failure) : user = null;

  final Users? user;
  final RegistrationFailure? failure;

  bool get isSuccess => user != null;
}

/// Who is signed in, and whether they stay signed in across launches.
///
/// Task 10 adds account creation and password hashing on top of this; for now
/// it holds the session itself, which is what lets the rest of the app stop
/// passing a user id through every route.
class SessionStore extends ChangeNotifier {
  SessionStore({required Repository repository, required LocalStore store})
      : _repository = repository,
        _store = store;

  static const String _userIdField = 'userId';

  final Repository _repository;
  final LocalStore _store;

  int? _userId;
  bool _isRestored = false;

  int? get userId => _userId;
  bool get isSignedIn => _userId != null;

  /// False until [restore] has run, so the app can hold the splash rather than
  /// flashing the login screen at someone who is already signed in.
  bool get isRestored => _isRestored;

  Users? get currentUser {
    final id = _userId;
    return id == null ? null : _repository.findUser(id);
  }

  /// Reads any saved session back.
  Future<void> restore() async {
    final saved = _store.readDocument(StoreKeys.session);
    final id = saved?[_userIdField];
    // Only trust the saved id if that user still exists.
    _userId = id is int && _repository.findUser(id) != null ? id : null;
    _isRestored = true;
    notifyListeners();
  }

  /// Checks credentials against the stored users and signs the match in.
  ///
  /// Returns the user, or null when the identity is unknown or the password is
  /// wrong. Both failures look the same to the caller on purpose: telling them
  /// apart would confirm which accounts exist.
  Future<Users?> signInWithCredentials({
    required String emailOrUsername,
    required String password,
  }) async {
    final user = _repository.findUserByIdentity(emailOrUsername);
    if (user == null || !user.hasPassword(password)) return null;

    await signIn(user.id);
    return user;
  }

  /// Creates an account and signs into it.
  ///
  /// Returns the outcome so the form can say what went wrong, rather than
  /// reporting a generic failure for a name that is simply taken.
  Future<RegistrationResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    if (_repository.isIdentityTaken(email)) {
      return const RegistrationResult.failure(RegistrationFailure.emailTaken);
    }
    if (_repository.isIdentityTaken(username)) {
      return const RegistrationResult.failure(
        RegistrationFailure.usernameTaken,
      );
    }

    final created = await _repository.createUser(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    if (created == null) {
      return const RegistrationResult.failure(RegistrationFailure.emailTaken);
    }

    await signIn(created.id);
    return RegistrationResult.success(created);
  }

  Future<void> signIn(int userId) async {
    _userId = userId;
    await _store.writeDocument(StoreKeys.session, {_userIdField: userId});
    notifyListeners();
  }

  Future<void> signOut() async {
    _userId = null;
    await _store.remove(StoreKeys.session);
    notifyListeners();
  }
}
