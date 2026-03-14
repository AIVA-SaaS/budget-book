import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores user's locale preference.
/// Emits `null` for "follow system", or a specific [Locale].
class LocaleCubit extends Cubit<Locale?> {
  static const _key = 'locale';

  LocaleCubit() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null && value != 'system') {
      emit(Locale(value));
    }
    // null means system default
  }

  Future<void> setLocale(Locale? locale) async {
    emit(locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.setString(_key, 'system');
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
