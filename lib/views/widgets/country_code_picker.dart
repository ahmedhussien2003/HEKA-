import 'package:flutter/material.dart';
import '../../data/notifiers.dart';

class CountryInfo {
  // final String nameAr;
  final String code;
  final String flag;
  final String isoCode;

  const CountryInfo({
    // required this.nameAr,
    required this.code,
    required this.flag,
    required this.isoCode,
  });

  // String getName(bool isArabic) => isArabic ? nameAr : nameAr;
}

const List<CountryInfo> supportedCountries = [
  CountryInfo(code: '+20', flag: '🇪🇬', isoCode: 'EG'),
  CountryInfo(code: '+966', flag: '🇸🇦', isoCode: 'SA'),
  CountryInfo(code: '+971', flag: '🇦🇪', isoCode: 'AE'),
  CountryInfo(code: '+965', flag: '🇰🇼', isoCode: 'KW'),
  CountryInfo(code: '+974', flag: '🇶🇦', isoCode: 'QA'),
  CountryInfo(code: '+973', flag: '🇧🇭', isoCode: 'BH'),
  CountryInfo(code: '+968', flag: '🇴🇲', isoCode: 'OM'),
  CountryInfo(code: '+962', flag: '🇯🇴', isoCode: 'JO'),
  CountryInfo(code: '+964', flag: '🇮🇶', isoCode: 'IQ'),
  CountryInfo(code: '+961', flag: '🇱🇧', isoCode: 'LB'),
  CountryInfo(code: '+963', flag: '🇸🇾', isoCode: 'SY'),
  CountryInfo(code: '+967', flag: '🇾🇪', isoCode: 'YE'),
  CountryInfo(code: '+218', flag: '🇱🇾', isoCode: 'LY'),
  CountryInfo(code: '+212', flag: '🇲🇦', isoCode: 'MA'),
  CountryInfo(code: '+216', flag: '🇹🇳', isoCode: 'TN'),
  CountryInfo(code: '+213', flag: '🇩🇿', isoCode: 'DZ'),
  CountryInfo(code: '+970', flag: '🇵🇸', isoCode: 'PS'),
  CountryInfo(code: '+1', flag: '🇺🇸', isoCode: 'US'),
  CountryInfo(code: '+44', flag: '🇬🇧', isoCode: 'GB'),
  CountryInfo(code: '+49', flag: '🇩🇪', isoCode: 'DE'),
  CountryInfo(code: '+33', flag: '🇫🇷', isoCode: 'FR'),
  CountryInfo(code: '+1', flag: '🇨🇦', isoCode: 'CA'),
];

class CountryCodeDropdown extends StatelessWidget {
  final CountryInfo selectedCountry;
  final ValueChanged<CountryInfo> onChanged;
  final bool isDarkMode;
  final Color textColor;
  final Color dropdownBgColor;

  const CountryCodeDropdown({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
    required this.isDarkMode,
    required this.textColor,
    required this.dropdownBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = selectedLanguageNotifier.value == 'Arabic';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CountryInfo>(
          value: selectedCountry,
          dropdownColor: dropdownBgColor,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            size: 18,
          ),
          onChanged: (CountryInfo? newCountry) {
            if (newCountry != null) {
              onChanged(newCountry);
            }
          },
          items: supportedCountries.map((CountryInfo country) {
            return DropdownMenuItem<CountryInfo>(
              value: country,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    country.code,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return supportedCountries.map((CountryInfo country) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    country.code,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
