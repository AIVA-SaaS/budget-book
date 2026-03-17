import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/presentation/widgets/category_form_sheet.dart';
import 'package:budget_book/features/category/presentation/widgets/category_list_tile.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

class AssetManagementPage extends StatelessWidget {
  const AssetManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('자산 관리'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: '카테고리'),
                  Tab(text: '결제수단'),
                  Tab(text: '포켓'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _CategoryTab(),
                _PaymentMethodTab(),
                _PocketTab(),
              ],
            ),
            floatingActionButton: _buildFab(context),
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return ListenableBuilder(
      listenable: DefaultTabController.of(context),
      builder: (context, _) {
        return FloatingActionButton(
          onPressed: () {
            final currentIndex = DefaultTabController.of(context).index;
            switch (currentIndex) {
              case 0:
                _showAddCategory(context);
              case 1:
                _showAddPaymentMethod(context);
              case 2:
                _showAddPocket(context);
            }
          },
          tooltip: '추가',
          child: const Icon(Icons.add),
        );
      },
    );
  }

  void _showAddCategory(BuildContext context) {
    final bloc = context.read<CategoryBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        onSubmit: (name, type, icon, color, groupId) {
          bloc.add(CreateCategory(
            name: name,
            type: type,
            icon: icon,
            color: color,
            groupId: groupId,
          ));
        },
      ),
    );
  }

  void _showAddPaymentMethod(BuildContext context) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
            ));
          },
        ),
      ),
    );
  }

  void _showAddPocket(BuildContext context) {
    final bloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        onSubmit:
            (name, type, allocatedAmount, icon, color, goalAmount, targetDate) {
          bloc.add(CreatePocket(
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoryBloc, CategoryState>(
      listener: (context, state) {
        if (state is CategoryLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! CategoryLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final expenses = state.expenseCategories;
        final incomes = state.incomeCategories;

        if (expenses.isEmpty && incomes.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.category,
            title: '카테고리가 없습니다',
            subtitle: '+ 버튼을 눌러 카테고리를 추가하세요',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (expenses.isNotEmpty) ...[
              const _SectionHeader(title: '지출'),
              ...expenses.map((c) => CategoryListTile(
                    category: c,
                    onEdit: () => _showEditCategory(context, c),
                    onDelete: c.isDefault
                        ? null
                        : () => _showDeleteDialog(context, c),
                  )),
            ],
            if (incomes.isNotEmpty) ...[
              const _SectionHeader(title: '수입'),
              ...incomes.map((c) => CategoryListTile(
                    category: c,
                    onEdit: () => _showEditCategory(context, c),
                    onDelete: c.isDefault
                        ? null
                        : () => _showDeleteDialog(context, c),
                  )),
            ],
          ],
        );
      },
    );
  }

  void _showEditCategory(BuildContext context, Category category) {
    final bloc = context.read<CategoryBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        category: category,
        onSubmit: (name, type, icon, color, groupId) {
          bloc.add(UpdateCategory(
            id: category.id,
            name: name,
            icon: icon,
            color: color,
            groupId: groupId,
          ));
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
            "'${category.name}' 카테고리를 삭제하시겠습니까?\n이 카테고리를 사용하는 거래의 카테고리가 해제됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CategoryBloc>().add(DeleteCategory(category.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTab extends StatelessWidget {
  const _PaymentMethodTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
      listener: (context, state) {
        if (state is PaymentMethodLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! PaymentMethodLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final methods = state.paymentMethods;

        if (methods.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.payment,
            title: '결제수단이 없습니다',
            subtitle: '+ 버튼을 눌러 결제수단을 추가하세요',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: methods.length,
          itemBuilder: (context, index) =>
              _buildPaymentMethodTile(context, methods[index]),
        );
      },
    );
  }

  Widget _buildPaymentMethodTile(BuildContext context, PaymentMethod method) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getTypeColor(method.type).withValues(alpha: 0.15),
        child: Icon(
          _getTypeIcon(method.type),
          color: _getTypeColor(method.type),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(method.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _buildTypeBadge(context, method.type),
          if (!method.isActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '비활성',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: method.isCredit
          ? Text(
              '결제일: ${method.settlementDay ?? '-'}일, 마감일: ${method.closingDay ?? '-'}일',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            )
          : method.isDefault
              ? Text(
                  '기본 결제수단',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                )
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: method.isActive,
            onChanged: (value) {
              context.read<PaymentMethodBloc>().add(
                    UpdatePaymentMethod(id: method.id, isActive: value),
                  );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') {
                _showEditPaymentMethod(context, method);
              } else if (action == 'delete') {
                _showDeleteDialog(context, method);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('수정'),
                  ],
                ),
              ),
              if (!method.isDefault)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text('삭제',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String type) {
    final label = switch (type) {
      'CASH' => '현금',
      'DEBIT' => '체크',
      'CREDIT' => '신용',
      _ => type,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getTypeColor(type),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    return switch (type) {
      'CASH' => Icons.money,
      'DEBIT' => Icons.credit_card,
      'CREDIT' => Icons.account_balance,
      _ => Icons.payment,
    };
  }

  Color _getTypeColor(String type) {
    return switch (type) {
      'CASH' => Colors.green,
      'DEBIT' => Colors.blue,
      'CREDIT' => Colors.deepPurple,
      _ => Colors.grey,
    };
  }

  void _showEditPaymentMethod(BuildContext context, PaymentMethod method) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          paymentMethod: method,
          onSubmit: (name, type, settlementDay, closingDay) {
            bloc.add(UpdatePaymentMethod(
              id: method.id,
              name: name,
              settlementDay: settlementDay,
              closingDay: closingDay,
            ));
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, PaymentMethod method) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('결제수단 삭제'),
        content: Text(
            "'${method.name}' 결제수단을 삭제하시겠습니까?\n이 결제수단을 사용한 거래 기록은 유지됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<PaymentMethodBloc>()
                  .add(DeletePaymentMethod(method.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _PocketTab extends StatelessWidget {
  const _PocketTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PocketBloc, PocketState>(
      listener: (context, state) {
        if (state is PocketLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! PocketLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final pockets = state.pockets;

        if (pockets.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.savings,
            title: '포켓이 없습니다',
            subtitle: '+ 버튼을 눌러 포켓을 추가하세요',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pockets.length,
          itemBuilder: (context, index) =>
              _buildPocketTile(context, pockets[index]),
        );
      },
    );
  }

  Widget _buildPocketTile(BuildContext context, MoneyPocket pocket) {
    final formatter = NumberFormat('#,###');
    final color = _parseColor(pocket.color);
    final typeLabel = switch (pocket.type) {
      'LIVING' => '생활비',
      'FIXED' => '고정지출',
      'CARD_PENDING' => '카드미결제',
      'SAVINGS' => '저축',
      'CUSTOM' => '직접입력',
      _ => pocket.type,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            _resolveIcon(pocket.icon),
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(pocket.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        subtitle: Text(
          '잔액: ${formatter.format(pocket.balance)}원 / 할당: ${formatter.format(pocket.allocatedAmount)}원',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _showEditPocket(context, pocket);
            } else if (action == 'delete') {
              _showDeleteDialog(context, pocket);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('수정'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text('삭제',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
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
        onSubmit:
            (name, type, allocatedAmount, icon, color, goalAmount, targetDate) {
          bloc.add(UpdatePocket(
            id: pocket.id,
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, MoneyPocket pocket) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('포켓 삭제'),
        content: Text("'${pocket.name}' 포켓을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<PocketBloc>().add(DeletePocket(pocket.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
