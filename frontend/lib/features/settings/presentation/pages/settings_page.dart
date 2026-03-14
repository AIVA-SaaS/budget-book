import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:budget_book/core/di/injection.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _defaultPaymentMethodId;
  String? _defaultPaymentMethodName;

  @override
  void initState() {
    super.initState();
    _loadDefaultPaymentMethod();
  }

  Future<void> _loadDefaultPaymentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('default_payment_method_id');
    if (id != null && mounted) {
      setState(() {
        _defaultPaymentMethodId = id;
      });
      // Load payment methods to resolve the name
      getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('설정'),
        ),
        body: ListView(
          children: [
            // Profile card
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthAuthenticated) {
                  final user = state.user;
                  return Card(
                    margin: const EdgeInsets.all(16),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: user.profileImageUrl != null
                            ? NetworkImage(user.profileImageUrl!)
                            : null,
                        child: user.profileImageUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.nickname),
                      subtitle: Text(user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.push('/settings/profile-edit'),
                        tooltip: '프로필 수정',
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Couple management
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('커플 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/couple'),
            ),
            const Divider(),
            // Categories
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('카테고리 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/categories'),
            ),
            // Category Groups
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('카테고리 그룹'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/category-groups'),
            ),
            // Payment Methods
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('결제수단 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/payment-methods'),
            ),
            // Money Pockets
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('머니 포켓'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/pockets'),
            ),
            // Recurring Transactions
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('반복 거래'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/recurring'),
            ),
            // Weekly Budgets
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('주간 예산'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/weekly-budgets'),
            ),
            const Divider(),
            // Theme setting
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('테마'),
                  subtitle: Text(_themeModeLabel(themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(context, themeMode),
                );
              },
            ),
            // Language setting
            BlocBuilder<LocaleCubit, Locale?>(
              builder: (context, locale) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('언어'),
                  subtitle: Text(_localeLabel(locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLocaleDialog(context, locale),
                );
              },
            ),
            // Default payment method
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
              child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
                builder: (context, pmState) {
                  String subtitle = '설정 안 됨';
                  if (_defaultPaymentMethodId != null &&
                      pmState is PaymentMethodLoaded) {
                    final match = pmState.paymentMethods.where(
                      (pm) => pm.id == _defaultPaymentMethodId,
                    );
                    if (match.isNotEmpty) {
                      subtitle = match.first.name;
                      _defaultPaymentMethodName = match.first.name;
                    }
                  } else if (_defaultPaymentMethodName != null) {
                    subtitle = _defaultPaymentMethodName!;
                  }
                  return ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('기본 결제수단'),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showDefaultPaymentMethodDialog(
                        context, pmState),
                  );
                },
              ),
            ),
            const Divider(),
            // App info
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('앱 정보'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/app-info'),
            ),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
      case ThemeMode.system:
        return '시스템 설정 따르기';
    }
  }

  String _localeLabel(Locale? locale) {
    if (locale == null) return '시스템 설정 따르기';
    switch (locale.languageCode) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }

  void _showThemeDialog(BuildContext context, ThemeMode current) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('테마 선택'),
        children: [
          _themeOption(dialogContext, '라이트 모드', ThemeMode.light, current),
          _themeOption(dialogContext, '다크 모드', ThemeMode.dark, current),
          _themeOption(
              dialogContext, '시스템 설정 따르기', ThemeMode.system, current),
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext dialogContext,
    String label,
    ThemeMode mode,
    ThemeMode current,
  ) {
    final isSelected = mode == current;
    return SimpleDialogOption(
      onPressed: () {
        context.read<ThemeCubit>().setThemeMode(mode);
        Navigator.of(dialogContext).pop();
      },
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _showLocaleDialog(BuildContext context, Locale? current) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('언어 선택'),
        children: [
          _localeOption(dialogContext, '한국어', const Locale('ko'), current),
          _localeOption(dialogContext, 'English', const Locale('en'), current),
          _localeOption(dialogContext, '시스템 설정 따르기', null, current),
        ],
      ),
    );
  }

  Widget _localeOption(
    BuildContext dialogContext,
    String label,
    Locale? locale,
    Locale? current,
  ) {
    final isSelected = (locale == null && current == null) ||
        (locale != null &&
            current != null &&
            locale.languageCode == current.languageCode);
    return SimpleDialogOption(
      onPressed: () {
        context.read<LocaleCubit>().setLocale(locale);
        Navigator.of(dialogContext).pop();
      },
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _showDefaultPaymentMethodDialog(
    BuildContext context,
    PaymentMethodState pmState,
  ) {
    // Ensure payment methods are loaded
    if (pmState is! PaymentMethodLoaded) {
      getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제수단 목록을 불러오는 중입니다...')),
      );
      return;
    }

    final methods = pmState.activePaymentMethods;
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('기본 결제수단 선택'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('default_payment_method_id');
              if (mounted) {
                setState(() {
                  _defaultPaymentMethodId = null;
                  _defaultPaymentMethodName = null;
                });
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Row(
              children: [
                Icon(
                  _defaultPaymentMethodId == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _defaultPaymentMethodId == null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                const Text('설정 안 함'),
              ],
            ),
          ),
          ...methods.map((pm) {
            final isSelected = pm.id == _defaultPaymentMethodId;
            return SimpleDialogOption(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('default_payment_method_id', pm.id);
                if (mounted) {
                  setState(() {
                    _defaultPaymentMethodId = pm.id;
                    _defaultPaymentMethodName = pm.name;
                  });
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(pm.name),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
