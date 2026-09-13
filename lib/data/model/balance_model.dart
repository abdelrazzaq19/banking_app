import 'package:newtronic_banking/data/model/money.dart';

class Balance {
  Balance({required this.balances});

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
        balances:
            List<Balances>.from(json['data'].map((x) => Balances.fromJson(x))),
      );

  final List<Balances> balances;

  Map<String, dynamic> toJson() => {
        'data': List<dynamic>.from(balances.map((x) => x.toJson())),
      };
}

/// One account or card the user holds.
class Balances {
  const Balances({
    required this.cardName,
    required this.cardNumber,
    required this.balance,
    required this.expiryDate,
    required this.id,
  });

  factory Balances.fromJson(Map<String, dynamic> json) => Balances(
        cardName: json['card_name'] as String,
        cardNumber: json['card_number'] as String,
        // Tolerates both the number the seed data now stores and the older
        // `"5,000,000 "` string, so a store written by a previous build still
        // reads back.
        balance: Money.parse(json['balance']),
        expiryDate: json['expiry_Date'] as String,
        id: json['id'] as String,
      );

  final String cardName;
  final String cardNumber;
  final Money balance;
  final String expiryDate;
  final String id;

  Balances copyWith({Money? balance}) => Balances(
        cardName: cardName,
        cardNumber: cardNumber,
        balance: balance ?? this.balance,
        expiryDate: expiryDate,
        id: id,
      );

  Map<String, dynamic> toJson() => {
        'card_name': cardName,
        'card_number': cardNumber,
        'balance': balance.toJson(),
        'expiry_Date': expiryDate,
        'id': id,
      };
}
