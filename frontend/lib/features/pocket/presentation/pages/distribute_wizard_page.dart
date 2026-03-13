import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';

class DistributeWizardPage extends StatefulWidget {
  const DistributeWizardPage({super.key});

  @override
  State<DistributeWizardPage> createState() => _DistributeWizardPageState();
}

class _DistributeWizardPageState extends State<DistributeWizardPage> {
  int _currentStep = 0;
  final _totalAmountController = TextEditingController();
  final Map<String, TextEditingController> _allocationControllers = {};
  final _formatter = NumberFormat('#,###');
  bool _isSubmitting = false;

  int get _totalAmount =>
      int.tryParse(_totalAmountController.text.replaceAll(',', '')) ?? 0;

  int get _totalAllocated {
    int sum = 0;
    for (final controller in _allocationControllers.values) {
      sum += int.tryParse(controller.text.replaceAll(',', '')) ?? 0;
    }
    return sum;
  }

  int get _remaining => _totalAmount - _totalAllocated;

  @override
  void dispose() {
    _totalAmountController.dispose();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<MoneyPocket> pockets) {
    for (final pocket in pockets) {
      _allocationControllers.putIfAbsent(
        pocket.id,
        () => TextEditingController(text: '0'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('월급 분배'),
      ),
      body: BlocConsumer<PocketBloc, PocketState>(
        listener: (context, state) {
          if (state is PocketLoaded && state.operationError != null) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PocketLoaded && _isSubmitting) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('분배가 완료되었습니다')),
            );
            context.pop();
          }
        },
        builder: (context, state) {
          if (state is! PocketLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final pockets = state.pockets;
          _ensureControllers(pockets);

          return Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 0 && _totalAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('금액을 입력하세요')),
                );
                return;
              }
              if (_currentStep == 1 && _remaining != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '남은 금액이 ${_formatter.format(_remaining)}원 있습니다. 모두 분배해주세요.',
                    ),
                  ),
                );
                return;
              }
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _submitDistribution(context, pockets);
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                context.pop();
              }
            },
            controlsBuilder: (context, details) {
              final isConfirmStep = _currentStep == 2;
              final canContinue = isConfirmStep
                  ? !_isSubmitting && _remaining == 0
                  : true;
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: canContinue ? details.onStepContinue : null,
                      child: _isSubmitting && isConfirmStep
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(isConfirmStep ? '확정' : '다음'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _isSubmitting ? null : details.onStepCancel,
                      child: Text(_currentStep == 0 ? '취소' : '이전'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('총 금액 입력'),
                content: _buildStep1(),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('포켓별 금액 할당'),
                content: _buildStep2(pockets),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('확인'),
                content: _buildStep3(pockets),
                isActive: _currentStep >= 2,
                state: StepState.indexed,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('분배할 총 금액을 입력하세요'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _totalAmountController,
          decoration: const InputDecoration(
            labelText: '총 금액',
            suffixText: '원',
            prefixIcon: Icon(Icons.payments),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStep2(List<MoneyPocket> pockets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: _remaining == 0
              ? Colors.green.shade50
              : _remaining < 0
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('남은 금액'),
                Text(
                  '${_formatter.format(_remaining)}원',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _remaining == 0
                        ? Colors.green
                        : _remaining < 0
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...pockets.map((pocket) {
          final controller = _allocationControllers[pocket.id]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: pocket.name,
                suffixText: '원',
                prefixIcon: const Icon(Icons.account_balance_wallet),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep3(List<MoneyPocket> pockets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분배 요약',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('총 금액'),
                    Text(
                      '${_formatter.format(_totalAmount)}원',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),
                ...pockets.map((pocket) {
                  final amount = int.tryParse(
                        _allocationControllers[pocket.id]
                                ?.text
                                .replaceAll(',', '') ??
                            '0',
                      ) ??
                      0;
                  if (amount <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(pocket.name),
                        Text('${_formatter.format(amount)}원'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _submitDistribution(
      BuildContext context, List<MoneyPocket> pockets) {
    setState(() => _isSubmitting = true);

    final distributions = <Map<String, dynamic>>[];
    for (final pocket in pockets) {
      final amount = int.tryParse(
            _allocationControllers[pocket.id]
                    ?.text
                    .replaceAll(',', '') ??
                '0',
          ) ??
          0;
      if (amount > 0) {
        distributions.add({
          'pocketId': pocket.id,
          'amount': amount,
        });
      }
    }

    context.read<PocketBloc>().add(DistributeIncome(
          totalAmount: _totalAmount,
          distributions: distributions,
        ));
    // Pop happens in BlocListener after successful response
  }
}
