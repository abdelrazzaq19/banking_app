import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flat admin fee charged on every transfer, in whole rupiah.
const int adminFeeIdr = 2500;

/// Transfer types offered on the transfer form.
const List<String> transactionTypes = ['BI-FAST', 'Online Transfer', 'RTGS'];

final List<Map<String, dynamic>> signUpTextFieldProperties = [
  {
    'hintText': 'Full Name',
    'icon': Icons.person_2_rounded,
    'type': TextInputType.name,
    'suffixIcon': false,
    'inputFormatters': <TextInputFormatter>[],
  },
  {
    'hintText': 'Username',
    'icon': Icons.verified_user_rounded,
    'type': TextInputType.name,
    'suffixIcon': false,
    'inputFormatters': <TextInputFormatter>[
      FilteringTextInputFormatter.deny(RegExp(r'\s'))
    ],
  },
  {
    'hintText': 'Email',
    'icon': Icons.email_rounded,
    'type': TextInputType.emailAddress,
    'suffixIcon': false,
    'inputFormatters': <TextInputFormatter>[
      FilteringTextInputFormatter.deny(RegExp(r'\s'))
    ],
  },
  {
    'hintText': 'Password',
    'icon': Icons.lock_rounded,
    'type': TextInputType.visiblePassword,
    'suffixIcon': true,
    'inputFormatters': <TextInputFormatter>[],
  },
  {
    'hintText': 'Confirm Password',
    'icon': Icons.lock_rounded,
    'type': TextInputType.visiblePassword,
    'suffixIcon': true,
    'inputFormatters': <TextInputFormatter>[],
  },
];

final List<Map<String, dynamic>> logInTextFieldProperties = [
  {
    'hintText': 'Email or Username',
    'icon': Icons.email_rounded,
    'type': TextInputType.name,
    'suffixIcon': false,
    'inputFormatters': <TextInputFormatter>[
      FilteringTextInputFormatter.deny(RegExp(r'\s'))
    ],
  },
  {
    'hintText': 'Password',
    'icon': Icons.lock_rounded,
    'type': TextInputType.visiblePassword,
    'suffixIcon': true,
    'inputFormatters': <TextInputFormatter>[],
  },
];

final List<Map<String, dynamic>> homeScreenTabbar = [
  {'name': 'Tracker', 'icon': Icons.pie_chart},
  {'name': 'Home', 'icon': Icons.home_rounded},
  {'name': 'Porto', 'icon': Icons.badge_rounded},
];

const List<String> homeScreenContentTabbar = ['Account', 'Card'];

const List<String> transactionScreenTabbar = [
  'Accounts',
  'Favorites',
  'Autodebit',
];
const List<String> addTransactionScreenTabbar = ['Accounts', 'Favorites'];
