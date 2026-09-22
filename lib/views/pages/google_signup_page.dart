import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';
import '../widgets/country_code_picker.dart';
import '../widget_tree.dart';

class GoogleSignupPage extends StatefulWidget {
  final User googleUser;

  const GoogleSignupPage({super.key, required this.googleUser});

  @override
  State<GoogleSignupPage> createState() => _GoogleSignupPageState();
}

class _GoogleSignupPageState extends State<GoogleSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  CountryInfo _selectedCountry = supportedCountries.first; // Egypt (+20) by default
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Split Google display name into first name and last name
    final parts = (widget.googleUser.displayName ?? '').split(' ');
    _firstNameController.text = parts.isNotEmpty ? parts.first : '';
    _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      String body = _phoneController.text.trim();
      if (body.startsWith('0')) {
        body = body.substring(1);
      }
      final fullPhone = '${_selectedCountry.code}$body';

      // 1. Save user profile data to Firestore
      await _firestoreService.saveUserData(
        uid: widget.googleUser.uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: widget.googleUser.email ?? '',
        phoneNumber: fullPhone,
        birthDate: '${_dayController.text.trim()}/${_monthController.text.trim()}/${_yearController.text.trim()}',
      );

      // 2. Save language preference
      await _firestoreService.saveUserLanguage(
        widget.googleUser.uid,
        selectedLanguageNotifier.value,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WidgetTree()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _handleBackPress() async {
    // If user attempts to leave before saving details, clean up Auth session
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedLanguageNotifier,
      builder: (context, language, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDarkMode, child) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            final backgroundColor = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final inputFillColor = isDarkMode
                ? Temple_Input_Fill_Dark
                : Temple_Input_Fill_Light;
            final textGrayColor = isDarkMode
                ? Temple_Text_Gray_Dark
                : Temple_Text_Gray_Light;
            final gradientCenterColor = isDarkMode
                ? const Color(0xFF2A2616)
                : const Color(0xFFE8DFC5);

            return WillPopScope(
              onWillPop: _handleBackPress,
              child: Scaffold(
                backgroundColor: backgroundColor,
                body: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.5,
                      colors: [gradientCenterColor, backgroundColor],
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Top Bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Temple_Gold),
                                    onPressed: () async {
                                      if (await _handleBackPress()) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                  ),
                                  Row(
                                    children: [
                                      // Language picker
                                      ValueListenableBuilder<String>(
                                        valueListenable: selectedLanguageNotifier,
                                        builder: (context, selectedLang, _) {
                                          final langData = kSupportedLanguages.firstWhere(
                                            (l) => l['name'] == selectedLang,
                                            orElse: () => kSupportedLanguages[1],
                                          );
                                          return GestureDetector(
                                            onTap: () => _showLanguagePicker(
                                              context,
                                              isDarkMode,
                                              inputFillColor,
                                              textGrayColor,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: inputFillColor,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Temple_Muted_Gold,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    langData['flag']!,
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    langData['name']!,
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white70
                                                          : Temple_Text_Gray_Light,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: getAppFontFamily(),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.expand_more,
                                                    color: Temple_Gold,
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Dark mode toggle
                                      IconButton(
                                        icon: Icon(
                                          isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                          color: Temple_Gold,
                                        ),
                                        onPressed: () {
                                          isDarkModeNotifier.value =
                                              !isDarkModeNotifier.value;
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(height: screenHeight * 0.02),

                              // Eye Logo
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? const Color(0xFF1E1C14)
                                      : Colors.white.withOpacity(0.5),
                                  border: Border.all(
                                    color: Temple_Gold.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Temple_Gold.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.visibility_outlined,
                                  color: Temple_Gold,
                                  size: 40,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'HEKA',
                                style: TextStyle(
                                  color: Temple_Gold,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontFamily: getAppFontFamily(),
                                ),
                              ),
                              Text(
                                AppTranslations.translate('complete_profile'),
                                style: TextStyle(
                                  color: textGrayColor.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4,
                                  fontFamily: getAppFontFamily(),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Display Google Email as Read-Only
                              _buildTempleReadOnlyField(
                                label: AppTranslations.translate('email_label'),
                                value: widget.googleUser.email ?? '',
                                icon: Icons.email_outlined,
                                isDarkMode: isDarkMode,
                                textGrayColor: textGrayColor,
                                inputFillColor: inputFillColor,
                              ),

                              const SizedBox(height: 20),

                              // First and Last Name
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTempleTextField(
                                      label: AppTranslations.translate('first_name'),
                                      hint: '...',
                                      icon: Icons.person_outline,
                                      controller: _firstNameController,
                                      textGrayColor: textGrayColor,
                                      inputFillColor: inputFillColor,
                                      isDarkMode: isDarkMode,
                                      validator: (value) =>
                                          value!.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _buildTempleTextField(
                                      label: AppTranslations.translate('last_name'),
                                      hint: '...',
                                      icon: Icons.person_outline,
                                      controller: _lastNameController,
                                      textGrayColor: textGrayColor,
                                      inputFillColor: inputFillColor,
                                      isDarkMode: isDarkMode,
                                      validator: (value) =>
                                          value!.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Phone field
                              _buildTempleTextField(
                                label: AppTranslations.translate('phone'),
                                hint: '10 1234 5678',
                                icon: Icons.phone_android_outlined,
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [AutofillHints.telephoneNumber],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                prefixWidget: CountryCodeDropdown(
                                  selectedCountry: _selectedCountry,
                                  isDarkMode: isDarkMode,
                                  textColor: isDarkMode ? Colors.white : Colors.black,
                                  dropdownBgColor: isDarkMode ? const Color(0xFF161510) : const Color(0xFFE8DFC5),
                                  onChanged: (newCountry) {
                                    setState(() {
                                      _selectedCountry = newCountry;
                                    });
                                  },
                                ),
                                onChanged: (value) {
                                  String body = value.trim();
                                  if (body.startsWith('+')) {
                                    for (var country in supportedCountries) {
                                      if (body.startsWith(country.code)) {
                                        setState(() {
                                          _selectedCountry = country;
                                        });
                                        final cleanBody = body.substring(country.code.length);
                                        _phoneController.value = TextEditingValue(
                                          text: cleanBody,
                                          selection: TextSelection.collapsed(offset: cleanBody.length),
                                        );
                                        break;
                                      }
                                    }
                                  } else if (body.startsWith('00')) {
                                    final cleanBody = '+${body.substring(2)}';
                                    for (var country in supportedCountries) {
                                      if (cleanBody.startsWith(country.code)) {
                                        setState(() {
                                          _selectedCountry = country;
                                        });
                                        final suffixBody = cleanBody.substring(country.code.length);
                                        _phoneController.value = TextEditingValue(
                                          text: suffixBody,
                                          selection: TextSelection.collapsed(offset: suffixBody.length),
                                        );
                                        break;
                                      }
                                    }
                                  }
                                },
                                textGrayColor: textGrayColor,
                                inputFillColor: inputFillColor,
                                isDarkMode: isDarkMode,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppTranslations.translate('field_required');
                                  }
                                  String body = value.trim();
                                  if (body.startsWith('0')) {
                                    body = body.substring(1);
                                  }
                                  if (body.length < 7 || body.length > 12) {
                                    return AppTranslations.translate('invalid_phone_format');
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Date of birth
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.translate('birth_date'),
                                    style: TextStyle(
                                      color: textGrayColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontFamily: getAppFontFamily(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTempleTextField(
                                          label: '',
                                          hint: 'DD',
                                          icon: Icons.calendar_today_outlined,
                                          controller: _dayController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          textGrayColor: textGrayColor,
                                          inputFillColor: inputFillColor,
                                          isDarkMode: isDarkMode,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return '!';
                                            }
                                            final day = int.tryParse(value);
                                            if (day == null || day < 1 || day > 31) {
                                              return '!';
                                            }

                                            final month = int.tryParse(
                                              _monthController.text,
                                            );
                                            final year = int.tryParse(
                                              _yearController.text,
                                            );

                                            if (month != null &&
                                                month >= 1 &&
                                                month <= 12) {
                                              final effectiveYear =
                                                  (year != null && year >= 1920)
                                                  ? year
                                                  : 2024;
                                              final maxDays =
                                                  DateUtils.getDaysInMonth(
                                                    effectiveYear,
                                                    month,
                                                  );
                                              if (day > maxDays) return '!';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTempleTextField(
                                          label: '',
                                          hint: 'MM',
                                          icon: Icons.calendar_month_outlined,
                                          controller: _monthController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          textGrayColor: textGrayColor,
                                          inputFillColor: inputFillColor,
                                          isDarkMode: isDarkMode,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return '!';
                                            }
                                            final month = int.tryParse(value);
                                            if (month == null ||
                                                month < 1 ||
                                                month > 12) {
                                              return '!';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildTempleTextField(
                                          label: '',
                                          hint: 'YYYY',
                                          icon: Icons.history_edu_outlined,
                                          controller: _yearController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          textGrayColor: textGrayColor,
                                          inputFillColor: inputFillColor,
                                          isDarkMode: isDarkMode,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return '!';
                                            }
                                            final year = int.tryParse(value);
                                            if (year == null || year < 1920) {
                                              return '!';
                                            }
                                            if (year > DateTime.now().year) {
                                              return '!';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 40),

                              // Submit Button
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: Temple_Gold,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Temple_Gold.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isLoading)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      else ...[
                                        Text(
                                          AppTranslations.translate('join_btn'),
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: getAppFontFamily(),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.keyboard_arrow_right,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTempleReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required Color textGrayColor,
    required Color inputFillColor,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              color: textGrayColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: getAppFontFamily(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: inputFillColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Temple_Muted_Gold.withOpacity(0.5), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDarkMode ? Colors.white54 : Colors.black45,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTempleTextField({
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    required TextEditingController controller,
    required Color textGrayColor,
    required Color inputFillColor,
    required bool isDarkMode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
    Widget? prefixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              color: textGrayColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: getAppFontFamily(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: getAppFontFamily(),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textGrayColor.withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: prefixWidget != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        icon,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      prefixWidget,
                      Container(
                        height: 24,
                        width: 1,
                        color: isDarkMode ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : Icon(
                    icon,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    size: 20,
                  ),
            suffixIcon: onToggleVisibility != null
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: inputFillColor,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Temple_Muted_Gold, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Temple_Muted_Gold, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Temple_Gold, width: 1.5),
            ),
            errorStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: getAppFontFamily(),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    bool isDarkMode,
    Color inputFillColor,
    Color textGrayColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheetBg = isDarkMode
            ? const Color(0xFF1A1914)
            : const Color(0xFFFBF5E6);
        final screenHeight = MediaQuery.of(context).size.height;

        return Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Temple_Muted_Gold.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Temple_Muted_Gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.translate('select_lang'),
                style: TextStyle(
                  color: Temple_Gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: getAppFontFamily(),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: selectedLanguageNotifier,
                builder: (ctx, selectedLang, _) {
                  return Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: kSupportedLanguages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final lang = kSupportedLanguages[i];
                        final isSelected = lang['name'] == selectedLang;
                        return GestureDetector(
                          onTap: () {
                            selectedLanguageNotifier.value = lang['name']!;
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Temple_Gold.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  lang['flag']!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Temple_Gold
                                        : (isDarkMode
                                            ? Colors.white70
                                            : Colors.black87),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontFamily: getAppFontFamily(),
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: Temple_Gold,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
