import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';

void main() {
  group('ThemeCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is ThemeMode.system', () {
      final cubit = ThemeCubit();
      expect(cubit.state, ThemeMode.system);
      cubit.close();
    });

    blocTest<ThemeCubit, ThemeMode>(
      'emits dark when setThemeMode(dark) is called',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => ThemeCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'emits light when setThemeMode(light) is called',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => ThemeCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.light),
      expect: () => [ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'emits system when setThemeMode(system) is called',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => ThemeCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.system),
      expect: () => [ThemeMode.system],
    );

    test('persists and loads theme from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final cubit = ThemeCubit();
      // Wait for async _load to complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cubit.state, ThemeMode.dark);
      cubit.close();
    });

    test('persists light theme to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = ThemeCubit();
      await cubit.setThemeMode(ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
      cubit.close();
    });
  });
}
