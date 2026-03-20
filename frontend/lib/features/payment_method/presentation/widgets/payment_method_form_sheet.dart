import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/payment_method/data/card_issuer_presets.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

class PaymentMethodFormSheet extends StatefulWidget {
  final PaymentMethod? paymentMethod;
  final void Function(
    String name,
    String type,
    int? settlementDay,
    int? closingDay,
  ) onSubmit;

  const PaymentMethodFormSheet({
    super.key,
    this.paymentMethod,
    required this.onSubmit,
  });

  @override
  State<PaymentMethodFormSheet> createState() =>
      _PaymentMethodFormSheetState();
}

class _PaymentMethodFormSheetState extends State<PaymentMethodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _settlementDayController;
  late final TextEditingController _closingDayController;
  late String _selectedType;
  String? _selectedIssuerId;
  bool _isSubmitting = false;

  bool get isEditing => widget.paymentMethod != null;

  @override
  void initState() {
    super.initState();
    final pm = widget.paymentMethod;
    _nameController = TextEditingController(text: pm?.name ?? '');
    _settlementDayController = TextEditingController(
      text: pm?.settlementDay?.toString() ?? '',
    );
    _closingDayController = TextEditingController(
      text: pm?.closingDay?.toString() ?? '',
    );
    _selectedType = pm?.type ?? 'CASH';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _settlementDayController.dispose();
    _closingDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentMethodBloc, PaymentMethodState>(
      listener: (context, state) {
        if (!_isSubmitting) return;
        if (state is PaymentMethodLoaded && state.operationError == null) {
          Navigator.of(context).pop();
        } else if (state is PaymentMethodLoaded &&
            state.operationError != null) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? '결제수단 수정' : '결제수단 추가',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '결제수단 이름',
                  hintText: '예: 현금, 신한카드',
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '결제수단 이름을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Type selector (only for new payment methods)
              if (!isEditing) ...[
                Text(
                  '유형',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'CASH',
                      label: Text('현금'),
                      icon: Icon(Icons.money),
                    ),
                    ButtonSegment(
                      value: 'DEBIT',
                      label: Text('체크'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment(
                      value: 'CREDIT',
                      label: Text('신용'),
                      icon: Icon(Icons.credit_score),
                    ),
                    ButtonSegment(
                      value: 'BANK',
                      label: Text('은행'),
                      icon: Icon(Icons.account_balance),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedType = value.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Card issuer presets + closing/settlement day (only for CREDIT type)
              if (_selectedType == 'CREDIT') ...[
                if (!isEditing) ...[
                  Text('카드사', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...cardIssuerPresets.map((preset) => ChoiceChip(
                        label: Text(preset.name, style: const TextStyle(fontSize: 12)),
                        selected: _selectedIssuerId == preset.id,
                        onSelected: (_) => _onCardIssuerSelected(preset),
                        visualDensity: VisualDensity.compact,
                      )),
                      ChoiceChip(
                        label: const Text('직접 입력', style: TextStyle(fontSize: 12)),
                        selected: _selectedIssuerId == 'custom',
                        onSelected: (_) {
                          setState(() {
                            _selectedIssuerId = 'custom';
                            _settlementDayController.clear();
                            _closingDayController.clear();
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _closingDayController,
                  decoration: const InputDecoration(
                    labelText: '마감일 (결제 기준일)',
                    hintText: '1~31 (31 = 매월 말일)',
                    suffixText: '일',
                    prefixIcon: Icon(Icons.event),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (_selectedType == 'CREDIT') {
                      if (value == null || value.trim().isEmpty) {
                        return '신용카드는 마감일을 입력해야 합니다';
                      }
                    }
                    if (value != null && value.isNotEmpty) {
                      final day = int.tryParse(value);
                      if (day == null || day < 1 || day > 31) {
                        return '1~31 사이의 숫자를 입력하세요';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _settlementDayController,
                  decoration: const InputDecoration(
                    labelText: '결제일',
                    hintText: '1~31',
                    suffixText: '일',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (_selectedType == 'CREDIT') {
                      if (value == null || value.trim().isEmpty) {
                        return '신용카드는 결제일을 입력해야 합니다';
                      }
                    }
                    if (value != null && value.isNotEmpty) {
                      final day = int.tryParse(value);
                      if (day == null || day < 1 || day > 31) {
                        return '1~31 사이의 숫자를 입력하세요';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Billing cycle info
                _buildBillingCycleInfo(context),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isSubmitting ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? '수정' : '추가'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBillingCycleInfo(BuildContext context) {
    final closingDay = int.tryParse(_closingDayController.text);
    final settlementDay = int.tryParse(_settlementDayController.text);

    if (closingDay == null || closingDay < 1 || closingDay > 31) {
      return const SizedBox.shrink();
    }

    final isEndOfMonth = closingDay == 31;
    final closingLabel = isEndOfMonth ? '말일' : '$closingDay일';

    // Billing period: from (closingDay + 1) of previous month to closingDay of current month
    String periodText;
    if (isEndOfMonth) {
      periodText = '이용 기간: 매월 1일 ~ 말일';
    } else {
      final startDay = closingDay + 1;
      periodText = '이용 기간: 전월 $startDay일 ~ 당월 $closingLabel';
    }

    String? settlementText;
    if (settlementDay != null && settlementDay >= 1 && settlementDay <= 31) {
      settlementText = '결제일: 매월 $settlementDay일에 대금 청구';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '결제 주기 안내',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            periodText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isEndOfMonth)
            Text(
              '* 2월은 28일(윤년 29일), 각 월 마지막 날 자동 적용',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
            ),
          if (settlementText != null)
            Text(
              settlementText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  void _onCardIssuerSelected(CardIssuerPreset preset) {
    setState(() {
      _selectedIssuerId = preset.id;
      _settlementDayController.text = preset.settlementDay.toString();
      _closingDayController.text = preset.closingDay.toString();
      if (_nameController.text.isEmpty) {
        _nameController.text = preset.name;
      }
    });
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);
      final settlementDay = _settlementDayController.text.isNotEmpty
          ? int.tryParse(_settlementDayController.text)
          : null;
      final closingDay = _closingDayController.text.isNotEmpty
          ? int.tryParse(_closingDayController.text)
          : null;

      widget.onSubmit(
        _nameController.text.trim(),
        _selectedType,
        settlementDay,
        closingDay,
      );
    }
  }
}
