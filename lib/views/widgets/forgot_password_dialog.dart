import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/translations.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import 'password_verification_dialog.dart'; // For SmsOverlayHelper

enum ForgotPasswordStep { enterDetails, enterNewPassword }

class ForgotPasswordDialog extends StatefulWidget {
  final bool isDarkMode;

  const ForgotPasswordDialog({super.key, required this.isDarkMode});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterDetails;
  bool _codeSent = false;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  String _userPhone = '';
  String _userUid = '';

  // OTP Verification variables
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isSimulated = false;
  String _generatedCode = '';
  String _verificationId = '';

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();

    // Clean up anonymous session if the user exits before resetting password
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.isAnonymous) {
      FirebaseAuth.instance.signOut();
    }
    super.dispose();
  }

  void _startSimulatedOtp(String warningMessage) {
    debugPrint("Warning: $warningMessage");

    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();

    setState(() {
      _isSimulated = true;
      _generatedCode = code;
      _verificationId = '';
      _secondsRemaining = 60;
      _errorMessage = AppTranslations.translate('billing_not_enabled_simulated');
      _isLoading = false;
      _otpController.clear();
      _codeSent = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _errorMessage = AppTranslations.translate('otp_expired');
        });
        _timer?.cancel();
      }
    });

    final smsMsg = AppTranslations.translate(
      'otp_sms_simulated',
    ).replaceAll('{code}', code);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmsOverlayHelper.showSimulatedSms(
        context: context,
        message: smsMsg,
        isDarkMode: widget.isDarkMode,
      );
    });
  }

  Future<void> _checkEmailAndSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      // Attempt anonymous authentication first if not already authenticated
      // to satisfy "request.auth != null" constraints on Firestore rules.
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (e) {
          debugPrint("Failed to sign in anonymously: $e");
        }
      }

      // Look up email in Firestore to get phone number and UID
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = AppTranslations.translate('email_not_registered');
          _isLoading = false;
        });
        return;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final phone = data['phoneNumber'] as String? ?? '';

      if (phone.isEmpty) {
        setState(() {
          _errorMessage = AppTranslations.translate('no_phone_linked');
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _userPhone = phone;
        _userUid = doc.id;
      });

      // Now send the verification code to the retrieved phone number
      _sendOtp();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _otpController.clear();
      _isSimulated = false;
    });

    String formattedPhone = _userPhone.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+20${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+20$formattedPhone';
      }
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          try {
            final UserCredential userCred = await FirebaseAuth.instance
                .signInWithCredential(credential);
            if (userCred.user != null) {
              await FirebaseAuth.instance.signOut();
            }

            _timer?.cancel();
            setState(() {
              _currentStep = ForgotPasswordStep.enterNewPassword;
              _errorMessage = null;
              _isLoading = false;
            });
          } catch (e) {
            setState(() {
              _errorMessage = e.toString();
              _isLoading = false;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          final errMsg = e.message ?? e.toString();
          final lowCaseMsg = errMsg.toLowerCase();
          final lowCaseCode = e.code.toLowerCase();

          if (lowCaseMsg.contains('billing') ||
              lowCaseMsg.contains('billing_not_enabled') ||
              lowCaseCode.contains('billing')) {
            _startSimulatedOtp(errMsg);
          } else {
            setState(() {
              _errorMessage = errMsg;
              _isLoading = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _secondsRemaining = 60;
            _errorMessage = null;
            _isLoading = false;
            _codeSent = true;
          });

          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_secondsRemaining > 0) {
              setState(() {
                _secondsRemaining--;
              });
            } else {
              setState(() {
                _errorMessage = AppTranslations.translate('otp_expired');
              });
              _timer?.cancel();
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString();
        final lowCaseMsg = errMsg.toLowerCase();
        if (lowCaseMsg.contains('billing') ||
            lowCaseMsg.contains('billing_not_enabled')) {
          _startSimulatedOtp(errMsg);
        } else {
          setState(() {
            _errorMessage = errMsg;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_secondsRemaining == 0) {
      setState(() {
        _errorMessage = AppTranslations.translate('otp_expired');
      });
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = AppTranslations.translate('otp_invalid');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isSimulated) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (otp == _generatedCode) {
        _timer?.cancel();
        setState(() {
          _currentStep = ForgotPasswordStep.enterNewPassword;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = AppTranslations.translate('otp_invalid');
        });
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (userCred.user != null) {
        await FirebaseAuth.instance.signOut();
      }

      _timer?.cancel();
      setState(() {
        _currentStep = ForgotPasswordStep.enterNewPassword;
        _errorMessage = null;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? AppTranslations.translate('otp_invalid');
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPassword = _newPassController.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(_userUid).set({
        'customPassword': newPassword,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTranslations.translate('password_changed_success'),
            ),
            backgroundColor: Temple_Teal,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetEmailStep() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _isSimulated = false;
      _otpController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isArabic = selectedLanguageNotifier.value == 'Arabic';

    final dialogBg = widget.isDarkMode ? const Color(0xFF1A1914) : Colors.white;
    final textGray = widget.isDarkMode
        ? Temple_Text_Gray_Dark
        : Temple_Text_Gray_Light;
    final textColor = widget.isDarkMode ? Colors.white : Temple_Black;
    final inputFill = widget.isDarkMode
        ? Temple_Input_Fill_Dark
        : Temple_Input_Fill_Light;
    final textHeadingColor = widget.isDarkMode
        ? Temple_Gold
        : const Color(0xFF9E7E0D);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Temple_Gold, width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentStep == ForgotPasswordStep.enterDetails
                ? _buildDetailsStep(
                    isArabic,
                    textHeadingColor,
                    textColor,
                    textGray,
                    inputFill,
                    screenWidth,
                  )
                : _buildPasswordStep(
                    isArabic,
                    textHeadingColor,
                    textColor,
                    textGray,
                    inputFill,
                    screenWidth,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(
    bool isArabic,
    Color headingColor,
    Color textColor,
    Color textGray,
    Color inputFill,
    double screenWidth,
  ) {
    final title = AppTranslations.translate('forgot_password_title');
    final btnText = _codeSent
        ? AppTranslations.translate('otp_verify_btn')
        : AppTranslations.translate('send_code_btn');
    final cancelText = AppTranslations.translate('cancel');

    final timerColor = _secondsRemaining > 10 ? Temple_Gold : Temple_Carnelian;
    final countdownText = AppTranslations.translate(
      'otp_seconds_remaining',
    ).replaceAll('{seconds}', _secondsRemaining.toString());

    String maskedPhone = _userPhone;
    if (_userPhone.length > 4) {
      final prefix = _userPhone.substring(0, min(4, _userPhone.length));
      final suffix = _userPhone.substring(max(0, _userPhone.length - 4));
      maskedPhone = "$prefix******$suffix";
    }

    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('details_step'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: headingColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
              if (_codeSent) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppTranslations.translate('demo_mode'),
                      style: TextStyle(
                        color: _isSimulated ? Temple_Gold : textGray,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: getAppFontFamily(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 30,
                      width: 38,
                      child: Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: _isSimulated,
                          activeColor: Temple_Gold,
                          activeTrackColor: Temple_Glow_Gold,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            if (val) {
                              _startSimulatedOtp(
                                "Switched to Demo Mode manually.",
                              );
                            } else {
                              _sendOtp();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              IconButton(
                icon: Icon(Icons.close, color: textGray, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: AppTranslations.translate('close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _codeSent
                ? "${AppTranslations.translate('otp_dialog_subtitle')}: $maskedPhone"
                : AppTranslations.translate('forgot_password_subtitle'),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              height: 1.4,
              fontFamily: getAppFontFamily(),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_codeSent, // Lock email field when OTP is sent
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: _codeSent ? textGray : textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
            decoration: InputDecoration(
              hintText: AppTranslations.translate('email_hint'),
              hintStyle: TextStyle(
                color: textGray.withOpacity(0.5),
                fontSize: 13,
              ),
              prefixIcon: Icon(Icons.email_outlined, color: textGray, size: 20),
              filled: true,
              fillColor: _codeSent
                  ? (widget.isDarkMode ? Colors.black26 : Colors.grey[200])
                  : inputFill,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.grey[800]!
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Temple_Gold, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppTranslations.translate('field_required');
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return AppTranslations.translate('invalid_email');
              }
              return null;
            },
          ),

          if (_codeSent) ...[
            Align(
              alignment: isArabic
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetEmailStep,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppTranslations.translate('change_email'),
                  style: const TextStyle(
                    color: Temple_Gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic SMS OTP Verification Code field
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: getAppFontFamily(),
              ),
              decoration: InputDecoration(
                counterText: "",
                hintText: "• • • • • •",
                hintStyle: TextStyle(
                  color: textGray.withOpacity(0.4),
                  fontSize: 16,
                  letterSpacing: 4,
                ),
                prefixIcon: Icon(Icons.lock_clock, color: textGray, size: 20),
                filled: true,
                fillColor: inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Temple_Muted_Gold,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Temple_Muted_Gold,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Temple_Gold, width: 1.5),
                ),
              ),
              onChanged: (val) {
                if (val.length == 6) {
                  _verifyOtp();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: timerColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  countdownText,
                  style: TextStyle(
                    color: timerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ],
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: isArabic ? TextAlign.right : TextAlign.center,
              style: const TextStyle(
                color: Temple_Carnelian,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_codeSent) ...[
                TextButton(
                  onPressed: (_secondsRemaining == 0 && !_isLoading)
                      ? (_isSimulated
                            ? () =>
                                  _startSimulatedOtp("Resending simulated OTP")
                            : _sendOtp)
                      : null,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppTranslations.translate('otp_resend'),
                    style: TextStyle(
                      color: (_secondsRemaining == 0 && !_isLoading)
                          ? Temple_Gold
                          : textGray.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontFamily: getAppFontFamily(),
                    ),
                  ),
                ),
              ],
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  cancelText,
                  style: TextStyle(
                    color: textGray,
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_codeSent ? _verifyOtp : _checkEmailAndSendOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Temple_Gold,
                  foregroundColor: Temple_Black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Temple_Black,
                          ),
                        ),
                      )
                    : Text(
                        btnText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: getAppFontFamily(),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(
    bool isArabic,
    Color headingColor,
    Color textColor,
    Color textGray,
    Color inputFill,
    double screenWidth,
  ) {
    final title = AppTranslations.translate('reset_password_title');
    final btnText = AppTranslations.translate('save_btn');
    final cancelText = AppTranslations.translate('cancel');

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('password_step'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: headingColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textGray, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _newPassController,
            obscureText: _obscureNewPass,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
            decoration: InputDecoration(
              labelText: AppTranslations.translate('new_password_label'),
              labelStyle: TextStyle(color: textGray, fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline, color: textGray, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                  color: textGray,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPass = !_obscureNewPass),
              ),
              filled: true,
              fillColor: inputFill,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Temple_Gold, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppTranslations.translate('field_required');
              }
              if (value.trim().length < 6) {
                return AppTranslations.translate('password_too_short');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPassController,
            obscureText: _obscureConfirmPass,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
            decoration: InputDecoration(
              labelText: AppTranslations.translate('confirm_password_label'),
              labelStyle: TextStyle(color: textGray, fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline, color: textGray, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                  color: textGray,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
              filled: true,
              fillColor: inputFill,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Temple_Muted_Gold,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Temple_Gold, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppTranslations.translate('field_required');
              }
              if (value.trim() != _newPassController.text.trim()) {
                return AppTranslations.translate('passwords_dont_match');
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                color: Temple_Carnelian,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  cancelText,
                  style: TextStyle(
                    color: textGray,
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Temple_Gold,
                  foregroundColor: Temple_Black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Temple_Black,
                          ),
                        ),
                      )
                    : Text(
                        btnText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: getAppFontFamily(),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
