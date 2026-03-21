import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_state.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_transfer_form_sheet.dart';

class PocketTransferPage extends StatelessWidget {
  const PocketTransferPage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포켓 이체 내역'),
      ),
      body: BlocConsumer<PocketTransferBloc, PocketTransferState>(
        listener: (context, state) {
          if (state is PocketTransferError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is PocketTransferLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            PocketTransferInitial() ||
            PocketTransferLoading() =>
              const Center(child: CircularProgressIndicator()),
            PocketTransferLoaded(transfers: final transfers) =>
              _buildContent(context, transfers),
            PocketTransferError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransfer(context),
        tooltip: '이체 추가',
        child: const Icon(Icons.swap_horiz),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<PocketTransfer> transfers) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '이체 내역이 없습니다',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _buildTransferTile(context, transfer);
      },
    );
  }

  Widget _buildTransferTile(BuildContext context, PocketTransfer transfer) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.15),
        child: const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
      ),
      title: Text(
        '${transfer.fromPocket.name} -> ${transfer.toPocket.name}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        '${transfer.transferDate}${transfer.description != null ? ' - ${transfer.description}' : ''}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
      trailing: Text(
        '${CurrencyFormatter.format(transfer.amount)}원',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('이체 내역을 불러오지 못했습니다'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context
                  .read<PocketTransferBloc>()
                  .add(const LoadPocketTransfers());
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _showAddTransfer(BuildContext context) {
    final pocketState = context.read<PocketBloc>().state;
    final pockets =
        pocketState is PocketLoaded ? pocketState.pockets : [];

    if (pockets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이체하려면 최소 2개의 포켓이 필요합니다')),
      );
      return;
    }

    final transferBloc = context.read<PocketTransferBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketTransferFormSheet(
        pockets: pockets.cast(),
        onSubmit: (fromPocketId, toPocketId, amount, description,
            transferDate) {
          transferBloc.add(CreatePocketTransfer(
            fromPocketId: fromPocketId,
            toPocketId: toPocketId,
            amount: amount,
            description: description,
            transferDate: transferDate,
          ));
        },
      ),
    );
  }
}
