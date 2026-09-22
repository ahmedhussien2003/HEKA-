import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';
import '../../data/translations.dart';
import '../widget_tree.dart';
import '../widgets/Firebasehelper.dart';
import 'signup_page.dart';
import 'google_signup_page.dart';
import '../widgets/forgot_password_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _isLoginSelected = true;
  bool _obscurePassword = true;

  Future<void> _Sign_in_with_Google() async {
    setState(() => _isLoading = true);
    try {
      final UserCredential credential = await _firebaseHelper
          .signInWithGoogle();

      final user = credential.user;
      if (user == null) return;

      // Check if this user already has a Firestore profile.
      // We must check this BEFORE any Firestore writes (like saveUserLanguage)
      // because write operations with merge:true will automatically create
      // the document, causing userExists() to return true for brand new users.
      final alreadyExists = await _firestoreService.userExists(user.uid);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (alreadyExists) {
        // Save language preference (fire-and-forget) for existing user
        _firestoreService.saveUserLanguage(
          user.uid,
          selectedLanguageNotifier.value,
        );

        // ── Existing user: log in directly ──────────────────────────────
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WidgetTree()),
        );
      } else {
        // ── New user: collect the remaining profile info ─────────────────
        // (For new users, language preference is saved in GoogleSignupPage after completion)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GoogleSignupPage(googleUser: user)),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('cancelled')
            ? 'Google Sign-In was cancelled.'
            : 'Google Sign-In failed. Please try again.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential? credential;
      try {
        credential = await _firebaseHelper.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (authEx) {
        // Standard email/password login failed. Check if there's a custom password in Firestore!
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;
          final userData = userDoc.data();
          final String? customPassword = userData['customPassword'] as String?;

          if (customPassword != null && customPassword == password) {
            // Success! The custom password matches!
            // Sign in anonymously to get a valid authenticated session
            credential = await FirebaseAuth.instance.signInAnonymously();

            if (credential.user != null) {
              // Copy all user data to the new anonymous UID
              await _firestoreService.cloneUserData(
                userDoc.id,
                credential.user!.uid,
              );
              // Clean up: delete the old Firestore user data to keep it unique
              await _firestoreService.deleteUserData(userDoc.id);
            }
          } else {
            rethrow; // customPassword did not match, raise the original auth exception
          }
        } else {
          rethrow; // User doesn't exist in Firestore, raise original auth exception
        }
      }

      if (credential?.user != null) {
        // Save the chosen language to Firestore asynchronously (no await)
        // so it doesn't slow down the login process, and preserves their selection.
        _firestoreService.saveUserLanguage(
          credential!.user!.uid,
          selectedLanguageNotifier.value,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WidgetTree()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message ?? 'An unknown error occurred.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.translate('unexpected_error')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

            return Scaffold(
              backgroundColor: backgroundColor,
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
                        horizontal: screenWidth * 0.08,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Top bar: dark-mode toggle + language picker
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Language picker
                                ValueListenableBuilder<String>(
                                  valueListenable: selectedLanguageNotifier,
                                  builder: (context, selectedLang, _) {
                                    final langData = kSupportedLanguages
                                        .firstWhere(
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
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
                                // Dark mode toggle
                                IconButton(
                                  icon: Icon(
                                    isDarkMode
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                                    color: Temple_Gold,
                                  ),
                                  onPressed: () {
                                    isDarkModeNotifier.value =
                                        !isDarkModeNotifier.value;
                                  },
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
                              AppTranslations.translate('login_title'),
                              style: TextStyle(
                                color: Temple_Gold,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontFamily: getAppFontFamily(),
                              ),
                            ),
                            Text(
                              AppTranslations.translate('login_subtitle'),
                              style: TextStyle(
                                color: textGrayColor.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4,
                                fontFamily: getAppFontFamily(),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Toggle Login/Signup
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: inputFillColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Temple_Muted_Gold,
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedAlign(
                                    alignment: _isLoginSelected
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Container(
                                          width: constraints.maxWidth / 2,
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Temple_Gold,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Temple_Gold.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() {
                                            _isLoginSelected = true;
                                            _formKey.currentState?.reset();
                                          }),
                                          child: Center(
                                            child: Text(
                                              AppTranslations.translate(
                                                'login',
                                              ),
                                              style: TextStyle(
                                                color: _isLoginSelected
                                                    ? Colors.black
                                                    : textGrayColor,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: getAppFontFamily(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(
                                              () => _isLoginSelected = false,
                                            );
                                            if (mounted) {
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder:
                                                      (
                                                        context,
                                                        animation,
                                                        secondaryAnimation,
                                                      ) => const SignupPage(),
                                                  transitionsBuilder:
                                                      (
                                                        context,
                                                        animation,
                                                        secondaryAnimation,
                                                        child,
                                                      ) => FadeTransition(
                                                        opacity:
                                                            CurvedAnimation(
                                                              parent: animation,
                                                              curve: Curves
                                                                  .easeInOut,
                                                            ),
                                                        child: child,
                                                      ),
                                                  transitionDuration:
                                                      const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                ),
                                              ).then((_) {
                                                if (mounted) {
                                                  setState(
                                                    () =>
                                                        _isLoginSelected = true,
                                                  );
                                                }
                                              });
                                            }
                                          },
                                          child: Center(
                                            child: Text(
                                              AppTranslations.translate(
                                                'signup',
                                              ),
                                              style: TextStyle(
                                                color: !_isLoginSelected
                                                    ? Colors.black
                                                    : textGrayColor,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: getAppFontFamily(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Input Fields
                            _buildTempleTextField(
                              label: AppTranslations.translate('email_label'),
                              hint: AppTranslations.translate('email_hint'),
                              icon: Icons.alternate_email,
                              controller: _emailController,
                              textGrayColor: textGrayColor,
                              inputFillColor: inputFillColor,
                              isDarkMode: isDarkMode,
                              validator: (value) => value!.isEmpty
                                  ? AppTranslations.translate('field_required')
                                  : null,
                            ),

                            const SizedBox(height: 20),

                            _buildTempleTextField(
                              label: AppTranslations.translate(
                                'password_label',
                              ),
                              hint: AppTranslations.translate('password_hint'),
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              controller: _passwordController,
                              textGrayColor: textGrayColor,
                              inputFillColor: inputFillColor,
                              isDarkMode: isDarkMode,
                              onToggleVisibility: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              validator: (value) => value!.length < 6
                                  ? AppTranslations.translate(
                                      'password_too_short',
                                    )
                                  : null,
                            ),

                            const SizedBox(height: 20),

                            Align(
                              alignment:
                                  selectedLanguageNotifier.value == 'Arabic'
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => ForgotPasswordDialog(
                                      isDarkMode: isDarkMode,
                                    ),
                                  );
                                },
                                child: Text(
                                  AppTranslations.translate(
                                    'forgot_password_question',
                                  ),
                                  style: TextStyle(
                                    color: Temple_Gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: getAppFontFamily(),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Action Button
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
                                onPressed: _isLoading ? null : _handleAuth,
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

                            const SizedBox(height: 30),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: Temple_Muted_Gold),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    AppTranslations.translate(
                                      'ancient_connection',
                                    ),
                                    style: TextStyle(
                                      color: textGrayColor.withOpacity(0.6),
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: getAppFontFamily(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Temple_Muted_Gold),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // Social Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      _Sign_in_with_Google();
                                    },
                                    child: _buildSocialButton(
                                      label: 'Google',
                                      logo: Image.asset(
                                        'assets/images/google_logo.png',
                                        width: 22,
                                        height: 22,
                                      ),
                                      isDarkMode: isDarkMode,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildSocialButton(
                                    label: 'Apple',
                                    icon: Icons.apple,
                                    isDarkMode: isDarkMode,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppTranslations.translate('no_account'),
                                  style: TextStyle(
                                    color: textGrayColor.withOpacity(0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: getAppFontFamily(),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignupPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    AppTranslations.translate('signup_btn'),
                                    style: TextStyle(
                                      color: Temple_Gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      fontFamily: getAppFontFamily(),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: textGrayColor,
                                  fontSize: (screenWidth * 0.025).clamp(10, 12),
                                  fontFamily: getAppFontFamily(),
                                ),
                                children: [
                                  TextSpan(
                                    text: AppTranslations.translate(
                                      'terms_prefix',
                                    ),
                                    style: TextStyle(
                                      color: textGrayColor,
                                      fontSize: (screenWidth * 0.025).clamp(
                                        10,
                                        12,
                                      ),
                                      fontFamily: getAppFontFamily(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: AppTranslations.translate(
                                      'scroll_of_terms',
                                    ),
                                    style: const TextStyle(
                                      color: Temple_Gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: AppTranslations.translate(
                                      'terms_and',
                                    ),
                                    style: TextStyle(
                                      color: textGrayColor,
                                      fontSize: (screenWidth * 0.025).clamp(
                                        10,
                                        12,
                                      ),
                                      fontFamily: getAppFontFamily(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: AppTranslations.translate(
                                      'privacy_decree',
                                    ),
                                    style: const TextStyle(
                                      color: Temple_Gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.03),

                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF1E1C14)
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Temple_Muted_Gold,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Temple_Gold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppTranslations.translate(
                                      'ar_recognition_ready',
                                    ),
                                    style: TextStyle(
                                      color: Temple_Gold,
                                      fontSize: (screenWidth * 0.025).clamp(
                                        8,
                                        10,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontFamily: getAppFontFamily(),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.04),
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

  void _showLanguagePicker(
    BuildContext context,
    bool isDarkMode,
    Color inputFillColor,
    Color textGrayColor,
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
                                            ? Temple_Gold
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
                                  const Icon(
                                    Icons.check_circle,
                                    color: Temple_Gold,
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

  Widget _buildTempleTextField({
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    required TextEditingController controller,
    required Color textGrayColor,
    required Color inputFillColor,
    required bool isDarkMode,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        TextFormField(
          controller: controller,
          obscureText: obscureText,
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
            prefixIcon: Icon(
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

  Widget _buildSocialButton({
    required String label,
    Widget? logo,
    IconData? icon,
    required bool isDarkMode,
  }) {
    final inputFillColor = isDarkMode
        ? Temple_Input_Fill_Dark
        : Temple_Input_Fill_Light;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Muted_Gold, width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (logo != null) logo,
            if (icon != null) Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
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
