import 'package:flutter/material.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/user_model.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/schedule_store.dart';
import 'package:newtronic_banking/state/transfer_service.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:provider/provider.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/data/utils/greetings.dart';
import 'package:newtronic_banking/presentation/screen/main/account_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/tracker_tab.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/balance_card.dart';
import 'package:newtronic_banking/presentation/screen/qr/qr_actions.dart';
import 'package:newtronic_banking/presentation/screen/transactions/receipt_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transaction_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/presentation/widget/shimmer.dart';

/// Everything the home tab needs, loaded once instead of by three competing
/// `FutureBuilder`s that each re-fetched on every rebuild.
class _HomeData {
  const _HomeData({
    required this.user,
    required this.balances,
    required this.activity,
    required this.people,
  });

  final Users? user;
  final List<Balances> balances;
  final List<Transactions> activity;
  final List<Users> people;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.id});
  static const routeName = '/home-screen';
  final int id;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Tall enough for the card's contents at their largest text scale. Fixed
  /// rather than a fraction of the screen, which overflowed on short devices.
  static const double _carouselHeight = 236;

  /// Leaves the neighbouring cards peeking, so the carousel reads as a stack
  /// you can swipe rather than a single static card.
  static const double _carouselViewport = 0.82;

  late final TabController tabController = TabController(
    length: homeScreenTabbar.length,
    vsync: this,
    initialIndex: 1,
  );
  late final TabController accountTypeController = TabController(
    length: homeScreenContentTabbar.length,
    vsync: this,
  );
  late final PageController cardController =
      PageController(viewportFraction: _carouselViewport);

  late Future<_HomeData> _data;

  /// The most recent successful load, kept so a refresh can leave the current
  /// content on screen instead of blanking it back to skeletons.
  _HomeData? _lastData;

  @override
  void initState() {
    super.initState();
    accountTypeController.addListener(_onAccountTypeChanged);
    _data = _load();
    // Scheduled transfers have no background scheduler behind them; the app
    // opening is when due ones are found and applied.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDueSchedules());
  }

  /// Applies any scheduled transfers that have fallen due, and reports what
  /// happened.
  ///
  /// Silence would be the wrong outcome either way: money moving without a
  /// word is alarming, and a transfer that could not be sent needs saying.
  Future<void> _runDueSchedules() async {
    final schedules = context.read<ScheduleStore>();
    final transfers = context.read<TransferService>();
    if (!schedules.isLoaded) await schedules.load();
    if (!mounted) return;

    final report = await schedules.runDue(
      now: DateTime.now(),
      transfers: transfers,
      userId: widget.id,
    );
    if (!mounted || report.isEmpty) return;

    setState(() => _data = _load());
    final summary = report.summary;
    if (summary == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            report.failed.isEmpty ? null : context.scheme.errorContainer,
      ),
    );
  }

  void _onAccountTypeChanged() {
    if (accountTypeController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    accountTypeController.removeListener(_onAccountTypeChanged);
    tabController.dispose();
    accountTypeController.dispose();
    cardController.dispose();
    super.dispose();
  }

  Future<_HomeData> _load() async {
    final repository = context.read<Repository>();
    final accounts = context.read<AccountStore>();
    final transactions = context.read<TransactionStore>();

    // The stores load once at startup; this only forces a read when the screen
    // is reached before that finished, or after a refresh cleared them.
    if (!accounts.isLoaded) await accounts.load();
    if (!transactions.isLoaded) await transactions.load();

    final data = _HomeData(
      user: repository.findUser(widget.id),
      balances: accounts.accounts,
      activity: transactions.transactions,
      people: repository.readUsers(),
    );
    _lastData = data;
    return data;
  }

  /// Re-reads the data behind the screen from the local store.
  Future<void> _refresh() async {
    await context.read<AccountStore>().load();
    if (!mounted) return;
    await context.read<TransactionStore>().load();
    if (!mounted) return;

    final refreshed = _load();
    // A block body, not an arrow: `setState(() => _data = refreshed)` returns
    // the assigned Future, and the framework asserts that setState callbacks
    // return nothing.
    setState(() {
      _data = refreshed;
    });
    await refreshed;
  }

  String get _accountLabel =>
      homeScreenContentTabbar[accountTypeController.index] == 'Card'
          ? 'Card'
          : 'Account';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.headerBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Insets.md),
                child: _buildTabBar(),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: Radii.sheetTop,
                    color: colors.sheetBackground,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TabBarView(
                    controller: tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const TrackerTab(),
                      _buildHomeTab(context),
                      const EmptyState(
                        animationAsset:
                            'lib/assets/lotties/lottieComingSoon.json',
                        title: 'Portfolio is on the way',
                        message:
                            'Savings goals and investments will live here.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _data,
      builder: (context, snapshot) {
        // Falling back to the last good load is what keeps a pull-to-refresh
        // from wiping the screen while the new data is in flight.
        // Accounts and activity come from the watched stores, not the snapshot,
        // so a transfer made elsewhere is reflected here without a reload.
        final accounts = context.watch<AccountStore>();
        final transactions = context.watch<TransactionStore>();
        final data = snapshot.data ?? _lastData;

        if (data == null) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your accounts',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onActionPressed: _refresh,
            );
          }
          return _buildShimmer();
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: Insets.lg,
          color: context.scheme.primary,
          child: ListView(
            padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.xxl),
            // Always scrollable so the pull gesture works even when the content
            // is shorter than the viewport.
            physics: const AlwaysScrollableScrollPhysics(),
            children: staggeredReveal([
              _buildGreeting(context, data.user),
              const SizedBox(height: Insets.md),
              _buildAccountTypeTabs(),
              _buildCarousel(context, accounts.accounts),
              const SectionHeader(title: 'Favorite Transactions'),
              _buildFavorites(context),
              const SectionHeader(title: 'Recent Activities'),
              _buildActivity(context, transactions.recent()),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.only(top: Insets.lg),
      children: [
        shimmerHeader(context),
        shimmerCard(context),
        const SectionHeader(title: 'Favorite Transactions'),
        shimmerClip(context),
        const SectionHeader(title: 'Recent Activities'),
        shimmerTile(context),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context, Users? user) {
    final colors = context.colors;
    final firstName = (user?.name ?? '').split(' ').first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open profile',
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, ProfileScreen.routeName),
              borderRadius: Radii.pillAll,
              child: ClipRRect(
                borderRadius: Radii.pillAll,
                child: RemoteImage(
                  url: user?.image ?? '',
                  size: 48,
                  fallback: (context) => const ProfilePhotoFallback(size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingsFunction(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.subtleText),
                ),
                Text(
                  firstName.isEmpty ? 'there' : firstName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }

  Widget _buildAccountTypeTabs() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: accountTypeController,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorPadding: const EdgeInsets.only(bottom: Insets.xs),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        tabs: [
          for (final label in homeScreenContentTabbar) Tab(text: label),
        ],
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, List<Balances> balances) {
    if (balances.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.credit_card_off_rounded,
        title: 'No accounts yet',
        message: 'Accounts you open will show up here.',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: context.scaledHeight(_carouselHeight),
          child: PageView.builder(
            controller: cardController,
            itemCount: balances.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final balance = balances[index];
              return Padding(
                padding: const EdgeInsets.only(
                  left: Insets.lg,
                  right: Insets.xs,
                  bottom: Insets.xs,
                ),
                child: Hero(
                  tag: balanceCardHeroTag(balance),
                  flightShuttleBuilder: (_, _, _, _, _) => Material(
                    color: Colors.transparent,
                    child: BalanceCard(
                      balance: balance,
                      label: _accountLabel,
                      showActions: false,
                      animateBalance: false,
                    ),
                  ),
                  child: BalanceCard(
                    balance: balance,
                    label: _accountLabel,
                    onTap: () => _openAccount(balance),
                    onMove: () => _openTransfer(),
                    onQris: () =>
                        showQrActions(context, initialAccount: balance),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.xs),
        Center(
          child: PageDots(controller: cardController, count: balances.length),
        ),
      ],
    );
  }

  void _openAccount(Balances balance) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDetailScreen(
          balance: balance,
          label: _accountLabel,
          userId: widget.id,
        ),
      ),
    );
  }

  /// Reopens a past transfer so it can be read again or shared.
  ///
  /// Only transfers the user made carry the details a receipt needs; the
  /// seeded entries never had one, so those rows do not open.
  void _openReceipt(Transactions transaction) {
    final receipt = transaction.toReceipt(widget.id);
    if (receipt == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(receipt: receipt),
      ),
    );
  }

  void _openTransfer({FavouriteTransfer? favourite}) => Navigator.pushNamed(
        context,
        AddTransactionScreen.routeName,
        arguments: TransferArgs(
          userId: widget.id,
          prefill: favourite == null
              ? null
              : TransferPrefill.fromFavourite(favourite),
        ),
      );

  Widget _buildFavorites(BuildContext context) {
    final colors = context.colors;
    final favourites = context.watch<FavouriteStore>().favourites;

    return SizedBox(
      height: context.scaledHeight(56),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, _) => const SizedBox(width: Insets.xs),
        itemCount: favourites.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FavoriteChip(
              label: 'Transaction',
              isPrimary: true,
              leading: Icon(Icons.add_rounded, color: context.scheme.onPrimary),
              onTap: () => Navigator.pushNamed(
                context,
                TransactionScreen.routeName,
                arguments: widget.id,
              ),
            );
          }

          // Saved recipients, each one tap from a prefilled transfer.
          final favourite = favourites[index - 1];
          return _FavoriteChip(
            label: favourite.recipientName,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: colors.mutedFill,
              child: Text(
                _initialOf(favourite.recipientName),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            onTap: () => _openTransfer(favourite: favourite),
          );
        },
      ),
    );
  }

  Widget _buildActivity(BuildContext context, List<Transactions> activity) {
    if (activity.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.receipt_long_rounded,
        title: 'No activity yet',
        message: 'Your recent transactions will appear here.',
      );
    }

    final visible = activity.take(4).toList();
    return Column(
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.xxs,
            ),
            child: _ActivityTile(
              transaction: item,
              onOpen: () => _openReceipt(item),
            ),
          ),
      ],
    );
  }

  /// First character of [name], or a placeholder when the name is empty.
  ///
  /// `name.split('')[0]` used to throw a `RangeError` on an empty name.
  static String _initialOf(String name) => name.isEmpty ? '?' : name[0];

  Widget _buildTabBar() {
    final colors = context.colors;

    return TabBar(
      controller: tabController,
      padding: const EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        bottom: Insets.md,
      ),
      splashBorderRadius: Radii.pillAll,
      indicator: BoxDecoration(
        borderRadius: Radii.pillAll,
        color: colors.sheetBackground,
      ),
      labelColor: context.scheme.primary,
      unselectedLabelColor: colors.onHeader,
      dividerColor: Colors.transparent,
      tabs: [
        for (final tab in homeScreenTabbar)
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab['icon'] as IconData, size: 18),
                const SizedBox(width: Insets.xxs),
                Flexible(
                  child: Text(
                    tab['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({
    required this.label,
    required this.leading,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;

    return Material(
      color: isPrimary ? scheme.primary : colors.sheetBackground,
      borderRadius: Radii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.pillAll,
        child: Container(
          padding: const EdgeInsets.only(
            left: Insets.xs,
            right: Insets.md,
          ),
          decoration: BoxDecoration(
            borderRadius: Radii.pillAll,
            border: Border.all(
              color: isPrimary ? Colors.transparent : colors.mutedBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 36, height: 36, child: Center(child: leading)),
              const SizedBox(width: Insets.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPrimary ? scheme.onPrimary : scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.transaction, required this.onOpen});

  final Transactions transaction;

  /// Opening the receipt behind this row. Null-tapped rows used to show an ink
  /// ripple and do nothing, which reads as the app having failed to respond.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = transaction.amount;

    return Material(
      color: colors.mutedFill,
      borderRadius: Radii.mdAll,
      child: InkWell(
        // Only a transfer the user made has a receipt behind it; the seeded
        // entries open nothing, and a null handler means no ripple promising
        // otherwise.
        onTap: transaction.isTransfer ? onOpen : null,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: Radii.smAll,
                child: RemoteImage(
                  url: transaction.image,
                  size: 40,
                  fallback: (context) =>
                      InitialFallback(name: transaction.name, size: 40),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formattedTransactionDate(transaction.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.subtleText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.xs),
              // Flexible for the same reason as the history row: at a large
              // text size the amount no longer fits beside the name, and it
              // wraps rather than being cut in half.
              Flexible(
                child: Text(
                  '- ${amount.formattedWithSymbol}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
