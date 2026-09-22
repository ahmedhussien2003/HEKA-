import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/translations.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';

/// Helper to display a premium slide-down simulated SMS alert at the top of the screen.
class SmsOverlayHelper {
  static void showSimulatedSms({
    required BuildContext context,
    required String message,
    required bool isDarkMode,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return SmsNotificationOverlay(
          message: message,
          isDarkMode: isDarkMode,
          onDismissed: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }
}

/// Widget for the animated simulated SMS notification banner.
class SmsNotificationOverlay extends StatefulWidget {
  final String message;
  final bool isDarkMode;
  final VoidCallback onDismissed;

  const SmsNotificationOverlay({
    super.key,
    required this.message,
    required this.isDarkMode,
    required this.onDismissed,
  });

  @override
  State<SmsNotificationOverlay> createState() => _SmsNotificationOverlayState();
}

class _SmsNotificationOverlayState extends State<SmsNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Timer _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    // Auto-dismiss after 5 seconds
    _autoDismissTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isArabic = selectedLanguageNotifier.value == 'Arabic';

    final cardBg = widget.isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
    final borderColor = Temple_Gold;
    final textColor = widget.isDarkMode ? Colors.white : Temple_Black;
    final subColor = widget.isDarkMode ? Temple_Text_Gray_Dark : Temple_Text_Gray_Light;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: 10,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Row(
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Temple_Glow_Gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: Temple_Gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppTranslations.translate('messages_title'),
                          style: TextStyle(
                            fontFamily: getAppFontFamily(),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Temple_Gold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.message,
                          style: TextStyle(
                            fontFamily: getAppFontFamily(),
                            fontSize: 13,
                            color: textColor,
                            height: 1.3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: subColor, size: 18),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum VerificationStep { enterOtp, enterNewPassword }

/// Dialog to handle phone-verification check followed by password update.
class ChangePasswordVerificationDialog extends StatefulWidget {
  final String userPhone;
  final bool isDarkMode;

  const ChangePasswordVerificationDialog({
    super.key,
    required this.userPhone,
    required this.isDarkMode,
  });

  @override
  State<ChangePasswordVerificationDialog> createState() =>
      _ChangePasswordVerificationDialogState();
}

class _ChangePasswordVerificationDialogState
    extends State<ChangePasswordVerificationDialog> {
  VerificationStep _currentStep = VerificationStep.enterOtp;
  String _verificationId = '';
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorMessage;

  // Fallback state variables
  bool _isSimulated = false;
  String _generatedCode = '';

  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
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
    });

    // Start 60 second timer
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

    // Show simulated notification overlay
    final smsMsg = AppTranslations.translate('otp_sms_simulated')
        .replaceAll('{code}', code);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmsOverlayHelper.showSimulatedSms(
        context: context,
        message: smsMsg,
        isDarkMode: widget.isDarkMode,
      );
    });
  }

  void _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _otpController.clear();
      _isSimulated = false;
    });

    String formattedPhone = widget.userPhone.trim();
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
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              bool isPhoneLinked = currentUser.providerData
                  .any((info) => info.providerId == 'phone');
              if (isPhoneLinked) {
                await currentUser.reauthenticateWithCredential(credential);
              } else {
                await currentUser.linkWithCredential(credential);
              }
              _timer?.cancel();
              setState(() {
                _currentStep = VerificationStep.enterNewPassword;
                _errorMessage = null;
              });
            }
          } catch (e) {
            setState(() {
              _errorMessage = e.toString();
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
          });

          // Start 60 second timer
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
        if (lowCaseMsg.contains('billing') || lowCaseMsg.contains('billing_not_enabled')) {
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
      // Simulated OTP check
      await Future.delayed(const Duration(milliseconds: 800));
      if (otp == _generatedCode) {
        _timer?.cancel();
        setState(() {
          _currentStep = VerificationStep.enterNewPassword;
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

    // Real Firebase Phone Auth
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        bool isPhoneLinked = currentUser.providerData
            .any((info) => info.providerId == 'phone');
        if (isPhoneLinked) {
          await currentUser.reauthenticateWithCredential(credential);
        } else {
          await currentUser.linkWithCredential(credential);
        }
        _timer?.cancel();
        setState(() {
          _currentStep = VerificationStep.enterNewPassword;
          _errorMessage = null;
        });
      } else {
        throw Exception("User not logged in");
      }
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(_newPassController.text.trim());
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.translate('password_changed_success')),
              backgroundColor: Temple_Teal,
            ),
          );
        }
      } else {
        throw Exception("User not logged in");
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'requires-recent-login') {
          _errorMessage = AppTranslations.translate('recent_login_required');
        } else {
          _errorMessage = e.message ?? AppTranslations.translate('unexpected_error');
        }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isArabic = selectedLanguageNotifier.value == 'Arabic';

    final dialogBg = widget.isDarkMode ? const Color(0xFF1A1914) : Colors.white;
    final textGray = widget.isDarkMode ? Temple_Text_Gray_Dark : Temple_Text_Gray_Light;
    final textColor = widget.isDarkMode ? Colors.white : Temple_Black;
    final inputFill = widget.isDarkMode ? Temple_Input_Fill_Dark : Temple_Input_Fill_Light;
    final textHeadingColor = widget.isDarkMode ? Temple_Gold : const Color(0xFF9E7E0D);

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
            child: _currentStep == VerificationStep.enterOtp
                ? _buildOtpStep(isArabic, textHeadingColor, textColor, textGray, inputFill, screenWidth)
                : _buildPasswordStep(isArabic, textHeadingColor, textColor, textGray, inputFill, screenWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpStep(
    bool isArabic,
    Color headingColor,
    Color textColor,
    Color textGray,
    Color inputFill,
    double screenWidth,
  ) {
    final timerColor = _secondsRemaining > 10 ? Temple_Gold : Temple_Carnelian;
    final countdownText = AppTranslations.translate('otp_seconds_remaining')
        .replaceAll('{seconds}', _secondsRemaining.toString());

    // Format phone number to E.164 first
    String formattedPhone = widget.userPhone.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+20${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+20$formattedPhone';
      }
    }

    // Mask phone number (e.g. +20******1234)
    String maskedPhone = formattedPhone;
    if (formattedPhone.length > 4) {
      final prefix = formattedPhone.substring(0, 3); // "+20"
      final suffix = formattedPhone.substring(formattedPhone.length - 4); // "1234"
      maskedPhone = "$prefix******$suffix";
    }

    return Column(
      key: const ValueKey('otp_step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppTranslations.translate('otp_dialog_title'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: headingColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        if (val) {
                          _startSimulatedOtp("Switched to Demo Mode manually.");
                        } else {
                          _sendOtp();
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textGray, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: AppTranslations.translate('close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "${AppTranslations.translate('otp_dialog_subtitle')}: $maskedPhone",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.4,
            fontFamily: getAppFontFamily(),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        
        // OTP input field
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            fontFamily: getAppFontFamily(),
          ),
          decoration: InputDecoration(
            counterText: "", // Hide count
            hintText: "• • • • • •",
            hintStyle: TextStyle(
              color: textGray.withOpacity(0.4),
              fontSize: 18,
              letterSpacing: 4,
            ),
            prefixIcon: Icon(Icons.lock_clock, color: textGray, size: 20),
            filled: true,
            fillColor: inputFill,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          ),
          onChanged: (val) {
            if (val.length == 6) {
              _verifyOtp();
            }
          },
        ),
        const SizedBox(height: 15),

        // Timer indicator
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

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Temple_Carnelian,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Resend and Verify buttons (Wrap to prevent overflow)
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: (_secondsRemaining == 0 && !_isLoading)
                  ? (_isSimulated ? () => _startSimulatedOtp("Resending simulated OTP") : _sendOtp)
                  : null,
              child: Text(
                AppTranslations.translate('otp_resend'),
                style: TextStyle(
                  color: (_secondsRemaining == 0 && !_isLoading) ? Temple_Gold : textGray.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Temple_Gold,
                foregroundColor: Temple_Black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Temple_Black),
                      ),
                    )
                  : Text(
                      AppTranslations.translate('otp_verify_btn'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: getAppFontFamily(),
                      ),
                    ),
            ),
          ],
        ),
      ],
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
              Expanded(
                child: Text(
                  AppTranslations.translate('change_password'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: headingColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, color: textGray, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // New Password field
          _buildLocalTextField(
            label: AppTranslations.translate('new_password_label'),
            hint: AppTranslations.translate('password_hint'),
            icon: Icons.lock_outline,
            obscureText: _obscureNewPass,
            controller: _newPassController,
            textGrayColor: textGray,
            inputFillColor: inputFill,
            textColor: textColor,
            onToggleVisibility: () => setState(() {
              _obscureNewPass = !_obscureNewPass;
            }),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppTranslations.translate('field_required');
              }
              if (value.length < 6) {
                return AppTranslations.translate('password_too_short');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password field
          _buildLocalTextField(
            label: AppTranslations.translate('confirm_password_label'),
            hint: AppTranslations.translate('password_hint'),
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPass,
            controller: _confirmPassController,
            textGrayColor: textGray,
            inputFillColor: inputFill,
            textColor: textColor,
            onToggleVisibility: () => setState(() {
              _obscureConfirmPass = !_obscureConfirmPass;
            }),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppTranslations.translate('field_required');
              }
              if (value != _newPassController.text) {
                return AppTranslations.translate('passwords_dont_match');
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Temple_Carnelian,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Submit & Cancel (Wrap to prevent overflow)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                child: Text(
                  AppTranslations.translate('cancel'),
                  style: TextStyle(
                    color: textGray,
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Temple_Gold,
                  foregroundColor: Temple_Black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Temple_Black),
                        ),
                      )
                    : Text(
                        AppTranslations.translate('change_password'),
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

  Widget _buildLocalTextField({
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    required TextEditingController controller,
    required Color textGrayColor,
    required Color inputFillColor,
    required Color textColor,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            color: textColor,
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
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              size: 20,
            ),
            suffixIcon: onToggleVisibility != null
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: inputFillColor,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
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
          ),
          validator: validator,
        ),
      ],
    );
  }
}
