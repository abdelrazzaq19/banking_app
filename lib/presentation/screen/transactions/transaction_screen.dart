import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:newtronic_banking/presentation/widget/theme_toggle_button.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, required this.userId});
  static const routeName = '/transaction';

  /// The signed-in user, carried through so downstream screens can return to
  /// the right account instead of a hardcoded one.
  final int userId;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen>
    with TickerProviderStateMixin {
  final TextEditingController searchController = TextEditingController();
  late TabController tabController;
  Timer? _loadingTimer;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => isLoading = false);
    });
    tabController =
        TabController(length: transactionScreenTabbar.length, vsync: this);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    searchController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios),
          color: context.scheme.primary,
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: Insets.xs)],
      ),
      body: isLoading
          ? Center(
              child: LottieBuilder.asset(
                'lib/assets/lotties/lottieLoading.json',
                width: MediaQuery.of(context).size.width * .5,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  customText(
                    textValue: 'Transaction',
                    textStyle: headline1.copyWith(
                      color: context.scheme.onSurface,
                    ),
                  ),
                  customSpaceVertical(16),
                  customTextField(
                    context,
                    controller: searchController,
                    hintText: 'Search',
                    errorText: '',
                    prefixIcon: Icons.search_rounded,
                    isFilled: true,
                  ),
                  customSpaceVertical(16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: Radii.pillAll,
                      color: context.colors.mutedFill,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: tabController,
                      indicator: BoxDecoration(
                        borderRadius: Radii.pillAll,
                        color: context.scheme.surface,
                      ),
                      labelColor: context.scheme.onSurface,
                      unselectedLabelColor: context.colors.subtleText,
                      tabs: List.generate(
                        transactionScreenTabbar.length,
                        (index) => Tab(text: transactionScreenTabbar[index]),
                      ),
                    ),
                  ),
                  customSpaceVertical(16),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      children: List.generate(
                        transactionScreenTabbar.length,
                        (index) => _buildEmptyState(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(Insets.xs),
                  child: Icon(
                    Icons.people_rounded,
                    color: context.scheme.onPrimary,
                  ),
                ),
                customSpaceHorizontal(8),
                customText(
                  textValue: 'Multiple Transaction',
                  textStyle: subHeadline4.copyWith(
                    color: context.scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: Column(
              children: [
                SvgPicture.asset(
                  'lib/assets/images/search.svg',
                  height: 140,
                ),
                customSpaceVertical(16),
                customText(
                  textValue:
                      'Transaction now! There is an interesting promo for you',
                  textStyle: bodyText2.copyWith(
                    color: context.colors.subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                customSpaceVertical(32),
                customButton(
                  buttonOnTap: () => Navigator.pushNamed(
                    context,
                    AddTransactionScreen.routeName,
                    arguments: widget.userId,
                  ),
                  buttonText: 'New Transaction',
                  buttonWidth: MediaQuery.of(context).size.width * .6,
                  buttonFirstGradientColor: context.scheme.primary,
                  buttonSecondGradientColor: context.colors.accent,
                  textColor: context.scheme.onPrimary,
                  buttonBorderRadius: Radii.pillAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
