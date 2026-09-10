import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/bank_model.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/user_model.dart';

/// Reads the bundled JSON seed data.
///
/// Results are memoized because the widget tree calls these from `FutureBuilder`s
/// that rebuild often, and re-reading plus re-decoding an asset on every frame is
/// pure waste.
class Repository {
  Repository._();

  static final Repository instance = Repository._();

  factory Repository() => instance;

  List<Users>? _users;
  List<Balances>? _balances;
  List<Transactions>? _transactions;
  List<Banks>? _banks;

  Future<List<dynamic>> _loadList(String assetPath, String key) async {
    final response = await rootBundle.loadString(assetPath);
    return json.decode(response)[key] as List<dynamic>;
  }

  Future<List<Users>> getUsers() async {
    return _users ??= (await _loadList('lib/assets/json/user.json', 'users'))
        .map((item) => Users.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Users?> getUserById({required int id}) async {
    final users = await getUsers();
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<Users?> loginUser({
    required String emailOrUsername,
    required String password,
  }) async {
    final users = await getUsers();
    for (final user in users) {
      final matchesIdentity =
          user.email == emailOrUsername || user.username == emailOrUsername;
      if (matchesIdentity && user.password == password) return user;
    }
    return null;
  }

  Future<List<Balances>> getBalances() async {
    return _balances ??=
        (await _loadList('lib/assets/json/balance.json', 'data'))
            .map((item) => Balances.fromJson(item as Map<String, dynamic>))
            .toList();
  }

  Future<List<Transactions>> getTransactions() async {
    return _transactions ??=
        (await _loadList('lib/assets/json/transaction.json', 'transactions'))
            .map((item) => Transactions.fromJson(item as Map<String, dynamic>))
            .toList();
  }

  Future<List<Banks>> getBanks() async {
    return _banks ??= (await _loadList('lib/assets/json/bank.json', 'banks'))
        .map((item) => Banks.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
