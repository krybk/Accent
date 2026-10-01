import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The UI language the user picked, or null to follow the system.
class LocaleController extends ChangeNotifier {
  static const prefsKey = 'app.locale';
  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(prefsKey);
    _locale = code == null ? null : Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, locale.languageCode);
    }
  }
}
