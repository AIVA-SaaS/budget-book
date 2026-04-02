import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_bloc.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_event.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_state.dart';
import 'package:budget_book/features/insurance/presentation/widgets/insurance_card.dart';

class InsuranceFormPage extends StatefulWidget {
  final String? insuranceId;

  const InsuranceFormPage({super.key, this.insuranceId});

  @override
  State<InsuranceFormPage> createState() => _InsuranceFormPageState();
}

class _InsuranceFormPageState extends State<InsuranceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _insurerController;
  late final TextEditingController _premiumController;
  late final TextEditingController _paymentDayController;
  late final TextEditingController _memoController;

  String _insuranceType = 'LIFE';
  String _paymentCycle = 'MONTHLY';
  String? _paymentMethodId;
  String? _categoryId;
  String? _categoryDisplayName;
  DateTime? _startDate;
  DateTime? _endDate;
  String _visibility = 'SHARED';
  bool _isSubmitting = false;
  bool _isDeleting = false;
  Insurance? _existingInsurance;

  bool get isEditing => widget.insuranceId != null;

  static const _typeOptions = [
    ('LIFE', '생명보험'),
    ('HEALTH', '건강보험'),
    ('CAR', '자동차보험'),
    ('FIRE', '화재보험'),
    ('ACCIDENT', '상해보험'),
    ('OTHER', '기타'),
  ];

  static const _cycleOptions = [
    ('MONTHLY', '매월'),
    ('QUARTERLY', '분기'),
    ('SEMI_ANNUAL', '반기'),
    ('YEARLY', '연간'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _insurerController = TextEditingController();
    _premiumController = TextEditingController();
    _paymentDayController = TextEditingController();
    _memoController = TextEditingController();

    // Ensure categories and payment methods are loaded for selectors
    final cgBloc = getIt<CategoryGroupBloc>();
    if (cgBloc.state is! CategoryGroupLoaded) {
      cgBloc.add(const LoadCategoryGroups());
    }
    final pmBloc = getIt<PaymentMethodBloc>();
    if (pmBloc.state is PaymentMethodInitial) {
      pmBloc.add(const LoadPaymentMethods());
    }

    if (isEditing) {
      _loadExistingInsurance();
    }
  }

  void _loadExistingInsurance() {
    final bloc = context.read<InsuranceBloc>();
    final state = bloc.state;
    if (state is InsuranceLoaded) {
      final insurance = state.insurances
          .where((i) => i.id == widget.insuranceId)
          .firstOrNull;
      if (insurance != null) {
        _populateForm(insurance);
      }
    }
  }

  void _populateForm(Insurance insurance) {
    _existingInsurance = insurance;
    _nameController.text = insurance.name;
    _insurerController.text = insurance.insurer ?? '';
    _premiumController.text = CurrencyFormatter.format(insurance.premiumAmount);
    _paymentDayController.text =
        insurance.paymentDay != null ? '${insurance.paymentDay}' : '';
    _memoController.text = insurance.memo ?? '';
    _insuranceType = insurance.insuranceType;
    _paymentCycle = insurance.paymentCycle;
    _paymentMethodId = insurance.paymentMethodId;
    _categoryId = insurance.categoryId;
    // Look up category display name from BLoC state
    if (_categoryId != null) {
      final catState = getIt<CategoryBloc>().state;
      if (catState is CategoryLoaded) {
        _categoryDisplayName = catState.categories
            .where((c) => c.id == _categoryId)
            .map((c) => c.name)
            .firstOrNull;
      }
    }
    _visibility = insurance.visibility;
    if (insurance.startDate != null) {
      _startDate = DateTime.tryParse(insurance.startDate!);
    }
    if (insurance.endDate != null) {
      _endDate = DateTime.tryParse(insurance.endDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _insurerController.dispose();
    _premiumController.dispose();
    _paymentDayController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatter.parse(_premiumController.text);
    if (amount == null || amount <= 0) return;

    final name = _nameController.text.trim();
    final insurer = _insurerController.text.trim().isEmpty
        ? null
        : _insurerController.text.trim();
    final paymentDay = int.tryParse(_paymentDayController.text.trim());
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    final startDateStr =
        _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final endDateStr =
        _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    setState(() => _isSubmitting = true);

    final bloc = context.read<InsuranceBloc>();

    if (isEditing) {
      final old = _existingInsurance;
      bloc.add(UpdateInsurance(
        id: widget.insuranceId!,
        name: name,
        insurer: insurer,
        clearInsurer: insurer == null && old?.insurer != null,
        insuranceType: _insuranceType,
        premiumAmount: amount,
        paymentDay: paymentDay,
        clearPaymentDay: paymentDay == null && old?.paymentDay != null,
        paymentCycle: _paymentCycle,
        paymentMethodId: _paymentMethodId,
        clearPaymentMethodId:
            _paymentMethodId == null && old?.paymentMethodId != null,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null && old?.categoryId != null,
        startDate: startDateStr,
        clearStartDate: startDateStr == null && old?.startDate != null,
        endDate: endDateStr,
        clearEndDate: endDateStr == null && old?.endDate != null,
        memo: memo,
        clearMemo: memo == null && old?.memo != null,
        visibility: _visibility,
      ));
    } else {
      bloc.add(CreateInsurance(
        name: name,
        insurer: insurer,
        insuranceType: _insuranceType,
        premiumAmount: amount,
        paymentDay: paymentDay,
        paymentCycle: _paymentCycle,
        paymentMethodId: _paymentMethodId,
        categoryId: _categoryId,
        startDate: startDateStr,
        endDate: endDateStr,
        memo: memo,
        visibility: _visibility,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InsuranceBloc, InsuranceState>(
      listener: (context, state) {
        if (state is InsuranceLoaded && state.operationError != null) {
          setState(() {
            _isSubmitting = false;
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else if (state is InsuranceLoaded && _isDeleting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제되었습니다')),
          );
          context.pop();
        } else if (state is InsuranceLoaded && _isSubmitting) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEditing ? '수정되었습니다' : '저장되었습니다')),
          );
          context.pop();
        } else if (state is InsuranceError && (_isSubmitting || _isDeleting)) {
          setState(() {
            _isSubmitting = false;
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? '보험 수정' : '보험 추가'),
          actions: [
            if (isEditing)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
        body: _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    final catState = getIt<CategoryBloc>().state;
    final categories = catState is CategoryLoaded
        ? catState.categories.where((c) => c.type == 'EXPENSE').toList()
        : <Category>[];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Start date
          InkWell(
            onTap: () => _selectDate(isStart: true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '시작일',
                prefixIcon: const Icon(Icons.play_arrow),
                suffixIcon: _startDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _startDate = null),
                      )
                    : null,
              ),
              child: Text(
                _startDate != null
                    ? DateFormat('yyyy년 M월 d일', 'ko').format(_startDate!)
                    : '선택 안 함',
                style: _startDate == null
                    ? TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 2. Premium amount (required)
          TextFormField(
            controller: _premiumController,
            decoration: const InputDecoration(
              labelText: '보험료 *',
              prefixIcon: Icon(Icons.attach_money),
              suffixText: '원',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) return '보험료를 입력하세요';
              final amount = CurrencyFormatter.parse(value);
              if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
              if (amount > 999999999) return '최대 999,999,999원까지 입력 가능합니다';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // 3. Insurance name (required)
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '보험 이름 *',
              prefixIcon: Icon(Icons.shield),
              hintText: '예: 삼성생명 종신보험',
            ),
            maxLength: 100,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '보험 이름을 입력하세요';
              return null;
            },
          ),
          const SizedBox(height: 12),
          // 4. Insurer
          TextFormField(
            controller: _insurerController,
            decoration: const InputDecoration(
              labelText: '보험사',
              prefixIcon: Icon(Icons.business),
              hintText: '예: 삼성생명',
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          // 5. Insurance type dropdown
          DropdownButtonFormField<String>(
            initialValue: _insuranceType,
            decoration: const InputDecoration(
              labelText: '보험 유형 *',
              prefixIcon: Icon(Icons.category),
            ),
            isExpanded: true,
            items: _typeOptions
                .map((e) => DropdownMenuItem(
                      value: e.$1,
                      child: Row(
                        children: [
                          Icon(
                            insuranceTypeIcon(e.$1),
                            size: 18,
                            color: insuranceTypeColor(e.$1),
                          ),
                          const SizedBox(width: 8),
                          Text(e.$2),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _insuranceType = value);
            },
          ),
          const SizedBox(height: 16),
          // 6. Payment day
          TextFormField(
            controller: _paymentDayController,
            decoration: const InputDecoration(
              labelText: '납부일',
              prefixIcon: Icon(Icons.calendar_today),
              hintText: '1-31',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final day = int.tryParse(value);
              if (day == null || day < 1 || day > 31) {
                return '1~31 사이의 숫자를 입력하세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Payment cycle dropdown
          DropdownButtonFormField<String>(
            initialValue: _paymentCycle,
            decoration: const InputDecoration(
              labelText: '납부 주기',
              prefixIcon: Icon(Icons.repeat),
            ),
            isExpanded: true,
            items: _cycleOptions
                .map((e) => DropdownMenuItem(
                      value: e.$1,
                      child: Text(e.$2),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _paymentCycle = value);
            },
          ),
          const SizedBox(height: 16),
          // 7. Payment method selector
          ItemSelectorField(
            label: '결제수단',
            selectedLabel: _paymentMethodId != null
                ? methods.where((pm) => pm.id == _paymentMethodId).map((pm) => pm.name).firstOrNull
                : null,
            prefixIcon: Icons.credit_card,
            placeholder: '선택 안 함',
            onTap: () => _showPaymentMethodSelectorSheet(context, methods),
          ),
          const SizedBox(height: 16),
          // 8. Category selector
          ItemSelectorField(
            label: '카테고리',
            selectedLabel: _categoryDisplayName ?? (_categoryId != null
                ? categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull ?? '(삭제됨)'
                : null),
            prefixIcon: Icons.category,
            placeholder: '선택 안 함',
            onTap: () => _showCategorySelectorSheet(context),
          ),
          const SizedBox(height: 16),
          // 9. End date
          InkWell(
            onTap: () => _selectDate(isStart: false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '만기일',
                prefixIcon: const Icon(Icons.stop),
                suffixIcon: _endDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _endDate = null),
                      )
                    : null,
              ),
              child: Text(
                _endDate != null
                    ? DateFormat('yyyy년 M월 d일', 'ko').format(_endDate!)
                    : '선택 안 함 (종신)',
                style: _endDate == null
                    ? TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 10. Memo
          TextFormField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: '메모',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // 11. Visibility
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(
              labelText: '공개 범위',
              prefixIcon: Icon(Icons.visibility),
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'SHARED', child: Text('공유')),
              DropdownMenuItem(value: 'PRIVATE', child: Text('비공개')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _visibility = value);
            },
          ),
          const SizedBox(height: 24),
          // Submit button
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: Text("'${_nameController.text}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isDeleting = true);
              this.context.read<InsuranceBloc>().add(DeleteInsurance(widget.insuranceId!));
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showCategorySelectorSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _categoryId,
        categoryType: 'EXPENSE',
        onSelected: (category) {
          setState(() {
            _categoryId = category?.id;
            _categoryDisplayName = null;
          });
        },
        onSelectedWithGroupName: (category, groupName) {
          setState(() {
            _categoryId = category?.id;
            if (category != null && groupName != null && groupName.isNotEmpty) {
              _categoryDisplayName = '$groupName > ${category.name}';
            } else {
              _categoryDisplayName = category?.name;
            }
          });
        },
        onDelete: (id) {
          if (_categoryId == id) {
            setState(() {
              _categoryId = null;
              _categoryDisplayName = null;
            });
          }
        },
      ),
    );
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = getIt<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (sheetContext, pmState) {
            final liveMethods = pmState is PaymentMethodLoaded
                ? pmState.activePaymentMethods
                : methods;
            return ItemSelectorSheet(
              title: '결제수단 선택',
              items: liveMethods
                  .indexed
                  .map((e) => SelectorItem(
                        id: e.$2.id,
                        label: e.$2.name,
                        leadingIcon: paymentMethodTypeIcon(e.$2.type),
                        leadingColor: paymentMethodTypeColor(e.$2.type),
                        isDeletable: true,
                        displayOrder: e.$1,
                        group: e.$2.type,
                      ))
                  .toList(),
              selectedId: _paymentMethodId,
              nullLabel: '선택 안 함',
              favoriteType: 'PAYMENT_METHOD',
              reorderRoute: '/asset-management',
              groupLabels: paymentMethodGroupLabels,
              onSelected: (item) {
                setState(() {
                  _paymentMethodId = item?.id;
                });
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_paymentMethodId == id) {
                  setState(() => _paymentMethodId = null);
                }
              },
              onCreate: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider<PaymentMethodBloc>.value(
                    value: pmBloc,
                    child: PaymentMethodFormSheet(
                      onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
                        pmBloc.add(CreatePaymentMethod(
                          name: name,
                          type: type,
                          settlementDay: settlementDay,
                          closingDay: closingDay,
                          linkedBankId: linkedBankId,
                        ));
                      },
                    ),
                  ),
                );
              },
              createLabel: '+ 새 결제수단',
            );
          },
        ),
      ),
    );
  }
}
