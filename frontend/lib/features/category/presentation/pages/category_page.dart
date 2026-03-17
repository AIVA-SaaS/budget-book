import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/presentation/widgets/category_form_sheet.dart';
import 'package:budget_book/features/category/presentation/widgets/category_list_tile.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('카테고리 관리'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '지출'),
              Tab(text: '수입'),
            ],
          ),
        ),
        body: BlocConsumer<CategoryBloc, CategoryState>(
          listener: (context, state) {
            if (state is CategoryError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is CategoryLoaded &&
                state.operationError != null) {
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
              CategoryInitial() || CategoryLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              CategoryLoaded(
                expenseCategories: final expenses,
                incomeCategories: final incomes,
              ) =>
                _buildTabContent(context, expenses, incomes),
              CategoryError() => _buildError(context),
            };
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddCategory(context),
          tooltip: '카테고리 추가',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    List<Category> expenses,
    List<Category> incomes,
  ) {
    return TabBarView(
      children: [
        _buildCategoryList(context, expenses, 'EXPENSE'),
        _buildCategoryList(context, incomes, 'INCOME'),
      ],
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    List<Category> categories,
    String type,
  ) {
    if (categories.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.category,
        title: '카테고리가 없습니다',
        subtitle: type == 'EXPENSE' ? '지출 카테고리가 없습니다' : '수입 카테고리가 없습니다',
        actionLabel: '카테고리 추가',
        onAction: () => _showAddCategory(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return CategoryListTile(
          category: category,
          onEdit: () => _showEditCategory(context, category),
          onDelete: category.isDefault
              ? null
              : () => _showDeleteDialog(context, category),
        );
      },
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '카테고리를 불러오지 못했습니다',
      onRetry: () {
        context.read<CategoryBloc>().add(const LoadCategories());
      },
      showHomeButton: true,
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
        content: Text("'${category.name}' 카테고리를 삭제하시겠습니까?\n이 카테고리를 사용하는 거래의 카테고리가 해제됩니다."),
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
