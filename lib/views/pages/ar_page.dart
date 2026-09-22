import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AR Page
// ─────────────────────────────────────────────────────────────────────────────

class ARPage extends StatefulWidget {
  const ARPage({
    super.key,
    this.preloadedImage,
    this.preloadedText,
    this.isSingleSymbol = false,
  });

  /// When set, the page skips the viewfinder and goes straight
  /// to the result view with the animated 3-D overlay.
  final File? preloadedImage;
  final String? preloadedText;
  final bool isSingleSymbol;

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> with TickerProviderStateMixin {
  // ── state ──────────────────────────────────────────────────────────────────
  File? _capturedImage;
  bool _isLoading = false;
  String? _errorMessage;
  String? _translatedText;

  // ── sensors ────────────────────────────────────────────────────────────────
  StreamSubscription? _sensorSubscription;
  final ValueNotifier<Offset> _sensorOffset = ValueNotifier(Offset.zero);
  static const double _sensorSmoothFactor = 0.12;
  DateTime _lastSensorUpdate = DateTime.now();

  // ── animations ─────────────────────────────────────────────────────────────
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _revealController;

  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _revealAnimation;

  // ── API ────────────────────────────────────────────────────────────────────
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  late final String _apiBaseUrl;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 60),
      sendTimeout: const Duration(minutes: 60),
      receiveTimeout: const Duration(minutes: 60),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _apiBaseUrl = _resolveApiBaseUrl();

    // floating bob
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // shimmer glow
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // scan-line sweep
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _scanAnimation = Tween<double>(
      begin: -0.1,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    // pulse ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // text reveal
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutBack,
    );

