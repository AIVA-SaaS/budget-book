import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';

class PocketTransferFormSheet extends StatefulWidget {
  final List<MoneyPocket> pockets;
  final void Function(
    String fromPocketId,
    String toPocketId,
    int amount,
    String? description,
    String transferDate,
  ) onSubmit;

  const PocketTransferFormSheet({
    super.key,
    required this.pockets,
    required this.onSubmit,
  });

  @override
  State<PocketTransferFormSheet> createState() =>
      _PocketTransferFormSheetState();
}

class _PocketTransferFormSheetState extends State<PocketTransferFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _fromPocketId;
  String? _toPocketId;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
                '포켓 이체',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              // From pocket
              DropdownButtonFormField<String>(
                initialValue: _fromPocketId,
                decoration: const InputDecoration(
                  labelText: '보내는 포켓',
                  prefixIcon: Icon(Icons.arrow_upward),
                ),
                items: widget.pockets
                    .map((p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                validator: (value) {
                  if (value == null) return '보내는 포켓을 선택하세요';
                  return null;
                },
                onChanged: (value) {
                  setState(() => _fromPocketId = value);
                },
              ),
              const SizedBox(height: 16),
              // To pocket
              DropdownButtonFormField<String>(
                initialValue: _toPocketId,
                decoration: const InputDecoration(
                  labelText: '받는 포켓',
                  prefixIcon: Icon(Icons.arrow_downward),
                ),
                items: widget.pockets
                    .map((p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                validator: (value) {
                  if (value == null) return '받는 포켓을 선택하세요';
                  if (value == _fromPocketId) return '같은 포켓으로 이체할 수 없습니다';
                  return null;
                },
                onChanged: (value) {
                  setState(() => _toPocketId = value);
                },
              ),
              const SizedBox(height: 16),
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '금액',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '금액을 입력하세요';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '0보다 큰 금액을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  hintText: '예: 이월 저축',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLength: 255,
              ),
              const SizedBox(height: 16),
              // Date
              InkWell(
                onTap: () async {
                  final picked = await showCalendarPickerDialog(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '날짜',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 24),
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
                    : const Text('이체'),
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
      final amount = int.parse(_amountController.text.trim());
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      widget.onSubmit(
        _fromPocketId!,
        _toPocketId!,
        amount,
        description,
        dateStr,
      );
      Navigator.of(context).pop();
    }
  }
}
