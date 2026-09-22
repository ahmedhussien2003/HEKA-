import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import 'about_us_page.dart';
import 'editProfile_page.dart';
import 'login_page.dart';
import 'faqs_page.dart';
import 'privacy_policy_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../data/translations.dart';
import '../widgets/password_verification_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // bool _notificationsEnabled = false;
  final FirestoreService _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  User? _user;
  String _userName = 'Loading...';
  String _userEmail = 'Loading...';
  String _userPhone = '';
  int _translationCount = 0;
  int _savedGlyphsCount = 0;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      try {
        final DocumentSnapshot userData = await _firestoreService.getUserData(
          _user!.uid,
        );
        if (!mounted) return;
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          _setStateIfMounted(() {
            _userName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}';
            _userEmail = data['email'] ?? 'No email';
            _userPhone = data['phoneNumber'] ?? '';
            _translationCount = data['translationCount'] ?? 0;
            _savedGlyphsCount = data['savedGlyphsCount'] ?? 0;

            // Set the selected language notifier from Firestore
            if (data['preferredLanguage'] != null) {
              selectedLanguageNotifier.value = data['preferredLanguage'];
            }
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
        _setStateIfMounted(() {
          _userName = 'Guest';
          _userEmail = '';
        });
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

            return Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  AppTranslations.translate('profile_settings'),
                  style: TextStyle(
                    color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
                    fontSize: (screenWidth * 0.045).clamp(16, 20),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
                centerTitle: true,
              ),
              body: Container(
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
                        horizontal: screenWidth * 0.05,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Avatar Section
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Temple_Gold,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: (screenWidth * 0.12).clamp(40, 60),
                                    backgroundColor: inputFillColor,
                                    backgroundImage: const AssetImage(
                                      'assets/images/Ahmad_Hussien.jpeg',
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Temple_Gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: backgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _userName,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : Temple_Text_Gray_Light,
                              fontSize: (screenWidth * 0.06).clamp(20, 28),
                              fontWeight: FontWeight.bold,
                              fontFamily: getAppFontFamily(),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Stats Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatCard(
                                _translationCount.toString(),
                                AppTranslations.translate('scans'),
                                inputFillColor,
                                isDarkMode,
                                screenWidth,
                              ),
                              _buildStatCard(
                                _savedGlyphsCount.toString(),
                                AppTranslations.translate('saved'),
                                inputFillColor,
                                isDarkMode,
                                screenWidth,
                              ), // Hardcoded for now as per design mockup
                              _buildStatCard(
                                '98%',
                                AppTranslations.translate('success'),
                                inputFillColor,
                                isDarkMode,
                                screenWidth,
                              ), // Hardcoded for now
                            ],
                          ),
                          const SizedBox(height: 35),

                          // Account Details
                          _buildSectionHeader(
                            AppTranslations.translate('account_details'),
                            isDarkMode,
                          ),
                          _buildMenuCard(
                            icon: Icons.person_add_alt_1,
                            title: AppTranslations.translate('edit_profile'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EditProfilePage(),
                                ),
                              ).then(
                                (_) => _loadUserData(),
                              ); // Refresh data when returning
                            },
                            fillColor: inputFillColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCard(
                            icon: Icons.lock_outline,
                            title: AppTranslations.translate('change_password'),
                            onTap: () {
                              if (_userPhone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppTranslations.translate(
                                        'no_phone_error',
                                      ),
                                    ),
                                    backgroundColor: Temple_Carnelian,
                                  ),
                                );
                              } else {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) =>
                                      ChangePasswordVerificationDialog(
                                        userPhone: _userPhone,
                                        isDarkMode: isDarkMode,
                                      ),
                                );
                              }
                            },
                            fillColor: inputFillColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 35),

                          // Appearance
                          _buildSectionHeader(
                            AppTranslations.translate('appearance'),
                            isDarkMode,
                          ),
                          _buildThemeSelector(isDarkMode, inputFillColor),
                          const SizedBox(height: 35),

                          // Preferences
                          _buildSectionHeader(
                            AppTranslations.translate('preferences'),
                            isDarkMode,
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: selectedLanguageNotifier,
                            builder: (context, lang, _) {
                              return _buildMenuCard(
                                icon: Icons.language,
                                title: AppTranslations.translate('language'),
                                trailingText: lang,
                                onTap: () => _showLanguagePicker(
                                  context,
                                  isDarkMode,
                                  inputFillColor,
                                ),
                                fillColor: inputFillColor,
                                isDarkMode: isDarkMode,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<bool>(
                            valueListenable: showArabicEnglishNotifier,
                            builder: (context, showArEn, _) {
                              return _buildToggleMenuCard(
                                icon: Icons.translate,
                                title: AppTranslations.translate(
                                  'appear_ar_en_statements',
                                ),
                                value: showArEn,
                                onChanged: (val) =>
                                    showArabicEnglishNotifier.value = val,
                                fillColor: inputFillColor,
                                isDarkMode: isDarkMode,
                              );
                            },
                          ),
                          const SizedBox(height: 35),

                          // Support & Info
                          _buildSectionHeader(
                            AppTranslations.translate('support_info'),
                            isDarkMode,
                          ),
                          _buildMenuCard(
                            icon: Icons.privacy_tip_outlined,
                            title: AppTranslations.translate('privacy_policy'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PrivacyPolicyPage(),
                                ),
                              );
                            },
                            fillColor: inputFillColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 1),
                          _buildMenuCard(
                            icon: Icons.quiz_outlined,
                            title: AppTranslations.translate('faqs'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FaqsPage(),
                                ),
                              );
                            },
                            fillColor: inputFillColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 1),
                          _buildMenuCard(
                            icon: Icons.info_outline,
                            title: AppTranslations.translate('about_us'),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const AboutUsPage(),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            fillColor: inputFillColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 40),

                          // Logout Button
                          Container(
                            width: double.infinity,
                            height: (screenWidth * 0.14).clamp(50, 60),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2D1410)
                                  : const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF4D2018)
                                    : const Color(0xFFF8B4B4),
                                width: 1,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: isDarkMode
                                          ? const Color(0xFF1A1914)
                                          : Colors.white,
                                      title: Text(
                                        AppTranslations.translate(
                                          'logout_title',
                                        ),
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Temple_Gold
                                              : const Color(0xFF9E7E0D),
                                          fontFamily: getAppFontFamily(),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        AppTranslations.translate('logout_msg'),
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Temple_Text_Gray_Light,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: getAppFontFamily(),
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text(
                                            AppTranslations.translate('cancel'),
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black54,
                                              fontFamily: getAppFontFamily(),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                        TextButton(
                                          child: Text(
                                            AppTranslations.translate(
                                              'logout_title',
                                            ),
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontFamily: getAppFontFamily(),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              await FirebaseAuth.instance
                                                  .signOut();
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                Navigator.of(
                                                  context,
                                                ).pushReplacement(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const LoginPage(),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Failed to logout. Please try again.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              label: Text(
                                AppTranslations.translate('logout'),
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  fontFamily: getAppFontFamily(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            '${AppTranslations.translate('version')} 1.0.0',
                            style: TextStyle(
                              color: textGrayColor.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              fontFamily: getAppFontFamily(),
                            ),
                          ),
                          const SizedBox(
                            height: 120,
                          ), // Spacer for floating navbar
                        ],
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

  Widget _buildStatCard(
    String value,
    String label,
    Color fillColor,
    bool isDarkMode,
    double screenWidth,
  ) {
    return Container(
      width: (screenWidth * 0.28).clamp(80, 120),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Muted_Gold.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Temple_Gold : const Color(0xFF9E7E0D),
              fontSize: (screenWidth * 0.045).clamp(16, 20),
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDarkMode
                  ? Temple_Text_Gray_Dark
                  : Temple_Text_Gray_Light.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: getAppFontFamily(),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
    required Color fillColor,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Muted_Gold.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Temple_Gold.withOpacity(0.15)
                : Temple_Gold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Temple_Text_Gray_Light,
            fontSize: (MediaQuery.of(context).size.width * 0.04).clamp(14, 17),
            fontWeight: FontWeight.w600,
            fontFamily: getAppFontFamily(),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: TextStyle(
                  color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isDarkMode
                  ? Colors.white54
                  : Temple_Text_Gray_Light.withOpacity(0.5),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildToggleMenuCard({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color fillColor,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Muted_Gold.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Temple_Gold.withOpacity(0.15)
                : Temple_Gold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Temple_Text_Gray_Light,
            fontSize: (MediaQuery.of(context).size.width * 0.04).clamp(14, 17),
            fontWeight: FontWeight.w600,
            fontFamily: getAppFontFamily(),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
          activeTrackColor: (isDarkMode ? Temple_Gold : const Color(0xFF8C620A))
              .withOpacity(0.4),
          inactiveThumbColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          inactiveTrackColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    bool isDarkMode,
    Color inputFillColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow custom height
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheetBg = isDarkMode
            ? const Color(0xFF1A1914)
            : const Color(0xFFFBF5E6);
        final screenHeight = MediaQuery.of(context).size.height;

        return Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8, // Prevent overflow
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
                AppTranslations.translate('select_language_title'),
                style: TextStyle(
                  color: isDarkMode ? Temple_Gold : const Color(0xFF8C620A),
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
                          onTap: () async {
                            final previousLang = selectedLanguageNotifier.value;
                            selectedLanguageNotifier.value = lang['name']!;

                            if (_user != null) {
                              try {
                                await _firestoreService.saveUserLanguage(
                                  _user!.uid,
                                  lang['name']!,
                                );
                              } catch (e) {
                                selectedLanguageNotifier.value = previousLang;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to save language preference.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Temple_Gold.withOpacity(0.12)
                                  : inputFillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Temple_Gold
                                    : Temple_Muted_Gold.withOpacity(0.3),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  lang['flag']!,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang['name']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDarkMode
                                                  ? Temple_Gold
                                                  : const Color(0xFF8C620A))
                                            : (isDarkMode
                                                  ? Colors.white
                                                  : Temple_Text_Gray_Light),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        fontFamily: getAppFontFamily(),
                                      ),
                                    ),
                                    Text(
                                      lang['native']!,
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.9)
                                            : Temple_Text_Gray_Light,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: getAppFontFamily(),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: isDarkMode
                                        ? Temple_Gold
                                        : const Color(0xFF8C620A),
                                    size: 20,
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

  Widget _buildThemeSelector(bool isDarkMode, Color fillColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Muted_Gold.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: Temple_Gold, size: 20),
              SizedBox(width: 10),
              Text(
                AppTranslations.translate('profile_display_theme'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Temple_Text_Gray_Light,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: getAppFontFamily(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  title: AppTranslations.translate('profile_theme_light'),
                  icon: Icons.light_mode_outlined,
                  isSelected: !isDarkMode,
                  onTap: () => isDarkModeNotifier.value = false,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeCard(
                  title: AppTranslations.translate('profile_theme_dark'),
                  icon: Icons.dark_mode_outlined,
                  isSelected: isDarkMode,
                  onTap: () => isDarkModeNotifier.value = true,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.transparent : Colors.black12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Temple_Gold
                : Temple_Muted_Gold.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8DFC5)
                    : const Color(0xFF1A1914),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Temple_Gold,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? (isDarkMode ? Colors.white : Temple_Text_Gray_Light)
                    : (isDarkMode
                          ? Colors.white54
                          : Temple_Text_Gray_Light.withOpacity(0.5)),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
