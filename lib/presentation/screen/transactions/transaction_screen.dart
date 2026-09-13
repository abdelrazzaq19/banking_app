import 'package:flutter/material.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/scheduled_transfer.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/receipt_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/schedule_sheet.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/schedule_store.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:provider/provider.dart';

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
  late final TabController tabController =
      TabController(length: transactionScreenTabbar.length, vsync: this);

  String _query = '';

  @override
  void dispose() {
    searchController.dispose();
    tabController.dispose();
    super.dispose();
  }

  void _startTransfer({FavouriteTransfer? favourite}) => Navigator.pushNamed(
        context,
        AddTransactionScreen.routeName,
        arguments: TransferArgs(
          userId: widget.userId,
          prefill: favourite == null
              ? null
              : TransferPrefill.fromFavourite(favourite),
        ),
      );

  Future<void> _scheduleFrom(FavouriteTransfer favourite) async {
    final accounts = context.read<AccountStore>().accounts;
    final created = await showScheduleSheet(
      context: context,
      favourite: favourite,
      accounts: accounts,
    );
    if (created == null || !mounted) return;

    await context.read<ScheduleStore>().add(created);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${created.frequency.label} transfer to '
            '${created.recipientName} scheduled'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = context.watch<TransactionStore>();
    final results = store.search(_query);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: context.scheme.primary,
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: Insets.xs)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startTransfer,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transaction', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: searchController,
              hintText: 'Search by payee, bank or amount',
              semanticLabel: 'Search transactions',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              suffix: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: Insets.md),
            Container(
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
                  for (final label in transactionScreenTabbar) Tab(text: label),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _buildHistory(context, results, store.transactions.isEmpty),
                  _buildFavourites(context),
                  _buildSchedules(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(
    BuildContext context,
    List<Transactions> results,
    bool historyIsEmpty,
  ) {
    if (historyIsEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No transactions yet',
        message: 'Transfers you make will be listed here.',
        actionLabel: 'New Transaction',
        onActionPressed: _startTransfer,
      );
    }

    // A search that matches nothing is a different situation from an empty
    // history, and says so.
    if (results.isEmpty) {
      return EmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: 'Nothing matches "$_query"',
        message: 'Try a payee, a bank name, or an amount.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Insets.xxxl),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.xs),
      itemBuilder: (context, index) => _HistoryTile(
        transaction: results[index],
        query: _query,
        onOpen: () => _openReceipt(results[index]),
      ),
    );
  }

  /// Reopens a past transfer so it can be read again or shared.
  ///
  /// Only transfers the user made have a receipt; the seeded history entries
  /// never had one, so those rows simply do not open.
  void _openReceipt(Transactions transaction) {
    final receipt = transaction.toReceipt(widget.userId);
    if (receipt == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(receipt: receipt),
      ),
    );
  }

  Widget _buildFavourites(BuildContext context) {
    final favourites = context.watch<FavouriteStore>().favourites;

    if (favourites.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No favourites yet',
        message: 'Save a transfer as a favourite and it will appear here for '
            'one-tap reuse.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Insets.xxxl),
      itemCount: favourites.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.xs),
      itemBuilder: (context, index) {
        final favourite = favourites[index];
        return _FavouriteTile(
          favourite: favourite,
          onSend: () => _startTransfer(favourite: favourite),
          onSchedule: () => _scheduleFrom(favourite),
          onRemove: () => context.read<FavouriteStore>().remove(favourite.id),
        );
      },
    );
  }

  Widget _buildSchedules(BuildContext context) {
    final store = context.watch<ScheduleStore>();

    if (store.isEmpty) {
      return const EmptyState(
        icon: Icons.event_repeat_rounded,
        title: 'No scheduled transfers',
        message: 'Open a favourite and choose Repeat to set one up. Scheduled '
            'transfers run when you next open the app on or after the due '
            'date.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Insets.xxxl),
      itemCount: store.schedules.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.xs),
      itemBuilder: (context, index) {
        final schedule = store.schedules[index];
        return _ScheduleTile(
          schedule: schedule,
          onTogglePause: () => store.setPaused(schedule.id, !schedule.isPaused),
          onRemove: () => store.remove(schedule.id),
        );
      },
    );
  }
}

class _FavouriteTile extends StatelessWidget {
  const _FavouriteTile({
    required this.favourite,
    required this.onSend,
    required this.onSchedule,
    required this.onRemove,
  });

  final FavouriteTransfer favourite;
  final VoidCallback onSend;
  final VoidCallback onSchedule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.mutedFill,
      borderRadius: Radii.mdAll,
      child: InkWell(
        onTap: onSend,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.mutedBorder,
                child: Text(
                  favourite.recipientName.isEmpty
                      ? '?'
                      : favourite.recipientName[0],
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favourite.recipientName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${favourite.bankName} · '
                      '${maskedBankNumber(favourite.accountNumber)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.subtleText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Favourite options',
                onSelected: (value) {
                  if (value == 'schedule') onSchedule();
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'schedule',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_repeat_rounded),
                      title: Text('Repeat this transfer'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Remove favourite'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onTogglePause,
    required this.onRemove,
  });

  final ScheduledTransfer schedule;
  final VoidCallback onTogglePause;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failure = schedule.lastFailure;

    return Material(
      color: colors.mutedFill,
      borderRadius: Radii.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  schedule.isPaused
                      ? Icons.pause_circle_outline_rounded
                      : Icons.event_repeat_rounded,
                  color: schedule.isPaused
                      ? colors.subtleText
                      : context.scheme.primary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.recipientName,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        schedule.isPaused
                            ? '${schedule.frequency.label} · paused'
                            : '${schedule.frequency.label} · next '
                                '${formattedTransactionDate(schedule.nextDueAt)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.subtleText),
                      ),
                    ],
                  ),
                ),
                Text(
                  schedule.amount.formattedWithSymbol,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Schedule options',
                  onSelected: (value) {
                    if (value == 'pause') onTogglePause();
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pause',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          schedule.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        title: Text(schedule.isPaused ? 'Resume' : 'Pause'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // A failed run stays visible on the card rather than disappearing
            // with the launch that produced it.
            if (failure != null) ...[
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: context.scheme.error,
                  ),
                  const SizedBox(width: Insets.xxs),
                  Expanded(
                    child: Text(
                      'Last run: $failure',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.scheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.transaction,
    required this.query,
    required this.onOpen,
  });

  final Transactions transaction;
  final String query;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = transaction.isTransfer
        ? '${transaction.bankName} · '
            '${maskedBankNumber(transaction.accountNumber ?? '')}'
        : formattedTransactionDate(transaction.date);

    return Material(
      color: colors.mutedFill,
      borderRadius: Radii.mdAll,
      child: InkWell(
        // Only a real transfer has a receipt to open.
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
                    HighlightedText(
                      text: transaction.name,
                      query: query,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    HighlightedText(
                      text: subtitle,
                      query: query,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.subtleText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.xs),
              // Flexible, because at a large text size the amount and the date
              // together are wider than what is left of a phone after the logo
              // and the payee name. The amount is allowed to wrap rather than
              // ellipsize — half a figure is worse than a figure on two lines
              // — while the date, which is repeated in the receipt, is the one
              // that gets cut.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- ${transaction.amount.formattedWithSymbol}',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (transaction.isTransfer)
                      Text(
                        formattedTransactionDate(transaction.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.subtleText),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
