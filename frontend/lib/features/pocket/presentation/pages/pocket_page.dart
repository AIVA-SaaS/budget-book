import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';

class PocketPage extends StatelessWidget {
  const PocketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('머니 포켓'),
        actions: [
          IconButton(
            onPressed: () => context.push('/pockets/distribute'),
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: '월급 분배',
          ),
          IconButton(
            onPressed: () => context.push('/pocket-transfers'),
            icon: const Icon(Icons.swap_horiz),
            tooltip: '포켓 이체',
          ),
        ],
      ),
      body: BlocConsumer<PocketBloc, PocketState>(
        listener: (context, state) {
          if (state is PocketError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PocketLoaded && state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            PocketInitial() || PocketLoading() =>
              const Center(child: CircularProgressIndicator()),
            PocketLoaded(pockets: final pockets) =>
              _buildContent(context, pockets, state),
            PocketError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPocket(context),
        tooltip: '포켓 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<MoneyPocket> pockets,
    PocketLoaded state,
  ) {
    if (pockets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '등록된 포켓이 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '+ 버튼을 눌러 첫 포켓을 만드세요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total balance card
        _TotalBalanceCard(totalBalance: state.totalBalance),
        const SizedBox(height: 16),
        // Pocket cards
        ...pockets.map((pocket) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PocketCard(
                pocket: pocket,
                onTap: () => _showEditPocket(context, pocket),
                onLongPress: () => _showDeleteDialog(context, pocket),
              ),
            )),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('포켓을 불러오지 못했습니다'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<PocketBloc>().add(const LoadPockets());
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _showAddPocket(BuildContext context) {
    final bloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        onSubmit: (name, type, allocatedAmount, icon, color) {
          bloc.add(CreatePocket(
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
          ));
        },
      ),
    );
  }

  void _showEditPocket(BuildContext context, MoneyPocket pocket) {
    final bloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        pocket: pocket,
        onSubmit: (name, type, allocatedAmount, icon, color) {
          bloc.add(UpdatePocket(
            id: pocket.id,
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
          ));
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(
      BuildContext context, MoneyPocket pocket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('포켓 삭제'),
        content: Text("'${pocket.name}' 포켓을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PocketBloc>().add(DeletePocket(pocket.id));
    }
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final int totalBalance;

  const _TotalBalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final isPositive = totalBalance >= 0;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '진짜 남은 돈',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatter.format(totalBalance)}원',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PocketCard extends StatelessWidget {
  final MoneyPocket pocket;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PocketCard({
    required this.pocket,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final color = _parseColor(pocket.color);
    final isPositive = pocket.balance >= 0;

    final typeLabel = switch (pocket.type) {
      'LIVING' => '생활비',
      'FIXED' => '고정지출',
      'CARD_PENDING' => '카드미결제',
      'SAVINGS' => '저축',
      'CUSTOM' => '직접입력',
      _ => pocket.type,
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  _resolveIcon(pocket.icon),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pocket.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '할당: ${formatter.format(pocket.allocatedAmount)}원',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatter.format(pocket.balance)}원',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _resolveIcon(String? iconName) {
    if (iconName == null) return Icons.account_balance_wallet;
    const iconMap = <String, IconData>{
      'home': Icons.home,
      'restaurant': Icons.restaurant,
      'shopping_cart': Icons.shopping_cart,
      'directions_bus': Icons.directions_bus,
      'savings': Icons.savings,
      'payments': Icons.payments,
      'account_balance': Icons.account_balance,
      'card_giftcard': Icons.card_giftcard,
    };
    return iconMap[iconName] ?? Icons.account_balance_wallet;
  }
}