    // If pre-loaded data was passed in, jump straight to result view.
    if (widget.preloadedImage != null && widget.preloadedText != null) {
      _capturedImage = widget.preloadedImage;
      _translatedText = widget.preloadedText;
      // Start the reveal animation after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealController.forward();
      });
    }

    // Start listening to accelerometer for parallax
    _startSensors();
  }

  void _startSensors() {
    _sensorSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;

      final now = DateTime.now();
      // Throttle sensor updates to ~30Hz to save CPU
      if (now.difference(_lastSensorUpdate).inMilliseconds < 32) return;
      _lastSensorUpdate = now;

      // Smooth the sensor data to prevent jitter
      final double targetX = event.x;
      final double targetY = event.z - 5.0; // Tilt offset

      final double newX =
          _sensorOffset.value.dx * (1.0 - _sensorSmoothFactor) +
          targetX * _sensorSmoothFactor;
      final double newY =
          _sensorOffset.value.dy * (1.0 - _sensorSmoothFactor) +
          targetY * _sensorSmoothFactor;

      _sensorOffset.value = Offset(newX, newY);
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _sensorOffset.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _revealController.dispose();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  String _resolveApiBaseUrl() {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final int port = widget.isSingleSymbol ? 8000 : 8001;
    if (kIsWeb) return 'http://localhost:$port';
    if (Platform.isAndroid) return 'http://192.168.1.7:$port';
    return 'http://localhost:$port';
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // ── capture & analyse ──────────────────────────────────────────────────────
  Future<void> _captureAndAnalyse() async {
    final picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (photo == null) return;

      _setStateIfMounted(() {
        _capturedImage = File(photo.path);
        _isLoading = true;
        _errorMessage = null;
        _translatedText = null;
      });
      _revealController.reset();

      await _sendToAPI(File(photo.path));
    } on PlatformException catch (e) {
      if (e.code != 'already_active') {
        _setStateIfMounted(() {
          _errorMessage = 'Camera error: ${e.message ?? e.code}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendToAPI(File image) async {
    try {
      final String fileName = image.path.split('/').last;
      final FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: fileName),
      });

      final currentLang = kSupportedLanguages.firstWhere(
        (l) => l['name'] == selectedLanguageNotifier.value,
        orElse: () => kSupportedLanguages[1],
      );
      final langCode = currentLang['code'] ?? 'en';

      final String path = widget.isSingleSymbol ? '/predict' : '/translate';
      final response = await _dio.post(
        '$_apiBaseUrl$path?target_lang=$langCode',
        data: formData,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final serverError = data['error'] ?? data['detail'];

        if (serverError != null) {
          _setStateIfMounted(() {
            _errorMessage = serverError.toString();
            _isLoading = false;
          });
        } else {
          String? result;
          if (widget.isSingleSymbol) {
            // For single symbol, extract meaning based on selected language
            final currentLangName = selectedLanguageNotifier.value;
            String? meaning;

            bool isValid(dynamic val) {
              if (val == null) return false;
              final s = val.toString().trim();
              return s.isNotEmpty && s != 'N/A' && s.toLowerCase() != 'null';
            }

            // 1. Try language-specific field
            final langField = 'meaning_${currentLangName.toLowerCase()}';
            if (isValid(data[langField])) {
              meaning = data[langField].toString();
            }

            // 2. Try Target_Language_Result
            if (meaning == null && isValid(data['Target_Language_Result'])) {
              meaning = data['Target_Language_Result'].toString();
            }

            // 3. Fallback to English
            if (meaning == null && isValid(data['meaning_english'])) {
              meaning = data['meaning_english'].toString();
            }

            // 4. Fallback to Arabic
            if (meaning == null && isValid(data['meaning_arabic'])) {
              meaning = data['meaning_arabic'].toString();
            }

            result = meaning;
          } else {
            // Build the best translation string available for multi symbols
            result = data['Target_Language_Result']?.toString();
            if (result == null || result.isEmpty) {
              result = data['Sentence']?.toString();
            }
            if (result == null || result.isEmpty) {
              final englishWords = (data['english'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              if (englishWords.isNotEmpty) {
                result = englishWords.join(', ');
              }
            }
          }

          _setStateIfMounted(() {
            _translatedText =
                result ?? AppTranslations.translate('ar_no_result');
            _isLoading = false;
          });
          _revealController.forward();
        }
      } else {
        _setStateIfMounted(() {
          _errorMessage =
              response.data?['error'] ??
              response.data?['detail'] ??
              'Translation failed';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      _setStateIfMounted(() {
        _errorMessage =
            e.response?.data?['error'] ??
            e.response?.data?['detail'] ??
            'Network error occurred';
        _isLoading = false;
      });
    } catch (e) {
      _setStateIfMounted(() {
        _errorMessage = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  void _retake() {
    _setStateIfMounted(() {
      _capturedImage = null;
      _translatedText = null;
      _errorMessage = null;
      _isLoading = false;
    });
    _revealController.reset();
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: selectedLanguageNotifier,
          builder: (context, language, _) {
            final bg = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final fontColor = isDarkMode ? Temple_White : Temple_Black;

            return Scaffold(
              backgroundColor: bg,
              extendBodyBehindAppBar: true,
              appBar: _buildAppBar(fontColor),
              body: _capturedImage == null
                  ? _buildViewfinder(isDarkMode, fontColor)
                  : _buildResultView(isDarkMode, fontColor),
            );
          },
        );
      },
    );
  }

  // ── app bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(Color fontColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: Temple_Gold),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-0.05),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (double i = 2; i > 0; i -= 0.5)
              Transform.translate(
                offset: Offset(i, i),
                child: Text(
                  AppTranslations.translate('ar_mode_title'),
                  style: TextStyle(
                    color: const Color(0xFF3E2723),
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 4,
                  ),
                ),
              ),
            Text(
              AppTranslations.translate('ar_mode_title'),
              style: TextStyle(
                color: Temple_Gold,
                fontFamily: getAppFontFamily(),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  // ── viewfinder ─────────────────────────────────────────────────────────────
  Widget _buildViewfinder(bool isDarkMode, Color fontColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      const Color(0xFF0F0E08),
                      const Color(0xFF1A1810),
                      const Color(0xFF0F0E08),
                    ]
                  : [
                      const Color(0xFFFCF5E0),
                      const Color(0xFFF0EAD6),
                      const Color(0xFFFCF5E0),
                    ],
            ),
          ),
        ),

        // animated corner brackets (AR feel)
        CustomPaint(painter: _ARCornersPainter()),

        // scan-line animation
        AnimatedBuilder(
          animation: _scanAnimation,
          builder: (context, _) {
            return Positioned(
              top: MediaQuery.of(context).size.height * _scanAnimation.value,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Temple_Gold.withOpacity(0.6),
                      Temple_Gold,
                      Temple_Gold.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Temple_Gold.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // centre content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // viewfinder icon
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) =>
                    Transform.scale(scale: _pulseAnimation.value, child: child),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Temple_Gold, width: 2.5),
                    color: Temple_Gold.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Temple_Gold.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_enhance_rounded,
                    size: 64,
                    color: Temple_Gold,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // instruction text
              Text(
                AppTranslations.translate('ar_tap_capture'),
                style: TextStyle(
                  color: fontColor,
                  fontFamily: getAppFontFamily(),
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 52),
              // capture button
              _CaptureButton(onTap: _captureAndAnalyse),
            ],
          ),
        ),
      ],
    );
  }

  // ── result view ────────────────────────────────────────────────────────────
  Widget _buildResultView(bool isDarkMode, Color fontColor) {
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── captured image ────────────────────────────────────────────────
        Positioned.fill(child: Image.file(_capturedImage!, fit: BoxFit.cover)),

        // ── dark vignette ─────────────────────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
                stops: const [0.0, 0.25, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // ── holographic scan-line sweep ───────────────────────────────────
        if (!_isLoading)
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, _) => Positioned(
              top: size.height * _scanAnimation.value,
              left: 0,
              right: 0,
              height: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Temple_Gold.withOpacity(0.5),
                      Temple_Gold.withOpacity(0.9),
                      Temple_Gold.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Temple_Gold.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── AR corner brackets ────────────────────────────────────────────
        CustomPaint(painter: _ARCornersPainter()),

        // ── loading indicator ─────────────────────────────────────────────
        if (_isLoading)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: Temple_Gold,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppTranslations.translate('ar_analyzing'),
                  style: TextStyle(
                    color: Temple_Gold,
                    fontFamily: getAppFontFamily(),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),

        // ── error message ─────────────────────────────────────────────────
        if (!_isLoading && _errorMessage != null)
          Positioned(
            top: size.height * 0.14,
            left: 24,
            right: 24,
            child: _ErrorBanner(message: _errorMessage!),
          ),

        // ── 3D translated text overlay ────────────────────────────────────
        if (!_isLoading && _translatedText != null)
          Positioned(
            top: size.height * 0.12,
            left: 20,
            right: 20,
            child: ScaleTransition(
              scale: _revealAnimation,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _floatAnimation,
                  _shimmerAnimation,
                ]),
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: ValueListenableBuilder<Offset>(
                      valueListenable: _sensorOffset,
                      builder: (context, sensor, _) {
                        return _ArTextOverlay(
                          text: _translatedText!,
                          opacity: _shimmerAnimation.value,
                          sensorX: sensor.dx,
                          sensorY: sensor.dy,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

        // ── bottom action bar ─────────────────────────────────────────────
        if (!_isLoading)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _RetakeButton(
                label: AppTranslations.translate('ar_retake'),
                onTap: _retake,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3D Text Overlay Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ArTextOverlay extends StatelessWidget {
  const _ArTextOverlay({
    required this.text,
    required this.opacity,
    required this.sensorX,
    required this.sensorY,
  });

  final String text;
  final double opacity;
  final double sensorX;
  final double sensorY;

  @override
  Widget build(BuildContext context) {
    // Static dramatic 3D angle (no sensor sway as requested)
    const double rotX = -0.22;
    const double rotY = 0.15;

    // Fixed extrusion for consistent 3D appearance

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.003) // Ultra perspective
        ..rotateX(rotX)
        ..rotateY(rotY),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.65),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Temple_Gold.withOpacity(0.25 * opacity),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
          border: Border.all(color: Temple_Gold.withOpacity(0.5), width: 1.8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Precise 3D Extrusion (24 Identical Layers for solid depth) ──
            for (double i = 24; i > 0; i -= 1.0)
              _depthLayer(
                text,
                Offset(i * 0.45, i * 0.45), // Unified precision offset
                Color.lerp(
                  const Color(0xFF000000),
                  const Color(0xFF3D2B1F), // Deep bronze
                  (24 - i) / 24,
                )!.withOpacity(0.98),
              ),

            // ── Face Shadow (Subtle lift) ──────────────────────────────────
            _depthLayer(
              text,
              const Offset(0.5, 0.5),
              Colors.black.withOpacity(0.5),
            ),

            // ── Outer Glow / Bloom ─────────────────────────────────────────
            _depthLayer(
              text,
              const Offset(0, 0),
              Temple_Gold.withOpacity(0.4 * opacity),
              blur: 12.0,
            ),

            // ── Main Face (Metallic Look) ──────────────────────────────────
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFFFFE57F),
                  Temple_Gold,
                  const Color(0xFF8B6B00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: getAppFontFamily(),
                  letterSpacing: 4,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _depthLayer(
    String text,
    Offset offset,
    Color color, {
    double blur = 0.0,
  }) {
    return Transform.translate(
      offset: offset,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          fontFamily: getAppFontFamily(),
          letterSpacing: 4,
          height: 1.2,
          shadows: blur > 0 ? [Shadow(color: color, blurRadius: blur)] : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Capture Button
// ─────────────────────────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFE57F), Temple_Gold, Color(0xFFB8860B)],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Temple_Gold.withOpacity(0.55),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.black87,
          size: 36,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Retake Button
// ─────────────────────────────────────────────────────────────────────────────

class _RetakeButton extends StatelessWidget {
  const _RetakeButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: Colors.black.withOpacity(0.6),
          border: Border.all(color: Temple_Gold, width: 1.5),
          boxShadow: [
            BoxShadow(color: Temple_Gold.withOpacity(0.3), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: Temple_Gold, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Temple_Gold,
                fontFamily: getAppFontFamily(),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Temple_Carnelian.withOpacity(0.8)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFFFF6B6B),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: getAppFontFamily(),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AR Corner Brackets Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ARCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Temple_Gold.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const double len = 36.0;
    const double pad = 28.0;

    // top-left
    canvas.drawLine(Offset(pad, pad + len), Offset(pad, pad), paint);
    canvas.drawLine(Offset(pad, pad), Offset(pad + len, pad), paint);

    // top-right
    canvas.drawLine(
      Offset(size.width - pad - len, pad),
      Offset(size.width - pad, pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(size.width - pad, pad + len),
      paint,
    );

    // bottom-left
    canvas.drawLine(
      Offset(pad, size.height - pad - len),
      Offset(pad, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(pad + len, size.height - pad),
      paint,
    );

    // bottom-right
    canvas.drawLine(
      Offset(size.width - pad - len, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad),
      Offset(size.width - pad, size.height - pad - len),
      paint,
    );

    // centre crosshair (small)
    final cx = size.width / 2;
    final cy = size.height / 2;
    const double ch = 14.0;
    final crossPaint = Paint()
      ..color = Temple_Gold.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(cx - ch, cy), Offset(cx + ch, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - ch), Offset(cx, cy + ch), crossPaint);
    canvas.drawCircle(Offset(cx, cy), 4.0, crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
