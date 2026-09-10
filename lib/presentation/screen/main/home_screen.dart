import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/user_model.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/data/utils/greetings.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transaction_screen.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:newtronic_banking/presentation/widget/shimmer.dart';
import 'package:newtronic_banking/presentation/widget/theme_toggle_button.dart';
import 'package:newtronic_banking/styles/typography.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.id});
  static const routeName = '/home-screen';
  final int id;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Height of the balance card carousel. Fixed rather than a fraction of the
  /// screen so the card contents cannot overflow on a short device.
  static const double _cardCarouselHeight = 248;

  final List<Map<String, String>> transactions = [];

  late TabController tabController;
  late TabController contentController;
  Timer? _shimmerTimer;
  bool isShimmer = true;

  void initTabController() {
    tabController = TabController(
      length: homeScreenTabbar.length,
      vsync: this,
      initialIndex: 1,
    );
    contentController = TabController(
      length: homeScreenContentTabbar.length,
      vsync: this,
    );
  }

  Future<void> getTransaction() async {
    final users = await Repository().getUsers();
    if (!mounted) return;
    setState(() {
      transactions
        ..clear()
        ..add({'name': 'Transaction', 'image': ''})
        ..addAll(users.map((user) => {
              'name': user.name,
              'image': user.image,
            }));
    });
  }

  @override
  void initState() {
    super.initState();
    _shimmerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => isShimmer = false);
    });
    initTabController();
    getTransaction();
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    tabController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.headerBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildTabBar(),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: Radii.sheetTop,
                    color: context.colors.sheetBackground,
                  ),
                  padding: const EdgeInsets.only(top: 24),
                  child: TabBarView(
                    controller: tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(
                      homeScreenTabbar.length,
                      (index) {
                        if (index != 1) return _buildComingSoon(context);
                        return FutureBuilder<Users?>(
                          future: Repository().getUserById(id: widget.id),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || isShimmer) {
                              return _buildShimmer();
                            }
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(snapshot.data!),
                                  _buildContentTabBar(),
                                  _buildContentTabBarView(context),
                                  _customTitle(title: 'Favorite Transactions'),
                                  _customContentTransaction(),
                                  _customTitle(title: 'Recent Activities'),
                                  customRecentActivities(),
                                  customSpaceVertical(24),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Center _buildComingSoon(BuildContext context) {
    return Center(
      child: LottieBuilder.asset(
        'lib/assets/lotties/lottieComingSoon.json',
        width: MediaQuery.of(context).size.width * .5,
        height: MediaQuery.of(context).size.height * .5,
      ),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shimmerHeader(context),
          shimmerCard(context),
          _customTitle(title: 'Favorite Transactions'),
          shimmerClip(context),
          _customTitle(title: 'Recent Activities'),
          shimmerTile(context),
        ],
      ),
    );
  }

  FutureBuilder<List<Transactions>> customRecentActivities() {
    return FutureBuilder<List<Transactions>>(
      future: Repository().getTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final itemCount = data.length > 3 ? 3 : data.length;
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          separatorBuilder: (context, index) => customSpaceVertical(8),
          shrinkWrap: true,
          itemCount: itemCount,
          itemBuilder: (context, listIndex) {
            final activity = data[listIndex];
            // Material, not a coloured Container: a DecoratedBox between a
            // ListTile and its nearest Material hides the tile's ink splashes,
            // and the framework asserts on that arrangement.
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                color: context.colors.cardGradient[1],
                borderRadius: Radii.mdAll,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      imageUrl: activity.image,
                      placeholder: (context, url) =>
                          customText(textValue: _initialOf(activity.name)),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  ),
                  title: customText(
                    textValue: activity.name,
                    textStyle: subHeadline4.copyWith(color: context.colors.onCard),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: customText(
                    textValue: formattedTransactionDate(activity.date),
                    textStyle: bodyText2.copyWith(
                      color: context.colors.onCard,
                    ),
                  ),
                  trailing: customText(
                    textValue: '- Rp ${activity.priceIdr}',
                    textStyle: numeric(bodyText2).copyWith(
                      color: context.colors.onCard,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// First character of [name], or a placeholder when the name is empty.
  ///
  /// `name.split('')[0]` used to throw a `RangeError` on an empty name.
  String _initialOf(String name) => name.isEmpty ? '?' : name[0];

  SizedBox _customContentTransaction() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => customSpaceHorizontal(8),
        itemCount: transactions.length,
        itemBuilder: (context, transactionIndex) {
          final data = transactions[transactionIndex];
          final isNewTransaction = transactionIndex == 0;
          return InkWell(
            onTap: () {
              if (isNewTransaction) {
                Navigator.pushNamed(
                  context,
                  TransactionScreen.routeName,
                  arguments: widget.id,
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.mutedBorder),
                borderRadius: Radii.pillAll,
                color: isNewTransaction
                    ? context.scheme.primary
                    : context.colors.sheetBackground,
              ),
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isNewTransaction)
                    const Padding(
                      padding: EdgeInsets.only(left: Insets.md),
                      child: Icon(Icons.add),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: CachedNetworkImage(
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        imageUrl: data['image'] ?? '',
                        placeholder: (context, url) => Image.asset(
                          'lib/assets/images/profile.jpg',
                          fit: BoxFit.cover,
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  customSpaceHorizontal(8),
                  customText(
                    textValue: data['name'] ?? '',
                    textStyle: bodyText2.copyWith(
                      color: isNewTransaction
                          ? context.scheme.onPrimary
                          : context.scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Padding _customTitle({required String title}) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: customText(textValue: title, textStyle: subHeadline3),
    );
  }

  SizedBox _buildContentTabBarView(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _cardCarouselHeight,
      child: TabBarView(
        controller: contentController,
        children: List.generate(
          contentController.length,
          (tabIndex) => FutureBuilder(
            future: Repository().getBalances(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                separatorBuilder: (context, index) => customSpaceHorizontal(10),
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, cardIndex) {
                  final data = snapshot.data![cardIndex];
                  final cardWidth =
                      (MediaQuery.of(context).size.width * .6).clamp(240.0, 360.0);
                  return Container(
                    width: cardWidth,
                    decoration: BoxDecoration(
                      borderRadius: Radii.mdAll,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: context.colors.cardGradient,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            customText(
                              textValue: tabIndex == 0
                                  ? '${data.cardName} Account'
                                  : '${data.cardName} Card',
                              textStyle: headline4.copyWith(
                                color: context.colors.onCard,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            customSpaceVertical(4),
                            customText(
                              textValue: data.cardNumber,
                              textStyle:
                                  subHeadline5.copyWith(color: context.colors.onCard),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            customText(
                              textValue: 'Balance',
                              textStyle: bodyText1.copyWith(color: context.colors.onCard),
                            ),
                            customSpaceVertical(8),
                            customText(
                              textValue: 'Rp ${data.balance.trim()}',
                              textStyle: headline4.copyWith(color: context.colors.onCard),
                            ),
                            customSpaceVertical(8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                2,
                                (index) => customButton(
                                  buttonWidth: cardWidth * .42,
                                  buttonOnTap: () {},
                                  buttonText: index == 0 ? 'MOVE' : 'QRIS',
                                  buttonFirstGradientColor:
                                      context.colors.onCard,
                                  buttonSecondGradientColor:
                                      context.colors.onCard,
                                  buttonPadding: const EdgeInsets.all(8),
                                  buttonBorderRadius: BorderRadius.circular(8),
                                  buttonLeftIcon: Icon(
                                    index == 0
                                        ? Icons.wallet_rounded
                                        : Icons.qr_code_rounded,
                                    // The card action sits on `onCard` (white)
                                    // in both themes, so it takes the darkest
                                    // gradient tone rather than `primary`,
                                    // which in dark mode is a light blue that
                                    // would leave ~1.9:1 against white.
                                    color: context.colors.cardGradient.first,
                                  ),
                                  isButtonIcon: true,
                                  textStyles: subHeadline5.copyWith(
                                    color: context.colors.cardGradient.first,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        customText(
                          textValue: 'Exp ${data.expiryDate}',
                          textStyle: bodyText2.copyWith(color: context.colors.onCard),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  TabBar _buildContentTabBar() {
    return TabBar(
      controller: contentController,
      indicatorPadding: const EdgeInsets.only(bottom: 8),
      indicatorSize: TabBarIndicatorSize.label,
      isScrollable: true,
      labelColor: context.scheme.onSurface,
      unselectedLabelColor: context.colors.subtleText,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tabAlignment: TabAlignment.start,
      onTap: (_) => setState(() {}),
      tabs: List.generate(
        homeScreenContentTabbar.length,
        (index) => Tab(text: homeScreenContentTabbar[index]),
      ),
    );
  }

  Padding _buildHeader(Users user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: CachedNetworkImage(
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              imageUrl: user.image,
              placeholder: (context, url) => Image.asset(
                'lib/assets/images/profile.jpg',
                fit: BoxFit.cover,
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: customText(
                    textValue: greetingsFunction(),
                    textStyle: subHeadline5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: customText(
                    textValue: user.name,
                    textStyle: headline4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ThemeToggleButton(),
              IconButton(
                onPressed: () {},
                tooltip: 'Notifications',
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.mutedFill,
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: context.scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: tabController,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      splashBorderRadius: BorderRadius.circular(40),
      indicator: BoxDecoration(
        borderRadius: Radii.pillAll,
        color: context.colors.sheetBackground,
      ),
      labelColor: context.scheme.primary,
      unselectedLabelColor: context.colors.onHeader,
      tabs: List.generate(
        homeScreenTabbar.length,
        (index) => Tab(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(homeScreenTabbar[index]['icon'] as IconData),
              customSpaceHorizontal(4),
              Flexible(
                child: customText(
                  textValue: homeScreenTabbar[index]['name'] as String,
                  textStyle: subHeadline5,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
