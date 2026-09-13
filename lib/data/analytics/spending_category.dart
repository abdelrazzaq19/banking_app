import 'package:flutter/material.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';

/// What a payment was for.
///
/// Deliberately a short, fixed list. Past roughly seven classes that all carry
/// meaning, adjacent colours blur and the breakdown stops being readable — so
/// anything unrecognised folds into [other] rather than growing the list.
enum SpendingCategory {
  subscriptions,
  food,
  shopping,
  transport,
  bills,
  transfers,
  other;

  String get label => switch (this) {
        SpendingCategory.subscriptions => 'Subscriptions',
        SpendingCategory.food => 'Food & drink',
        SpendingCategory.shopping => 'Shopping',
        SpendingCategory.transport => 'Transport',
        SpendingCategory.bills => 'Bills & utilities',
        SpendingCategory.transfers => 'Transfers',
        SpendingCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        SpendingCategory.subscriptions => Icons.subscriptions_rounded,
        SpendingCategory.food => Icons.restaurant_rounded,
        SpendingCategory.shopping => Icons.shopping_bag_rounded,
        SpendingCategory.transport => Icons.directions_car_rounded,
        SpendingCategory.bills => Icons.receipt_rounded,
        SpendingCategory.transfers => Icons.swap_horiz_rounded,
        SpendingCategory.other => Icons.category_rounded,
      };

  static SpendingCategory fromName(String? name) =>
      SpendingCategory.values.firstWhere(
        (category) => category.name == name,
        orElse: () => SpendingCategory.other,
      );
}

/// Guesses a category from the payee.
///
/// Checked in order, most specific first: "Amazon Prime" is a subscription, not
/// shopping, and only reaches the shopping keywords if the subscription ones
/// miss. A guess is always overridable — see `SpendingStore.setCategory`.
abstract final class CategoryGuesser {
  static const Map<SpendingCategory, List<String>> _keywords = {
    SpendingCategory.subscriptions: [
      'netflix', 'spotify', 'hulu', 'disney', 'hbo', 'prime', 'youtube',
      'apple tv', 'icloud', 'subscription', 'vidio', 'viu',
    ],
    SpendingCategory.food: [
      'resto', 'restaurant', 'cafe', 'coffee', 'kopi', 'food', 'makan',
      'warung', 'bakery', 'mcd', 'kfc', 'starbucks',
    ],
    SpendingCategory.transport: [
      'grab', 'gojek', 'uber', 'transport', 'fuel', 'shell', 'pertamina',
      'parkir', 'toll', 'bensin', 'train', 'kereta',
    ],
    SpendingCategory.bills: [
      'pln', 'listrik', 'water', 'pdam', 'internet', 'telkom', 'indihome',
      'bill', 'tagihan', 'bpjs', 'insurance', 'asuransi',
    ],
    SpendingCategory.shopping: [
      'tokopedia', 'shopee', 'lazada', 'bukalapak', 'amazon', 'shop',
      'store', 'mart', 'mall', 'belanja', 'ikea', 'uniqlo',
    ],
  };

  /// The category [transaction] falls into when nobody has said otherwise.
  static SpendingCategory guess(Transactions transaction) {
    // A transfer the user made is a transfer, whatever the payee is called.
    if (transaction.isTransfer) return SpendingCategory.transfers;

    final name = transaction.name.toLowerCase();
    for (final entry in _keywords.entries) {
      if (entry.value.any(name.contains)) return entry.key;
    }
    return SpendingCategory.other;
  }
}
