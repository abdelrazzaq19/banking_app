import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys the app stores under, in one place so a typo cannot silently
/// create a second, empty collection.
abstract final class StoreKeys {
  static const String version = 'store.version';
  static const String accounts = 'store.accounts';
  static const String transactions = 'store.transactions';
  static const String users = 'store.users';
  static const String session = 'store.session';
  static const String favourites = 'store.favourites';
  static const String schedules = 'store.schedules';
  static const String budget = 'store.budget';
}

/// A small JSON document store on top of `shared_preferences`.
///
/// `shared_preferences` rather than a database because this has to run on web
/// and Windows as well as mobile, and the data here is a few dozen records.
/// Every value is stored as a JSON string, so collections and documents share
/// one mechanism.
class LocalStore {
  LocalStore(this._preferences);

  /// Bumped whenever the stored shape changes. [migrate] walks a store written
  /// by an older build up to this version rather than discarding it.
  static const int currentVersion = 1;

  final SharedPreferences _preferences;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  int get version => _preferences.getInt(StoreKeys.version) ?? 0;

  /// Whether anything has been written yet — the signal to seed from assets.
  bool get isEmpty => version == 0;

  Future<void> setVersion(int value) =>
      _preferences.setInt(StoreKeys.version, value);

  bool contains(String key) => _preferences.containsKey(key);

  /// Reads a single JSON object, or null when absent or unreadable.
  Map<String, dynamic>? readDocument(String key) {
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (error) {
      // Corrupt data should degrade to "absent" rather than crash on launch.
      debugPrint('LocalStore: could not decode document "$key": $error');
      return null;
    }
  }

  Future<void> writeDocument(String key, Map<String, dynamic> value) =>
      _preferences.setString(key, jsonEncode(value));

  /// Reads a JSON array, or an empty list when absent or unreadable.
  List<Map<String, dynamic>> readCollection(String key) {
    final raw = _preferences.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } on FormatException catch (error) {
      debugPrint('LocalStore: could not decode collection "$key": $error');
      return const [];
    }
  }

  Future<void> writeCollection(
    String key,
    List<Map<String, dynamic>> items,
  ) =>
      _preferences.setString(key, jsonEncode(items));

  Future<void> remove(String key) => _preferences.remove(key);

  /// Wipes everything this app stored. Used by tests and by a future
  /// "sign out and forget me".
  Future<void> clear() async {
    for (final key in [
      StoreKeys.version,
      StoreKeys.accounts,
      StoreKeys.transactions,
      StoreKeys.users,
      StoreKeys.session,
      StoreKeys.favourites,
      StoreKeys.schedules,
      StoreKeys.budget,
    ]) {
      await _preferences.remove(key);
    }
  }

  /// Brings a store written by an older build up to [currentVersion].
  ///
  /// There is only one version so far, so this has nothing to do yet — it
  /// exists so the first real shape change has somewhere to go instead of
  /// forcing a wipe.
  Future<void> migrate() async {
    var from = version;
    if (from == currentVersion) return;

    // Future migrations land here as `if (from < n) { ...; from = n; }`.

    if (from != currentVersion) {
      await setVersion(currentVersion);
      from = currentVersion;
    }
  }
}
