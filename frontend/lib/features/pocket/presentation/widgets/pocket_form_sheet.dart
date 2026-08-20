import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';

class PocketFormSheet extends StatefulWidget {
  final MoneyPocket? pocket;
  final void Function(
    String name,
    String type,
    int allocatedAmount,
    String? icon,
    String? color,
    int? goalAmount,
    String? targetDate,
  ) onSubmit;

  const PocketFormSheet({
    super.key,
    this.pocket,
    required this.onSubmit,
  });

  @override
  State<PocketFormSheet> createState() => _PocketFormSheetState();
}

class _PocketFormSheetState extends State<PocketFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _goalAmountController;
  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColor;
  DateTime? _selectedTargetDate;
  bool _isSubmitting = false;

  bool get isEditing => widget.pocket != null;

  static const _typeLabels = {
    'LIVING': '생활비',
    'FIXED': '고정지출',
    'CARD_PENDING': '카드미결제',
    'SAVINGS': '저축',
    'CUSTOM': '직접입력',
  };

  static const _iconOptions = [
    'home',
    'restaurant',
    'shopping_cart',
    'directions_bus',
    'savings',
    'payments',
    'account_balance',
    'card_giftcard',
  ];

  static const _colorOptions = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#795548',
    '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pocket;
    _nameController = TextEditingController(text: p?.name ?? '');
    _amountController = TextEditingController(
      text: p != null ? p.allocatedAmount.toString() : '',
    );
    _goalAmountController = TextEditingController(
      text: p?.goalAmount != null ? p!.goalAmount.toString() : '',
    );
    _selectedType = p?.type ?? 'LIVING';
    _selectedIcon = p?.icon ?? 'home';
    _selectedColor = p?.color ?? '#4CAF50';
    if (p?.targetDate != null) {
      try {
        _selectedTargetDate = DateTime.parse(p!.targetDate!);
      } catch (_) {
        _selectedTargetDate = null;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _goalAmountController.dispose();
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
                isEditing ? '포켓 수정' : '포켓 추가',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '포켓 이름',
                  hintText: '예: 생활비, 저축',
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '포켓 이름을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Type dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: '유형',
                  prefixIcon: Icon(Icons.label),
                ),
                items: _typeLabels.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Amount field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '할당 금액',
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
                  if (amount == null || amount < 0) {
                    return '0 이상의 금액을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Goal amount field (optional)
              TextFormField(
                controller: _goalAmountController,
                decoration: const InputDecoration(
                  labelText: '목표 금액 (선택)',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.flag),
                  hintText: '설정하지 않으면 목표 없음',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final amount = int.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return '0보다 큰 금액을 입력하세요';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Target date field (optional)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _selectedTargetDate != null
                      ? '목표일: ${DateFormat('yyyy-MM-dd').format(_selectedTargetDate!)}'
                      : '목표일 (선택)',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: _selectedTargetDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _selectedTargetDate = null);
                        },
                      )
                    : null,
                onTap: () async {
                  final picked = await showCalendarPickerDialog(
                    context: context,
                    initialDate: _selectedTargetDate ??
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _selectedTargetDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Icon selector
              Text(
                '아이콘',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _iconOptions.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Icon(
                      UIHelpers.resolveIcon(iconName,
                          fallback: Icons.account_balance_wallet),
                      size: 20,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedIcon = iconName;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Color selector
              Text(
                '색상',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((hex) {
                  final isSelected = _selectedColor == hex;
                  final color = UIHelpers.parseColor(hex);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = hex;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  padding: context.bbSpace
                      .symmetric(h: BbSpaceToken.md, v: BbSpaceToken.xl),
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
      final amount = int.parse(_amountController.text.trim());
      final goalText = _goalAmountController.text.trim();
      final goalAmount = goalText.isNotEmpty ? int.tryParse(goalText) : null;
      final targetDate = _selectedTargetDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedTargetDate!)
          : null;
      widget.onSubmit(
        _nameController.text.trim(),
        _selectedType,
        amount,
        _selectedIcon,
        _selectedColor,
        goalAmount,
        targetDate,
      );
      Navigator.of(context).pop();
    }
  }
}
