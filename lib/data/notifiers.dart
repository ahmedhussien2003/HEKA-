//valueNotifier: hold the data
//valueListenableBuilder: Listen to the data(you don't need the set state)


// data/notifiers.dart
import 'package:flutter/material.dart';

ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);
ValueNotifier<int> selectedHeaderNotifier = ValueNotifier(0);
ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
ValueNotifier<String> selectedLanguageNotifier = ValueNotifier('English');
ValueNotifier<bool> showArabicEnglishNotifier = ValueNotifier(false);

String getAppFontFamily() {
  return 'JosefinSans';
}

/// The 7 supported UI languages.
const List<Map<String, String>> kSupportedLanguages = [
  {'name': 'Arabic', 'flag': '🇪🇬', 'native': 'العربية', 'code': 'ar'},
  {'name': 'English', 'flag': '🇬🇧', 'native': 'English', 'code': 'en'},
  {'name': 'Italian', 'flag': '🇮🇹', 'native': 'Italiano', 'code': 'it'},
  {'name': 'German', 'flag': '🇩🇪', 'native': 'Deutsch', 'code': 'de'},
  {'name': 'Spanish', 'flag': '🇪🇸', 'native': 'Español', 'code': 'es'},
  {'name': 'Russian', 'flag': '🇷🇺', 'native': 'Русский', 'code': 'ru'},
  {'name': 'Polish', 'flag': '🇵🇱', 'native': 'Polski', 'code': 'pl'},
];

