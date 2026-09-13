import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';

/// Saved recipients, newest first.
class FavouriteStore extends ChangeNotifier {
  FavouriteStore(this._store);

  final LocalStore _store;

  List<FavouriteTransfer> _favourites = const [];
  bool _isLoaded = false;

  List<FavouriteTransfer> get favourites => List.unmodifiable(_favourites);
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _favourites.isEmpty;

  Future<void> load() async {
    _favourites = _store
        .readCollection(StoreKeys.favourites)
        .map(FavouriteTransfer.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isLoaded = true;
    notifyListeners();
  }

  bool contains(String id) =>
      _favourites.any((favourite) => favourite.id == id);

  /// Whether this receipt's destination is already saved.
  bool containsReceipt(TransferReceipt receipt) => contains(
        favouriteIdFor(
          bankName: receipt.bankName,
          accountNumber: receipt.accountNumber,
        ),
      );

  /// Saves a recipient, replacing any existing entry for the same destination.
  ///
  /// Replacing rather than appending is what keeps a frequently-paid person
  /// from filling the list with near-identical rows.
  Future<void> save(FavouriteTransfer favourite) async {
    _favourites = [
      favourite,
      ..._favourites.where((existing) => existing.id != favourite.id),
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> saveReceipt(TransferReceipt receipt) =>
      save(FavouriteTransfer.fromReceipt(receipt));

  Future<void> remove(String id) async {
    _favourites =
        _favourites.where((favourite) => favourite.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _store.writeCollection(
        StoreKeys.favourites,
        _favourites.map((favourite) => favourite.toJson()).toList(),
      );
}
