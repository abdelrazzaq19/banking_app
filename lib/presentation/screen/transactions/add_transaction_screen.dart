import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/bank_model.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, required this.userId});
  static const routeName = '/add-transaction';

  final int userId;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  static const int _accountNumberLength = 12;
  static const int _minTransfer = 10000;
  static const int _maxTransfer = 500000000;

  final PageController pageController = PageController();
  final TextEditingController bankNumberController = TextEditingController();
  final TextEditingController recipientNameController = TextEditingController();
  final TextEditingController bankSearchController = TextEditingController();
  final TextEditingController accountSearchController = TextEditingController();
  final TextEditingController transferController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  List<Banks> banks = [];
  List<Banks> filteredBanks = [];
  List<Balances> balances = [];
  List<Balances> filteredBalances = [];

  /// The destination bank, chosen from the picker. Null until one is selected —
  /// previously this was a list that other code indexed at `[0]` unguarded.
  Banks? selectedBank;

  /// The account the money leaves from.
  Balances? selectedAccount;

  late TabController tabController;
  int pageIndex = 0;
  String accountNumberErrorText = '';
  String recipientErrorText = '';
  String transferErrorText = '';
  String noteErrorText = '';
  String transactionType = transactionTypes.first;

  void initializeTabController() {
    tabController =
        TabController(length: addTransactionScreenTabbar.length, vsync: this);
  }

  Future<void> fetchData() async {
    final loadedBanks = await Repository().getBanks();
    final loadedBalances = await Repository().getBalances();
    if (!mounted) return;

    // The filtered copies must be taken *after* the data arrives. Copying them
    // up front left both pickers permanently empty.
    setState(() {
      banks = loadedBanks;
      filteredBanks = List.of(loadedBanks);
      balances = loadedBalances;
      filteredBalances = List.of(loadedBalances);
      selectedAccount = loadedBalances.isEmpty ? null : loadedBalances.first;
    });
  }

  @override
  void initState() {
    super.initState();
    initializeTabController();
    fetchData();
  }

  @override
  void dispose() {
    pageController.dispose();
    bankNumberController.dispose();
    recipientNameController.dispose();
    bankSearchController.dispose();
    accountSearchController.dispose();
    transferController.dispose();
    noteController.dispose();
    tabController.dispose();
    super.dispose();
  }

  bool get isRecipientStepComplete =>
      selectedBank != null &&
      recipientNameController.text.trim().isNotEmpty &&
      bankNumberController.text.length == _accountNumberLength &&
      accountNumberErrorText.isEmpty &&
      recipientErrorText.isEmpty;

  bool get isAmountStepComplete =>
      transferController.text.isNotEmpty &&
      transferErrorText.isEmpty &&
      noteErrorText.isEmpty &&
      selectedAccount != null;

  bool get isCurrentStepComplete =>
      pageIndex == 0 ? isRecipientStepComplete : isAmountStepComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(context),
              customSpaceVertical(16),
              _buildContent(),
              _buildButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Column _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (pageIndex == 1) {
              pageController.animateToPage(
                0,
                duration: Motion.medium,
                curve: Motion.move,
              );
            } else {
              Navigator.pop(context);
            }
          },
          child: Icon(
            Icons.arrow_back_ios_rounded,
            size: 24,
            color: context.scheme.primary,
          ),
        ),
        customSpaceVertical(16),
        customText(
          textValue: 'New Transfer',
          textStyle: headline1.copyWith(color: context.scheme.onSurface),
        ),
      ],
    );
  }

  Expanded _buildContent() {
    return Expanded(
      child: PageView.builder(
        controller: pageController,
        onPageChanged: (value) => setState(() => pageIndex = value),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        itemBuilder: (context, page) {
          switch (page) {
            case 0:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildTabBar(),
                  customSpaceVertical(16),
                  _buildTabBarView(context),
                ],
              );
            default:
              return _buildAmountStep(context);
          }
        },
      ),
    );
  }

  Widget _buildAmountStep(BuildContext context) {
    final balanceLabel = selectedAccount?.cardName ?? '-';
    final balanceValue = selectedAccount?.balance.trim() ?? '0';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildWalletTiles(),
          customSpaceVertical(32),
          TextField(
            controller: transferController,
            style: numeric(headline5).copyWith(color: context.scheme.onSurface),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) =>
                setState(() => transferErrorText = _validateTransfer(value)),
            decoration: InputDecoration(
              errorText:
                  transferErrorText.isEmpty ? null : transferErrorText,
              filled: false,
              hintText: 'Nominal Transfer',
              hintStyle: bodyText2.copyWith(color: context.colors.subtleText),
              prefix: customText(
                textValue: 'Rp ',
                textStyle: headline5.copyWith(color: context.scheme.onSurface),
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
            ),
          ),
          customSpaceVertical(4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: customText(
                  textValue: 'Saldo $balanceLabel',
                  textStyle: subHeadline5.copyWith(
                    color: context.colors.subtleText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              customText(
                textValue: 'Rp $balanceValue',
                textStyle: numeric(subHeadline5).copyWith(
                  color: context.colors.subtleText,
                ),
              ),
            ],
          ),
          customSpaceVertical(16),
          DropdownButtonFormField<String>(
            initialValue: transactionType,
            decoration: InputDecoration(
              filled: false,
              label: customText(
                textValue: 'Transaction Type',
                textStyle: bodyText2.copyWith(color: context.colors.subtleText),
              ),
              suffixText: formatRupiahWithSymbol(adminFeeIdr),
              suffixStyle: bodyText2.copyWith(color: context.colors.success),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
            ),
            items: transactionTypes
                .map((type) => DropdownMenuItem<String>(
                      value: type,
                      child: customText(
                        textValue: type,
                        textStyle: subHeadline5.copyWith(
                          color: context.scheme.onSurface,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (value) => setState(
                () => transactionType = value ?? transactionTypes.first),
          ),
          customSpaceVertical(16),
          TextField(
            controller: noteController,
            style: numeric(headline5).copyWith(color: context.scheme.onSurface),
            onChanged: (value) => setState(() => noteErrorText = value.length > 20
                ? 'Notes maximum length is 20 characters'
                : ''),
            decoration: InputDecoration(
              errorText: noteErrorText.isEmpty ? null : noteErrorText,
              filled: false,
              hintText: 'Note (Optional)',
              hintStyle: bodyText2.copyWith(color: context.colors.subtleText),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _validateTransfer(String value) {
    if (value.isEmpty) return 'Transfer is empty';
    final amount = int.tryParse(value);
    if (amount == null) return 'Invalid input';
    if (amount < _minTransfer || amount > _maxTransfer) {
      return 'Transfer must be between '
          '${formatRupiahWithSymbol(_minTransfer)} and '
          '${formatRupiahWithSymbol(_maxTransfer)}';
    }
    return '';
  }

  Widget _buildWalletTiles() {
    final destination = selectedBank;
    return Column(
      children: [
        ListTile(
          onTap: showAccountPicker,
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.asset(
              'lib/assets/images/newtronic.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          title: customText(
            textValue: selectedAccount?.cardName ?? 'Select account',
            textStyle: headline5.copyWith(color: context.scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: customText(
            textValue: selectedAccount?.cardNumber ?? '-',
            textStyle: bodyText2.copyWith(color: context.colors.subtleText),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        customSpaceVertical(8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: destination == null
                ? Image.asset(
                    'lib/assets/images/profile.jpg',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    imageUrl: destination.image,
                    placeholder: (context, url) => Image.asset(
                      'lib/assets/images/profile.jpg',
                      fit: BoxFit.cover,
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
          ),
          title: customText(
            textValue: recipientNameController.text.trim().isEmpty
                ? 'Recipient'
                : recipientNameController.text.trim(),
            textStyle: headline5.copyWith(color: context.scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: customText(
            // `substring(0, 4)` / `substring(8, 12)` used to throw whenever the
            // number was shorter than twelve digits.
            textValue: '${destination?.name ?? '-'}\n'
                '${maskedBankNumber(bankNumberController.text)}',
            textStyle: bodyText2.copyWith(color: context.colors.subtleText),
          ),
        ),
      ],
    );
  }

  Container _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.pillAll,
        color: context.colors.mutedFill,
      ),
      padding: const EdgeInsets.all(Insets.xxs),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          borderRadius: Radii.pillAll,
          color: context.scheme.surface,
        ),
        labelColor: context.scheme.onSurface,
        unselectedLabelColor: context.colors.subtleText,
        tabs: List.generate(
          addTransactionScreenTabbar.length,
          (index) => Tab(text: addTransactionScreenTabbar[index]),
        ),
      ),
    );
  }

  Expanded _buildTabBarView(BuildContext context) {
    return Expanded(
      child: TabBarView(
        controller: tabController,
        children: List.generate(
          tabController.length,
          (index) => index == 0
              ? _buildRecipientForm()
              : _buildNoFavoritesYet(context),
        ),
      ),
    );
  }

  Widget _buildRecipientForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // An InputDecorator rather than a disabled TextField: the field is a
          // button, so it needs no controller (one built in `build` would leak
          // a new instance every frame) and stays hit-testable.
          InkWell(
            key: const ValueKey('bank-name-field'),
            onTap: showBankPicker,
            child: InputDecorator(
              decoration: InputDecoration(
                filled: false,
                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.colors.mutedBorder),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.colors.mutedBorder),
                ),
              ),
              child: customText(
                textValue: selectedBank?.name ?? 'Bank Name',
                textStyle: selectedBank == null
                    ? bodyText2.copyWith(color: context.colors.subtleText)
                    : subHeadline5.copyWith(color: context.scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          customSpaceVertical(16),
          TextField(
            controller: bankNumberController,
            style: numeric(subHeadline5).copyWith(color: context.scheme.onSurface),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_accountNumberLength),
            ],
            onChanged: (value) => setState(() {
              accountNumberErrorText = value.length == _accountNumberLength
                  ? ''
                  : 'Account number must be $_accountNumberLength digits';
            }),
            decoration: InputDecoration(
              errorText: accountNumberErrorText.isEmpty
                  ? null
                  : accountNumberErrorText,
              filled: false,
              hintText: 'Account Number',
              hintStyle: bodyText2.copyWith(color: context.colors.subtleText),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
            ),
          ),
          customSpaceVertical(16),
          TextField(
            controller: recipientNameController,
            style: subHeadline5.copyWith(color: context.scheme.onSurface),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() {
              recipientErrorText =
                  value.trim().isEmpty ? 'Recipient name is required' : '';
            }),
            decoration: InputDecoration(
              errorText:
                  recipientErrorText.isEmpty ? null : recipientErrorText,
              filled: false,
              hintText: 'Recipient Name',
              hintStyle: bodyText2.copyWith(color: context.colors.subtleText),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colors.mutedBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFavoritesYet(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LottieBuilder.asset(
            'lib/assets/lotties/lottieAsk.json',
            width: MediaQuery.of(context).size.width / 2.5,
          ),
          customSpaceVertical(16),
          customText(
            textValue: 'You don\'t have any favorite transactions yet',
            textStyle: subHeadline4.copyWith(color: context.colors.subtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InkWell _buildButton(BuildContext context) {
    final isEnabled = isCurrentStepComplete;
    return customButton(
      buttonOnTap: () {
        if (pageIndex == 0) {
          if (!isRecipientStepComplete) return;
          pageController.animateToPage(
            1,
            duration: Motion.medium,
            curve: Motion.move,
          );
          return;
        }
        if (!isAmountStepComplete) return;
        _confirmTransfer(context);
      },
      buttonText: pageIndex == 0 ? 'Next' : 'Confirm',
      buttonWidth: MediaQuery.of(context).size.width,
      buttonFirstGradientColor:
          isEnabled ? context.scheme.primary : context.colors.mutedBorder,
      buttonSecondGradientColor:
          isEnabled ? context.colors.accent : context.colors.mutedBorder,
      textColor:
          isEnabled ? context.scheme.onPrimary : context.colors.subtleText,
    );
  }

  void _confirmTransfer(BuildContext context) {
    final bank = selectedBank;
    final account = selectedAccount;
    final nominal = int.tryParse(transferController.text);
    if (bank == null || account == null || nominal == null) return;

    customDialogWithButton(
      context,
      dialogTextValue: 'Are you sure want to transfer '
          '${formatRupiahWithSymbol(nominal)}?',
      dialogAction: () {
        Navigator.pop(context);
        final receipt = TransferReceipt(
          userId: widget.userId,
          recipientName: recipientNameController.text.trim(),
          bankName: bank.name,
          bankImage: bank.image,
          accountNumber: bankNumberController.text,
          sourceAccountName: account.cardName,
          nominal: nominal,
          transactionType: transactionType,
          reference: _generateReference(),
          createdAt: DateTime.now(),
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
        showSuccessDialog(
          context,
          message: 'Transfer Success',
          onAction: () => Navigator.pushReplacementNamed(
            context,
            StatusTransactionScreen.routeName,
            arguments: receipt,
          ),
        );
      },
    );
  }

  /// A 16-digit reference, grouped for display. Previously every receipt showed
  /// the same hardcoded `1696 2200 4022 5002`.
  String _generateReference() {
    final random = Random();
    final digits = StringBuffer(
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    while (digits.length < 16) {
      digits.write(random.nextInt(10));
    }
    return formattedBankNumber(digits.toString().substring(0, 16));
  }

  Future<void> showAccountPicker() {
    accountSearchController.clear();
    filteredBalances = List.of(balances);
    return _showPickerSheet(
      title: 'Select Account',
      searchController: accountSearchController,
      onSearch: (query) => filteredBalances = balances
          .where((account) =>
              account.cardName.toLowerCase().contains(query.toLowerCase()) ||
              account.cardNumber.toLowerCase().contains(query.toLowerCase()))
          .toList(),
      itemCount: () => filteredBalances.length,
      itemBuilder: (context, index) {
        final account = filteredBalances[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.asset(
              'lib/assets/images/newtronic.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          title: customText(
            textValue: account.cardName,
            textStyle: headline5.copyWith(color: context.scheme.onSurface),
          ),
          subtitle: customText(
            textValue: account.cardNumber,
            textStyle: numeric(bodyText2).copyWith(
              color: context.colors.subtleText,
            ),
          ),
          onTap: () {
            setState(() => selectedAccount = account);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> showBankPicker() {
    bankSearchController.clear();
    filteredBanks = List.of(banks);
    return _showPickerSheet(
      title: 'Select Bank',
      searchController: bankSearchController,
      onSearch: (query) => filteredBanks = banks
          .where((bank) =>
              bank.name.toLowerCase().contains(query.toLowerCase()))
          .toList(),
      itemCount: () => filteredBanks.length,
      itemBuilder: (context, index) {
        final bank = filteredBanks[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: CachedNetworkImage(
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              imageUrl: bank.image,
              placeholder: (context, url) => Image.asset(
                'lib/assets/images/profile.jpg',
                fit: BoxFit.cover,
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          title: customText(
            textValue: bank.name,
            textStyle: headline5.copyWith(color: context.scheme.onSurface),
          ),
          onTap: () {
            setState(() => selectedBank = bank);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// One searchable bottom sheet used by both pickers.
  ///
  /// The two copies this replaced had diverged: the account one filtered into a
  /// scratch list it never rendered, and gated selection behind that list being
  /// non-empty, so no account could ever be chosen.
  Future<void> _showPickerSheet({
    required String title,
    required TextEditingController searchController,
    required void Function(String query) onSearch,
    required int Function() itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      isDismissible: true,
      builder: (sheetContext) => StatefulBuilder(
        // Material rather than a coloured Container: a DecoratedBox between the
        // ListTiles and their nearest Material swallows their ink splashes, and
        // the framework asserts on it.
        builder: (sheetContext, setSheetState) => Material(
          color: sheetContext.scheme.surface,
          borderRadius: Radii.mdAll,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * .7,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 80,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: sheetContext.colors.mutedBorder,
                    ),
                  ),
                ),
                customSpaceVertical(16),
                customText(
                  textValue: title,
                  textStyle: headline5.copyWith(
                    color: sheetContext.scheme.onSurface,
                  ),
                ),
                customSpaceVertical(16),
                customTextField(
                  sheetContext,
                  controller: searchController,
                  hintText: 'Search',
                  errorText: '',
                  prefixIcon: Icons.search_rounded,
                  isFilled: true,
                  onChanged: (query) => setSheetState(() => onSearch(query)),
                ),
                customSpaceVertical(16),
                Expanded(
                  child: itemCount() == 0
                      ? Center(
                          child: customText(
                            textValue: '"${searchController.text}" not found',
                            textStyle: subHeadline5.copyWith(
                              color: sheetContext.colors.subtleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.vertical,
                          separatorBuilder: (context, index) =>
                              customSpaceVertical(8),
                          itemCount: itemCount(),
                          itemBuilder: itemBuilder,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
