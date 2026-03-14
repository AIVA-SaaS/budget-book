import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';

void main() {
  group('LocaleCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is null (system default)', () {
      final cubit = LocaleCubit();
      expect(cubit.state, isNull);
      cubit.close();
    });

    blocTest<LocaleCubit, Locale?>(
      'emits Locale(ko) when setLocale(ko) is called',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => LocaleCubit(),
      act: (cubit) => cubit.setLocale(const Locale('ko')),
      expect: () => [const Locale('ko')],
    );

    blocTest<LocaleCubit, Locale?>(
      'emits Locale(en) when setLocale(en) is called',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => LocaleCubit(),
      act: (cubit) => cubit.setLocale(const Locale('en')),
      expect: () => [const Locale('en')],
    );

    blocTest<LocaleCubit, Locale?>(
      'emits null when setLocale(null) is called (system)',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => LocaleCubit(),
      act: (cubit) async {
        await cubit.setLocale(const Locale('en'));
        await cubit.setLocale(null);
      },
      expect: () => [const Locale('en'), null],
    );

    test('persists and loads locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'locale': 'en'});
      final cubit = LocaleCubit();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cubit.state, const Locale('en'));
      cubit.close();
    });

    test('loads null when saved value is system', () async {
      SharedPreferences.setMockInitialValues({'locale': 'system'});
      final cubit = LocaleCubit();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cubit.state, isNull);
      cubit.close();
    });

    test('persists locale to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = LocaleCubit();
      await cubit.setLocale(const Locale('ko'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'ko');
      cubit.close();
    });

    test('persists system to SharedPreferences when null', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = LocaleCubit();
      await cubit.setLocale(null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'system');
      cubit.close();
    });
  });
}
