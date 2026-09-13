import 'package:flutter/material.dart';

/// Flat admin fee charged on every transfer, in whole rupiah.
const int adminFeeIdr = 2500;

/// Transfer types offered on the transfer form.
const List<String> transactionTypes = ['BI-FAST', 'Online Transfer', 'RTGS'];

final List<Map<String, dynamic>> homeScreenTabbar = [
  {'name': 'Tracker', 'icon': Icons.pie_chart},
  {'name': 'Home', 'icon': Icons.home_rounded},
  {'name': 'Porto', 'icon': Icons.badge_rounded},
];

const List<String> homeScreenContentTabbar = ['Account', 'Card'];

const List<String> transactionScreenTabbar = [
  'History',
  'Favorites',
  'Autodebit',
];
const List<String> addTransactionScreenTabbar = ['Accounts', 'Favorites'];
