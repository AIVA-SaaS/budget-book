import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';

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
    return Padding(
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
                      label: Text('체크카드'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment(
                      value: 'CREDIT',
                      label: Text('신용카드'),
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
              // Settlement day and closing day (only for CREDIT type)
              if (_selectedType == 'CREDIT') ...[
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _closingDayController,
                  decoration: const InputDecoration(
                    labelText: '마감일 (결제 기준일)',
                    hintText: '1~31',
                    suffixText: '일',
                    prefixIcon: Icon(Icons.event),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
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
    );
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
      Navigator.of(context).pop();
    }
  }
}
