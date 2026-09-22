import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';
import '../../data/translations.dart';
import '../widgets/country_code_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  User? _user;

  CountryInfo _selectedCountry =
      supportedCountries.first; // Egypt (+20) by default

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot userData = await _firestoreService.getUserData(
          _user!.uid,
        );
        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              // Set the selected language notifier from Firestore
              if (data['preferredLanguage'] != null) {
                selectedLanguageNotifier.value = data['preferredLanguage'];
              }
              _firstNameController.text = data['firstName'] ?? '';
              _lastNameController.text = data['lastName'] ?? '';
              _emailController.text = data['email'] ?? '';

              String fullPhone = data['phoneNumber'] ?? '';
              if (fullPhone.isNotEmpty) {
                bool found = false;
                for (var country in supportedCountries) {
                  if (fullPhone.startsWith(country.code)) {
                    _selectedCountry = country;
                    _phoneController.text = fullPhone.substring(
                      country.code.length,
                    );
                    found = true;
                    break;
                  }
                }
                if (!found) {
                  _phoneController.text = fullPhone;
                }
              } else {
                _phoneController.text = '';
              }

              List<String> birthDateParts = (data['birthDate'] ?? '').split(
                '/',
              );
              if (birthDateParts.length == 3) {
                _dayController.text = birthDateParts[0];
                _monthController.text = birthDateParts[1];
                _yearController.text = birthDateParts[2];
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  int _getMaxDays(int month, int year) {
    if (month == 2) {
      return _isLeapYear(year) ? 29 : 28;
    }
    if ([4, 6, 9, 11].contains(month)) {
      return 30;
    }
    return 31;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_user != null) {
      try {
        String body = _phoneController.text.trim();
        if (body.startsWith('0')) {
          body = body.substring(1);
        }
        final fullPhone = '${_selectedCountry.code}$body';

        Map<String, dynamic> updatedData = {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'email': _emailController.text,
          'phoneNumber': fullPhone,
          'birthDate':
              '${_dayController.text}/${_monthController.text}/${_yearController.text}',
        };
        await _firestoreService.updateUserData(_user!.uid, updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.translate('profile_updated'))),
        );

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.translate('update_failed')}: $e'),
          ),
        );
      }
    }
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
            final fontColor = isDarkMode
                ? Font_Color_dark_mode
                : Font_Color_light_mode;
            final borderColor = isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[300]!;
            final gradientCenterColor = isDarkMode
                ? const Color(0xFF2A2616)
                : const Color(0xFFE8DFC5);

            return Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFFD4AF37),
                  ), // Gold color for back arrow
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  AppTranslations.translate('edit_profile'),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
              body: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 3,
                    colors: [gradientCenterColor, backgroundColor],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: screenHeight * 0.025),
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: screenWidth * 0.18,
                                    backgroundImage: const AssetImage(
                                      'assets/images/Ahmad_Hussien.jpeg',
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4AF37),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: screenHeight * 0.04),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: AppTranslations.translate(
                                      'first_name',
                                    ),
                                    controller: _firstNameController,
                                    fontColor: fontColor,
                                    borderColor: borderColor,
                                    screenWidth: screenWidth,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    label: AppTranslations.translate(
                                      'last_name',
                                    ),
                                    controller: _lastNameController,
                                    fontColor: fontColor,
                                    borderColor: borderColor,
                                    screenWidth: screenWidth,
                                  ),
                                ),
                              ],
                            ),
                            _buildTextField(
                              label: AppTranslations.translate('email_label'),
                              controller: _emailController,
                              fontColor: fontColor,
                              borderColor: borderColor,
                              enabled: false,
                              prefixIcon: Icons.email,
                              screenWidth: screenWidth,
                            ),
                            _buildTextField(
                              label: AppTranslations.translate('phone'),
                              controller: _phoneController,
                              fontColor: fontColor,
                              borderColor: borderColor,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone,
                              screenWidth: screenWidth,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              hintText: '10 1234 5678',
                              prefixWidget: CountryCodeDropdown(
                                selectedCountry: _selectedCountry,
                                isDarkMode: isDarkMode,
                                textColor: fontColor,
                                dropdownBgColor: isDarkMode
                                    ? const Color(0xFF1B1F22)
                                    : const Color(0xFFF7F0E8),
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
                                      final cleanBody = body.substring(
                                        country.code.length,
                                      );
                                      _phoneController.value = TextEditingValue(
                                        text: cleanBody,
                                        selection: TextSelection.collapsed(
                                          offset: cleanBody.length,
                                        ),
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
                                      final suffixBody = cleanBody.substring(
                                        country.code.length,
                                      );
                                      _phoneController.value = TextEditingValue(
                                        text: suffixBody,
                                        selection: TextSelection.collapsed(
                                          offset: suffixBody.length,
                                        ),
                                      );
                                      break;
                                    }
                                  }
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppTranslations.translate(
                                    'field_required',
                                  );
                                }
                                String body = value.trim();
                                if (body.startsWith('0')) {
                                  body = body.substring(1);
                                }
                                if (body.length < 7 || body.length > 12) {
                                  return AppTranslations.translate(
                                    'invalid_phone_format',
                                  );
                                }
                                return null;
                              },
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.translate('birth_date'),
                                  style: TextStyle(
                                    color: fontColor.withOpacity(0.7),
                                    fontSize: (screenWidth * 0.035)
                                        .roundToDouble(),
                                    fontFamily: getAppFontFamily(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildShortTextField(
                                        controller: _dayController,
                                        fontColor: fontColor,
                                        borderColor: borderColor,
                                        hintText: 'DD',
                                        screenWidth: screenWidth,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return '??';
                                          }
                                          final day = int.tryParse(value);
                                          if (day == null ||
                                              day < 1 ||
                                              day > 31) {
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
                                            final maxDays = _getMaxDays(
                                              month,
                                              year ?? 2024,
                                            );
                                            if (day > maxDays) {
                                              return 'Max $maxDays';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildShortTextField(
                                        controller: _monthController,
                                        fontColor: fontColor,
                                        borderColor: borderColor,
                                        hintText: 'MM',
                                        screenWidth: screenWidth,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return '??';
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildShortTextField(
                                        controller: _yearController,
                                        fontColor: fontColor,
                                        borderColor: borderColor,
                                        hintText: 'YYYY',
                                        screenWidth: screenWidth,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return '??';
                                          }
                                          final year = int.tryParse(value);
                                          if (year == null) return '!';
                                          if (year < 1940) return '>= 1940';
                                          if (year > DateTime.now().year) {
                                            return 'Future';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                            const SizedBox(height: 35),
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: _updateProfile,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.save_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppTranslations.translate('save_changes'),
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: (screenWidth * 0.045)
                                            .roundToDouble(),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: getAppFontFamily(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            Text(
                              '${AppTranslations.translate('edit_verified_by')} Ahmad',
                              style: TextStyle(
                                color: fontColor.withOpacity(0.4),
                                fontSize: (screenWidth * 0.025).roundToDouble(),
                                fontFamily: getAppFontFamily(),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.025),
                          ],
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    required Color fontColor,
    required Color borderColor,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    required double screenWidth,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    String? hintText,
    Widget? prefixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: fontColor.withOpacity(0.7),
            fontSize: (screenWidth * 0.03).roundToDouble(),
            fontFamily: getAppFontFamily(),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          style: TextStyle(
            color: fontColor,
            fontFamily: getAppFontFamily(),
            fontWeight: FontWeight.w600,
            fontSize: (screenWidth * 0.035).roundToDouble(),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            hintText: hintText,
            hintStyle: TextStyle(
              color: fontColor.withOpacity(0.3),
              fontSize: (screenWidth * 0.035).roundToDouble(),
            ),
            prefixIcon: prefixWidget != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      if (prefixIcon != null)
                        Icon(
                          prefixIcon,
                          color: const Color(0xFFD4AF37),
                          size: 20,
                        ),
                      const SizedBox(width: 4),
                      prefixWidget,
                      Container(
                        height: 24,
                        width: 1,
                        color: fontColor.withOpacity(0.2),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : (prefixIcon != null
                      ? Icon(
                          prefixIcon,
                          color: const Color(0xFFD4AF37),
                          size: 20,
                        )
                      : null),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD4AF37), // Use Gold color for better clarity
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFFD4AF37).withOpacity(0.6),
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor.withOpacity(0.1),
                width: 1.0,
              ),
            ),
            errorStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: getAppFontFamily(),
            ),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShortTextField({
    required TextEditingController controller,
    required Color fontColor,
    required Color borderColor,
    String? hintText,
    required double screenWidth,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: fontColor,
        fontFamily: getAppFontFamily(),
        fontWeight: FontWeight.w600,
        fontSize: (screenWidth * 0.035).roundToDouble(),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: fontColor.withOpacity(0.3),
          fontSize: (screenWidth * 0.035).roundToDouble(),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFD4AF37).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        errorStyle: const TextStyle(fontSize: 10, height: 0.8),
        errorMaxLines: 1,
      ),
      validator: validator,
    );
  }
}
