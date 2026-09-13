import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/bank_model.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/user_model.dart';

/// Owns the app's data: seeds it from the bundled JSON on first launch, then
/// reads and writes the local store.
///
/// Constructed once and injected. It used to be a singleton built inside
/// `build()`, which meant a fresh instance — and a fresh asset read — on every
/// frame that rebuilt a `FutureBuilder`.
class Repository {
  Repository({required LocalStore store, AssetBundle? bundle})
      : _store = store,
        _bundle = bundle ?? rootBundle;

  final LocalStore _store;
  final AssetBundle _bundle;

  /// Banks are reference data, not user data: they are never written, so they
  /// stay an asset read and are memoized rather than copied into the store.
  List<Banks>? _banks;

  // ------------------------------------------------------------------ seed

  /// Copies the bundled seed data into the store the first time the app runs.
  ///
  /// After this the store is authoritative — the assets are never read for
  /// accounts, transactions or users again, so a balance changed by a transfer
  /// is not quietly overwritten on the next launch.
  Future<void> ensureSeeded() async {
    if (!_store.isEmpty) {
      await _store.migrate();
      return;
    }

    // The bundled users carry plain-text passwords. Reading them through the
    // model hashes each one, and writing the model back means the plaintext
    // never reaches the store.
    final seedUsers = (await _readAsset('lib/assets/json/user.json', 'users'))
        .map(Users.fromJson)
        .toList();
    await writeUsers(seedUsers);
    await _store.writeCollection(
      StoreKeys.accounts,
      await _readAsset('lib/assets/json/balance.json', 'data'),
    );
    await _store.writeCollection(
      StoreKeys.transactions,
      await _readAsset('lib/assets/json/transaction.json', 'transactions'),
    );
    await _store.setVersion(LocalStore.currentVersion);
  }

  Future<List<Map<String, dynamic>>> _readAsset(
    String assetPath,
    String key,
  ) async {
    final response = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    return (decoded[key] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // ------------------------------------------------------------------ read

  List<Users> readUsers() => _store
      .readCollection(StoreKeys.users)
      .map(Users.fromJson)
      .toList();

  Users? findUser(int id) {
    for (final user in readUsers()) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Finds a user by email or username.
  Users? findUserByIdentity(String identity) {
    for (final user in readUsers()) {
      if (user.matchesIdentity(identity)) return user;
    }
    return null;
  }

  /// Whether an email or username is already taken.
  bool isIdentityTaken(String identity) => findUserByIdentity(identity) != null;

  /// Appends a new user, assigning the next free id.
  ///
  /// Returns null when the email or username is already in use, so the caller
  /// reports a collision rather than creating a second account nobody can
  /// reliably sign in to.
  Future<Users?> createUser({
    required String name,
    required String username,
    required String email,
    required String password,
    String image = '',
  }) async {
    final existing = readUsers();
    if (existing.any((user) =>
        user.matchesIdentity(email) || user.matchesIdentity(username))) {
      return null;
    }

    final nextId = existing.fold(0, (highest, user) =>
        user.id > highest ? user.id : highest) + 1;

    final created = Users.create(
      id: nextId,
      name: name,
      username: username,
      email: email,
      password: password,
      image: image,
    );

    await writeUsers([...existing, created]);
    return created;
  }

  /// Writes [updated] over the stored user with the same id.
  ///
  /// Returns false when no such user exists, so a caller cannot silently think
  /// it saved something it did not.
  Future<bool> updateUser(Users updated) async {
    final existing = readUsers();
    final index = existing.indexWhere((user) => user.id == updated.id);
    if (index < 0) return false;

    final next = [...existing];
    next[index] = updated;
    await writeUsers(next);
    return true;
  }

  List<Balances> readAccounts() => _store
      .readCollection(StoreKeys.accounts)
      .map(Balances.fromJson)
      .toList();

  List<Transactions> readTransactions() {
    final items = _store
        .readCollection(StoreKeys.transactions)
        .map(Transactions.fromJson)
        .toList();
    // Newest first, which is the order every screen wants to show them in.
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<List<Banks>> getBanks() async {
    return _banks ??= (await _readAsset('lib/assets/json/bank.json', 'banks'))
        .map(Banks.fromJson)
        .toList();
  }

  // ----------------------------------------------------------------- write

  Future<void> writeUsers(List<Users> users) => _store.writeCollection(
        StoreKeys.users,
        users.map((user) => user.toJson()).toList(),
      );

  Future<void> writeAccounts(List<Balances> accounts) =>
      _store.writeCollection(
        StoreKeys.accounts,
        accounts.map((account) => account.toJson()).toList(),
      );

  Future<void> writeTransactions(List<Transactions> transactions) =>
      _store.writeCollection(
        StoreKeys.transactions,
        transactions.map((transaction) => transaction.toJson()).toList(),
      );
}
