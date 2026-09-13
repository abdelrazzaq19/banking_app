import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/bank_model.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/transfer_service.dart';
import 'package:provider/provider.dart';
import 'package:newtronic_banking/data/utils/currency_input_formatter.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/transfer_summary_sheet.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.userId,
    this.prefill,
  });
  static const routeName = '/add-transaction';

  final int userId;

  /// When arriving from a saved recipient or a scanned code, the form starts
  /// filled in.
  final TransferPrefill? prefill;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  /// Indonesian account numbers run 10 to 16 digits depending on the bank, so
  /// a single fixed length rejected valid numbers — including the 16-digit
  /// ones this app's own cards carry, which is what a payment code generated
  /// from an account contains.
  static const int _minAccountNumber = 10;
  static const int _maxAccountNumber = 16;

  static bool _isAccountNumberComplete(String digits) =>
      digits.length >= _minAccountNumber &&
      digits.length <= _maxAccountNumber;
  static const int _minTransfer = 10000;
  static const int _maxTransfer = 500000000;
  static const int _noteMaxLength = 20;

  final PageController pageController = PageController();
  final TextEditingController bankNumberController = TextEditingController();
  final TextEditingController recipientNameController = TextEditingController();
  final TextEditingController transferController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  List<Banks> banks = [];
  List<Balances> balances = [];

  /// The destination bank, chosen from the picker. Null until one is selected —
  /// previously this was a list that other code indexed at `[0]` unguarded.
  Banks? selectedBank;

  /// The account the money leaves from.
  Balances? selectedAccount;

  /// Set when the bank list could not be read at all.
  bool _loadFailed = false;

  /// A bank a scanned code named that this app does not carry.
  ///
  /// Kept so the form can say which bank was asked for. Leaving the field
  /// blank with no explanation would read as a bug in the scan.
  String? unknownBankName;

  late final TabController tabController =
      TabController(length: addTransactionScreenTabbar.length, vsync: this);

  int pageIndex = 0;
  bool _isSubmitting = false;
  String accountNumberErrorText = '';
  String recipientErrorText = '';
  String transferErrorText = '';
  String noteErrorText = '';
  String transactionType = transactionTypes.first;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    pageController.dispose();
    bankNumberController.dispose();
    recipientNameController.dispose();
    transferController.dispose();
    noteController.dispose();
    tabController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    // Both lookups happen before the first await, so no BuildContext is held
    // across an async gap.
    final repository = context.read<Repository>();
    final accountStore = context.read<AccountStore>();

    List<Banks> loadedBanks;
    try {
      loadedBanks = await repository.getBanks();
      if (!accountStore.isLoaded) await accountStore.load();
    } catch (error, stackTrace) {
      // A form with no banks and no explanation looks like a bug in the
      // picker. Saying the list failed at least points somewhere.
      debugPrint('Transfer form could not load its data: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    if (!mounted) return;

    final loadedBalances = accountStore.accounts;
    setState(() {
      _loadFailed = false;
      banks = loadedBanks;
      balances = loadedBalances;
      selectedAccount = loadedBalances.isEmpty ? null : loadedBalances.first;
      _applyPrefill(loadedBanks);
    });
  }

  /// Fills the form in from a saved recipient or a scanned code.
  ///
  /// Stops on the first step rather than skipping to the amount: a prefilled
  /// form is a suggestion, and the details are worth a glance before money
  /// moves. That matters more for a code than for a favourite — the payee
  /// details came from something the user pointed a camera at.
  void _applyPrefill(List<Banks> loadedBanks) {
    final prefill = widget.prefill;
    if (prefill == null) return;
    _fillFrom(prefill, loadedBanks);
  }

  /// Puts one set of recipient details into the fields.
  void _fillFrom(TransferPrefill prefill, List<Banks> loadedBanks) {
    for (final bank in loadedBanks) {
      if (bank.name == prefill.bankName) {
        selectedBank = bank;
        break;
      }
    }
    // A code can name a bank this app does not carry. The rest of the details
    // are still shown, and the bank field stays empty so the mismatch is
    // visible instead of being papered over with the wrong bank.
    unknownBankName = selectedBank == null ? prefill.bankName : null;

    bankNumberController.text = prefill.accountNumber;
    recipientNameController.text = prefill.recipientName;
    if (prefill.amount != null) {
      transferController.text = prefill.amount!.formatted;
    }
    if (prefill.note != null) noteController.text = prefill.note!;
    if (prefill.transactionType != null &&
        transactionTypes.contains(prefill.transactionType)) {
      transactionType = prefill.transactionType!;
    }
  }

  // ------------------------------------------------------------------ state

  /// Whole rupiah currently entered, or null when the field is empty.
  int? get _amount => parseRupiah(transferController.text);

  int get _sourceBalance => selectedAccount?.balance.rupiah ?? 0;

  /// What the source account would hold once this transfer and its fee clear.
  int get _balanceAfterTransfer =>
      _sourceBalance - (_amount ?? 0) - adminFeeIdr;

  bool get _hasEnoughBalance => _amount == null || _balanceAfterTransfer >= 0;

  bool get isRecipientStepComplete =>
      selectedBank != null &&
      recipientNameController.text.trim().isNotEmpty &&
      _isAccountNumberComplete(bankNumberController.text) &&
      accountNumberErrorText.isEmpty &&
      recipientErrorText.isEmpty;

  bool get isAmountStepComplete =>
      _amount != null &&
      transferErrorText.isEmpty &&
      noteErrorText.isEmpty &&
      selectedAccount != null &&
      _hasEnoughBalance;

  bool get isCurrentStepComplete =>
      pageIndex == 0 ? isRecipientStepComplete : isAmountStepComplete;

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: (value) => setState(() => pageIndex = value),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  itemBuilder: (context, page) => page == 0
                      ? _buildRecipientStep(context)
                      : _buildAmountStep(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: Insets.sm,
                  bottom: Insets.md,
                ),
                child: _buildPrimaryAction(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _goBack,
              tooltip: pageIndex == 1 ? 'Back to recipient' : 'Close',
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              color: context.scheme.primary,
            ),
            const Spacer(),
            // Which of the two steps the user is on, so the flow has a
            // visible sense of progress.
            _StepIndicator(step: pageIndex, total: 2),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Text(
          pageIndex == 0 ? 'New Transfer' : 'How much?',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: Insets.md),
      ],
    );
  }

  void _goBack() {
    if (pageIndex == 1) {
      pageController.animateToPage(
        0,
        duration: Motion.medium,
        curve: Motion.move,
      );
      return;
    }
    Navigator.pop(context);
  }

  // ------------------------------------------------------------ step one

  Widget _buildRecipientStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(context),
        const SizedBox(height: Insets.md),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _buildRecipientForm(context),
              _buildFavourites(context),
            ],
          ),
        ),
      ],
    );
  }

  /// The saved recipients, as a way into the form beside typing one in.
  ///
  /// This tab used to be a fixed "No favourites yet" panel that said the same
  /// thing whether the user had none or twenty — favourites became real in
  /// the history screen and this second entry point was never connected.
  Widget _buildFavourites(BuildContext context) {
    final favourites = context.watch<FavouriteStore>().favourites;

    if (favourites.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No favourites yet',
        message: 'Transfers you save will show up here for one-tap reuse.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.xs),
      itemBuilder: (context, index) {
        final favourite = favourites[index];
        return Material(
          color: context.colors.mutedFill,
          borderRadius: Radii.mdAll,
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
            leading: ClipRRect(
              borderRadius: Radii.smAll,
              child: RemoteImage(
                url: favourite.bankImage,
                size: 40,
                fallback: (context) => const BankLogoFallback(size: 40),
              ),
            ),
            title: Text(
              favourite.recipientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${favourite.bankName} · '
              '${maskedBankNumber(favourite.accountNumber)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _useFavourite(favourite),
          ),
        );
      },
    );
  }

  /// Fills the form from a saved recipient and returns to it.
  ///
  /// Fills in place rather than pushing a second copy of this screen: the
  /// user is already on the form, and stacking another would leave the old
  /// one behind the new.
  void _useFavourite(FavouriteTransfer favourite) {
    setState(() => _fillFrom(TransferPrefill.fromFavourite(favourite), banks));
    tabController.animateTo(0);
  }

  Widget _buildTabBar(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.pillAll,
        color: colors.mutedFill,
      ),
      padding: const EdgeInsets.all(Insets.xxs),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          borderRadius: Radii.pillAll,
          color: context.scheme.surface,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          for (final label in addTransactionScreenTabbar) Tab(text: label),
        ],
      ),
    );
  }

  Widget _buildRecipientForm(BuildContext context) {
    if (_loadFailed) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the bank list',
        message: 'Without it there is nothing to transfer to. Try again.',
        actionLabel: 'Retry',
        onActionPressed: fetchData,
      );
    }

    final bank = selectedBank;

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      children: staggeredReveal([
        _PickerField(
          label: 'Bank',
          value: bank?.name,
          placeholder: 'Select a bank',
          fieldKey: const ValueKey('bank-name-field'),
          leading: bank == null
              ? null
              : ClipRRect(
                  borderRadius: Radii.pillAll,
                  child: RemoteImage(
                    url: bank.image,
                    size: 32,
                    fallback: (context) => const BankLogoFallback(size: 32),
                  ),
                ),
          onTap: showBankPicker,
        ),
        if (unknownBankName case final String named)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              'The code asked for $named, which is not in the list. Pick the '
              'closest match before sending.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.scheme.error,
                  ),
            ),
          ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: bankNumberController,
          hintText: 'Account Number',
          semanticLabel: 'Recipient account number',
          useTabularFigures: true,
          keyboardType: TextInputType.number,
          errorText: accountNumberErrorText,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_maxAccountNumber),
          ],
          helperText: '$_minAccountNumber to $_maxAccountNumber digits',
          onChanged: (value) => setState(() {
            accountNumberErrorText =
                value.isEmpty || _isAccountNumberComplete(value)
                    ? ''
                    : 'Account number must be $_minAccountNumber to '
                        '$_maxAccountNumber digits';
          }),
        ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: recipientNameController,
          hintText: 'Recipient Name',
          semanticLabel: 'Recipient name',
          textCapitalization: TextCapitalization.words,
          errorText: recipientErrorText,
          onChanged: (value) => setState(() {
            recipientErrorText = '';
          }),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------ step two

  Widget _buildAmountStep(BuildContext context) {
    final colors = context.colors;
    final account = selectedAccount;

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      children: staggeredReveal([
        _PickerField(
          label: 'From',
          value: account == null
              ? null
              : '${account.cardName} · ${account.cardNumber}',
          placeholder: 'Select an account',
          leading: ClipRRect(
            borderRadius: Radii.pillAll,
            child: Image.asset(
              'lib/assets/images/newtronic.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          onTap: showAccountPicker,
        ),
        const SizedBox(height: Insets.md),
        _RecipientSummary(
          bank: selectedBank,
          accountNumber: bankNumberController.text,
          name: recipientNameController.text.trim(),
        ),
        const SizedBox(height: Insets.xl),
        AppTextField(
          controller: transferController,
          hintText: 'Nominal Transfer',
          semanticLabel: 'Transfer amount in rupiah',
          style: AppFieldStyle.underlined,
          useTabularFigures: true,
          keyboardType: TextInputType.number,
          errorText: transferErrorText,
          inputFormatters: const [ThousandsSeparatorInputFormatter()],
          onChanged: (_) => setState(() {
            transferErrorText = _validateTransfer();
          }),
        ),
        const SizedBox(height: Insets.sm),
        _BalancePreview(
          accountName: account?.cardName ?? '-',
          balance: _sourceBalance,
          remaining: _balanceAfterTransfer,
          showRemaining: _amount != null,
          isShort: !_hasEnoughBalance,
        ),
        const SizedBox(height: Insets.lg),
        DropdownButtonFormField<String>(
          initialValue: transactionType,
          // Without this the dropdown sizes to its content and overflows a
          // phone-width row once the label and value are both present.
          isExpanded: true,
          decoration: InputDecoration(
            filled: false,
            labelText: 'Transaction Type',
            // The fee lives under the field rather than in a suffix, which had
            // no room beside the value on a narrow screen.
            helperText: 'Admin fee ${formatRupiahWithSymbol(adminFeeIdr)}',
            helperStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.subtleText),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.mutedBorder),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.mutedBorder),
            ),
          ),
          items: [
            for (final type in transactionTypes)
              DropdownMenuItem<String>(value: type, child: Text(type)),
          ],
          onChanged: (value) => setState(
            () => transactionType = value ?? transactionTypes.first,
          ),
        ),
        const SizedBox(height: Insets.lg),
        AppTextField(
          controller: noteController,
          hintText: 'Note (Optional)',
          semanticLabel: 'Transfer note',
          style: AppFieldStyle.underlined,
          errorText: noteErrorText,
          inputFormatters: [
            LengthLimitingTextInputFormatter(_noteMaxLength),
          ],
          helperText: '${noteController.text.length}/$_noteMaxLength',
          onChanged: (_) => setState(() => noteErrorText = ''),
        ),
      ]),
    );
  }

  String _validateTransfer() {
    final amount = _amount;
    if (amount == null) return '';
    if (amount < _minTransfer) {
      return 'Transfer must be between '
          '${formatRupiahWithSymbol(_minTransfer)} and '
          '${formatRupiahWithSymbol(_maxTransfer)}';
    }
    if (amount > _maxTransfer) {
      return 'Transfer must be between '
          '${formatRupiahWithSymbol(_minTransfer)} and '
          '${formatRupiahWithSymbol(_maxTransfer)}';
    }
    if (!_hasEnoughBalance) {
      return 'Not enough balance for this transfer plus the '
          '${formatRupiahWithSymbol(adminFeeIdr)} fee';
    }
    return '';
  }

  // ----------------------------------------------------------------- action

  Widget _buildPrimaryAction(BuildContext context) {
    return AppButton(
      label: pageIndex == 0 ? 'Next' : 'Continue',
      isLoading: _isSubmitting,
      onPressed: isCurrentStepComplete
          ? () {
              if (pageIndex == 0) {
                pageController.animateToPage(
                  1,
                  duration: Motion.medium,
                  curve: Motion.move,
                );
                return;
              }
              _confirmTransfer();
            }
          : null,
    );
  }

  Future<void> _confirmTransfer() async {
    final bank = selectedBank;
    final account = selectedAccount;
    final nominal = _amount;
    if (bank == null || account == null || nominal == null) return;

    final receipt = TransferReceipt(
      userId: widget.userId,
      recipientName: recipientNameController.text.trim(),
      bankName: bank.name,
      bankImage: bank.image,
      accountNumber: bankNumberController.text,
      sourceAccountId: account.id,
      sourceAccountName: account.cardName,
      nominal: Money(nominal),
      transactionType: transactionType,
      reference: _generateReference(),
      createdAt: DateTime.now(),
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );

    // A summary sheet rather than a yes/no dialog: the last thing before money
    // moves should show exactly what is about to happen.
    final confirmed = await showTransferSummarySheet(
      context: context,
      receipt: receipt,
      balanceAfter: Money(_balanceAfterTransfer),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    // The money moves here, before the receipt screen — so the receipt is
    // evidence of something that happened rather than a promise.
    final outcome = await context.read<TransferService>().execute(receipt);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!outcome.isSuccess) {
      showErrorDialog(context, message: outcome.failure!.message);
      return;
    }

    showSuccessDialog(
      context,
      message: 'Transfer Success',
      onDismissed: () => Navigator.pushReplacementNamed(
        context,
        StatusTransactionScreen.routeName,
        arguments: receipt,
      ),
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

  // ---------------------------------------------------------------- pickers

  Future<void> showBankPicker() async {
    final picked = await showPickerSheet<Banks>(
      context: context,
      title: 'Select Bank',
      searchHint: 'Search banks',
      items: banks,
      matches: (bank, query) =>
          bank.name.toLowerCase().contains(query.toLowerCase()),
      itemBuilder: (context, bank, query) => ListTile(
        leading: ClipRRect(
          borderRadius: Radii.pillAll,
          child: RemoteImage(
            url: bank.image,
            size: 40,
            fallback: (context) => const BankLogoFallback(size: 40),
          ),
        ),
        title: HighlightedText(
          text: bank.name,
          query: query,
          maxLines: 2,
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => selectedBank = picked);
  }

  Future<void> showAccountPicker() async {
    final picked = await showPickerSheet<Balances>(
      context: context,
      title: 'Select Account',
      searchHint: 'Search accounts',
      items: balances,
      matches: (account, query) {
        final needle = query.toLowerCase();
        return account.cardName.toLowerCase().contains(needle) ||
            account.cardNumber.toLowerCase().contains(needle);
      },
      itemBuilder: (context, account, query) => ListTile(
        leading: ClipRRect(
          borderRadius: Radii.pillAll,
          child: Image.asset(
            'lib/assets/images/newtronic.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        title: HighlightedText(text: account.cardName, query: query),
        subtitle: HighlightedText(
          text: account.cardNumber,
          query: query,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.colors.subtleText),
        ),
        trailing: Text(
          account.balance.formattedWithSymbol,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      selectedAccount = picked;
      // The new account may not cover what was already typed.
      transferErrorText = _validateTransfer();
    });
  }
}

/// "Step 1 of 2", as a pair of bars.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < total; index++)
              AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.move,
                margin: const EdgeInsets.only(left: Insets.xxs),
                width: index == step ? 24 : 12,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: index <= step
                      ? context.scheme.primary
                      : context.colors.mutedBorder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.leading,
    this.fieldKey,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? leading;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = value != null && value!.isNotEmpty;

    return Semantics(
      button: true,
      label: '$label: ${hasValue ? value : placeholder}',
      child: ExcludeSemantics(
        child: Material(
          key: fieldKey,
          color: colors.mutedFill,
          borderRadius: Radii.mdAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.mdAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Insets.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.subtleText),
                        ),
                        Text(
                          hasValue ? value! : placeholder,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: hasValue
                                    ? context.scheme.onSurface
                                    : colors.subtleText,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colors.subtleText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who the money is going to, carried onto the amount step so the figure is
/// never entered without the recipient in view.
class _RecipientSummary extends StatelessWidget {
  const _RecipientSummary({
    required this.bank,
    required this.accountNumber,
    required this.name,
  });

  final Banks? bank;
  final String accountNumber;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Icon(Icons.arrow_downward_rounded, size: 18, color: colors.subtleText),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: colors.subtleText),
              ),
              Text(
                name.isEmpty ? 'Recipient' : name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${bank?.name ?? '-'} · ${maskedBankNumber(accountNumber)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.subtleText),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Current balance, and what would be left once the transfer clears.
class _BalancePreview extends StatelessWidget {
  const _BalancePreview({
    required this.accountName,
    required this.balance,
    required this.remaining,
    required this.showRemaining,
    required this.isShort,
  });

  final String accountName;
  final int balance;
  final int remaining;
  final bool showRemaining;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        _row(
          context,
          label: 'Balance $accountName',
          value: formatRupiahWithSymbol(balance),
          color: colors.subtleText,
        ),
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.move,
          alignment: Alignment.topCenter,
          child: showRemaining
              ? Padding(
                  padding: const EdgeInsets.only(top: Insets.xxs),
                  child: _row(
                    context,
                    label: 'After transfer',
                    value: formatRupiahWithSymbol(remaining),
                    color: isShort ? context.scheme.error : colors.success,
                    emphasise: true,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool emphasise = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Text(
          value,
          style: (emphasise ? textTheme.titleSmall : textTheme.bodySmall)
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
