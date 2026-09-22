import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';
import 'ar_page.dart';

class OneSymbolPage extends StatefulWidget {
  const OneSymbolPage({super.key});

  @override
  State<OneSymbolPage> createState() => _OneSymbolPageState();
}

class _OneSymbolPageState extends State<OneSymbolPage>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  File? _image;
  bool _isLoading = false;
  bool _isPickingImage = false;
  bool _isSaved = false;
  String? _savedDocId;
  Map<String, dynamic>? _predictionResult;
  String? _errorMessage;
  Duration? _apiExecutionTime;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AnimationController _glowController;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 3),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );

  static const String _predictPath = "/predict";
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  late final String _apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _apiBaseUrl = _resolveApiBaseUrl();
    _setupDioLogging();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _resolveApiBaseUrl() {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return "http://localhost:8000";
    if (Platform.isAndroid) return "http://10.187.52.11:8000";
    return "http://localhost:8000";
  }

  void _setupDioLogging() {
    if (!kDebugMode) return;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint("[API] --> ${options.method} ${options.uri}");
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            "[API] <-- ${response.statusCode} ${response.requestOptions.uri}",
          );
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint("[API] xx error: ${error.message}");
          handler.next(error);
        },
      ),
    );
    debugPrint("[API] Base URL = $_apiBaseUrl");
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage || _isLoading) return;

    _isPickingImage = true;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null) {
        _setStateIfMounted(() {
          _image = File(image.path);
          _predictionResult = null;
          _errorMessage = null;
          _apiExecutionTime = null;
        });
        await _sendImageToAPI();
      }
    } on PlatformException catch (e) {
      // Happens if image picker is launched twice quickly.
      if (e.code != 'already_active') {
        _setStateIfMounted(() {
          _errorMessage = 'Failed to pick image: ${e.message ?? e.code}';
        });
      }
    } finally {
      _isPickingImage = false;
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _predictionResult = null;
      _errorMessage = null;
      _isLoading = false;
      _apiExecutionTime = null;
      _isSaved = false;
    });
  }

  String _formatExecutionTime(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return "${duration.inMilliseconds} ms";
    }
    return "${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s";
  }

  String _formatConfidence(dynamic score) {
    if (score is num) return "${(score * 100).toStringAsFixed(2)}%";
    return score?.toString() ?? "N/A";
  }

  Map<String, dynamic> _normalizePrediction(Map<String, dynamic> data) {
    final className = data['class_name'] ?? data['gardiner'];
    final confidence =
        data['confidence'] ?? _formatConfidence(data['confidence_score']);

    return {
      'class_id': data['class_id'],
      'class_name': className,
      'gardiner': data['gardiner'] ?? className ?? '',
      'meaning_english': data['meaning_english'],
      'meaning_arabic': data['meaning_arabic'],
      'meaning_italian': data['meaning_italian'] ?? '',
      'meaning_german': data['meaning_german'] ?? '',
      'meaning_spanish': data['meaning_spanish'] ?? '',
      'meaning_russian': data['meaning_russian'] ?? '',
      'meaning_polish': data['meaning_polish'] ?? '',
      'meaning_user': data['Target_Language_Result'],
      'confidence': confidence,
    };
  }

  Future<String?> _resizeAndCompressImage(File? imageFile) async {
    if (imageFile == null) return null;
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 300);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Error compressing image: $e');
    }
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  String _getMeaningForSaving() {
    if (_predictionResult == null) return 'N/A';
    final currentLangName = selectedLanguageNotifier.value;
    if (currentLangName == 'Arabic') {
      return _predictionResult!['meaning_arabic'] ??
          _predictionResult!['meaning_english'] ??
          'N/A';
    } else if (currentLangName == 'English') {
      return _predictionResult!['meaning_english'] ?? 'N/A';
    } else {
      return _predictionResult!['meaning_user'] ??
          _predictionResult!['meaning_english'] ??
          'N/A';
    }
  }

  Future<void> _saveResult() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    if (_predictionResult == null) return;
    try {
      final base64Image = await _resizeAndCompressImage(_image);

      final docRef = await _firestoreService.recordTranslation(user.uid, {
        'Date': Timestamp.now(),
        'Type': 'Saved Single Symbol',
        'Meaning': _getMeaningForSaving(),
        'MeaningEnglish': _predictionResult!['meaning_english'] ?? 'N/A',
        'MeaningArabic': _predictionResult!['meaning_arabic'] ?? 'N/A',
        'MeaningItalian': _predictionResult!['meaning_italian'] ?? 'N/A',
        'MeaningGerman': _predictionResult!['meaning_german'] ?? 'N/A',
        'MeaningSpanish': _predictionResult!['meaning_spanish'] ?? 'N/A',
        'MeaningRussian': _predictionResult!['meaning_russian'] ?? 'N/A',
        'MeaningPolish': _predictionResult!['meaning_polish'] ?? 'N/A',
        'MeaningUser': _predictionResult!['meaning_user'] ?? 'N/A',
        'SavedLanguage': selectedLanguageNotifier.value,
        'SavedData': _predictionResult,
        'image_base64': base64Image,
      });

      await _firestoreService.incrementSavedGlyphsCount(user.uid);

      _setStateIfMounted(() {
        _isSaved = true;
        _savedDocId = docRef.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.translate('saved_success'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTranslations.translate('save_error')}: $e',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _unsaveResult() async {
    final User? user = _auth.currentUser;
    if (user == null || _savedDocId == null) return;
    try {
      await _firestoreService.deleteTranslation(user.uid, _savedDocId!);
      await _firestoreService.decrementSavedGlyphsCount(user.uid);
      _setStateIfMounted(() {
        _isSaved = false;
        _savedDocId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.translate('removed_saved_success'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppTranslations.translate('remove_error')}: $e',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isSaved) {
      await _unsaveResult();
    } else {
      await _saveResult();
    }
  }

  Future<void> _sendImageToAPI() async {
    if (_image == null) return;

    _setStateIfMounted(() {
      _isLoading = true;
      _errorMessage = null;
      _predictionResult = null;
      _apiExecutionTime = null;
      _isSaved = false;
      _savedDocId = null;
    });
    final stopwatch = Stopwatch()..start();

    try {
      String fileName = _image!.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(_image!.path, filename: fileName),
      });

      final currentLang = kSupportedLanguages.firstWhere(
        (l) => l['name'] == selectedLanguageNotifier.value,
        orElse: () => kSupportedLanguages[1],
      );
      final langCode = currentLang['code'] ?? 'en';

      var response = await _dio.post(
        "$_apiBaseUrl$_predictPath?target_lang=$langCode",
        data: formData,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final serverError = data['error'] ?? data['detail'];
        if (serverError != null) {
          _setStateIfMounted(() {
            _errorMessage = serverError.toString();
          });
        } else {
          _setStateIfMounted(() {
            _predictionResult = _normalizePrediction(data);
          });
          final User? user = _auth.currentUser;
          if (user != null) {
            try {
              await _firestoreService.incrementTranslationCount(user.uid);
              await _firestoreService.recordTranslation(user.uid, {
                'Date': Timestamp.now(),
                'Type': 'Single Symbol',
                'Meaning': _getMeaningForSaving(),
                'MeaningEnglish':
                    _predictionResult!['meaning_english'] ?? 'N/A',
                'MeaningArabic': _predictionResult!['meaning_arabic'] ?? 'N/A',
                'MeaningItalian':
                    _predictionResult!['meaning_italian'] ?? 'N/A',
                'MeaningGerman': _predictionResult!['meaning_german'] ?? 'N/A',
                'MeaningSpanish':
                    _predictionResult!['meaning_spanish'] ?? 'N/A',
                'MeaningRussian':
                    _predictionResult!['meaning_russian'] ?? 'N/A',
                'MeaningPolish': _predictionResult!['meaning_polish'] ?? 'N/A',
                'MeaningUser': _predictionResult!['meaning_user'] ?? 'N/A',
                'SavedLanguage': selectedLanguageNotifier.value,
              });
              debugPrint('Translation recorded successfully for ${user.uid}');
            } catch (e) {
              debugPrint('Failed to record translation: $e');
            }
          }
        }
      } else {
        _setStateIfMounted(() {
          _errorMessage =
              response.data?['error'] ??
              response.data?['detail'] ??
              'Failed to get prediction';
        });
      }
    } on DioException catch (e) {
      _setStateIfMounted(() {
        _errorMessage =
            e.response?.data?['error'] ??
            e.response?.data?['detail'] ??
            'Network error occurred';
      });
    } catch (e) {
      _setStateIfMounted(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      stopwatch.stop();
      _setStateIfMounted(() {
        _isLoading = false;
        _apiExecutionTime = stopwatch.elapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: selectedLanguageNotifier,
          builder: (context, language, child) {
            final fontColor = isDarkMode ? Temple_White : Temple_Black;
            final backgroundColor = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
            final screenWidth = MediaQuery.of(context).size.width;

            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: fontColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  AppTranslations.translate('single_symbol_title'),
                  style: TextStyle(
                    color: Temple_Gold,
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  children: [
                    if (_image == null)
                      _buildInitialCards(
                        context,
                        cardColor,
                        fontColor,
                        screenWidth,
                      )
                    else
                      _buildImagePreview(
                        context,
                        cardColor,
                        fontColor,
                        screenWidth,
                      ),
                    const SizedBox(height: 40),
                    if (_isLoading)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.translate('analyzing_image'),
                            style: TextStyle(
                              color: fontColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: getAppFontFamily(),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    if (!_isLoading && _image != null)
                      if (_errorMessage != null)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: getAppFontFamily(),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_apiExecutionTime != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                "${AppTranslations.translate('execution_time')}: ${_formatExecutionTime(_apiExecutionTime!)}",
                                style: TextStyle(
                                  color: fontColor,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        )
                      else if (_predictionResult != null)
                        _buildResults(
                          fontColor,
                          screenWidth,
                          cardColor,
                          isDarkMode,
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInitialCards(
    BuildContext context,
    Color cardColor,
    Color fontColor,
    double screenWidth,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Row(
      key: const ValueKey('initialCards'),
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildChoiceCard(
          context: context,
          icon: Icons.photo_library_outlined,
          label: AppTranslations.translate('browse'),
          onTap: () => _pickImage(ImageSource.gallery),
          cardColor: cardColor,
          fontColor: fontColor,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
        _buildChoiceCard(
          context: context,
          icon: Icons.camera_alt_outlined,
          label: AppTranslations.translate('camera'),
          onTap: () => _pickImage(ImageSource.camera),
          cardColor: cardColor,
          fontColor: fontColor,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
      ],
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    Color cardColor,
    Color fontColor,
    double screenWidth,
  ) {
    return Container(
      key: const ValueKey('imagePreview'),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Temple_Gold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              image: _image != null
                  ? DecorationImage(
                      image: FileImage(_image!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _image == null
                ? Icon(
                    Icons.image_outlined,
                    color: fontColor.withAlpha(128),
                    size: 40,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppTranslations.translate('your_image'),
              style: TextStyle(
                color: fontColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
          ),
          IconButton(
            onPressed: _reset,
            icon: Icon(Icons.close, color: fontColor),
            tooltip: AppTranslations.translate('remove_image'),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    Color fontColor,
    double screenWidth,
    Color cardColor,
    bool isDarkMode,
  ) {
    final gardiner =
        (_predictionResult?['gardiner'] ??
                _predictionResult?['class_name'] ??
                '')
            .toString();
    final meaningEnglish = (_predictionResult?['meaning_english'] ?? '')
        .toString();
    final meaningArabic = (_predictionResult?['meaning_arabic'] ?? '')
        .toString();
    final meaningItalian = (_predictionResult?['meaning_italian'] ?? '')
        .toString();
    final meaningGerman = (_predictionResult?['meaning_german'] ?? '')
        .toString();
    final meaningSpanish = (_predictionResult?['meaning_spanish'] ?? '')
        .toString();
    final meaningRussian = (_predictionResult?['meaning_russian'] ?? '')
        .toString();
    final meaningPolish = (_predictionResult?['meaning_polish'] ?? '')
        .toString();

    String getActiveMeaning() {
      if (_predictionResult == null) return '';
      final currentLang = selectedLanguageNotifier.value;
      final meaningUserVal = (_predictionResult?['meaning_user'] ?? '')
          .toString();
      if (currentLang == 'English') {
        return meaningEnglish;
      } else if (currentLang == 'Arabic') {
        return meaningArabic;
      } else if (currentLang == 'Italian') {
        if (meaningItalian.isNotEmpty) return meaningItalian;
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      } else if (currentLang == 'German') {
        if (meaningGerman.isNotEmpty) return meaningGerman;
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      } else if (currentLang == 'Spanish') {
        if (meaningSpanish.isNotEmpty) return meaningSpanish;
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      } else if (currentLang == 'Russian') {
        if (meaningRussian.isNotEmpty) return meaningRussian;
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      } else if (currentLang == 'Polish') {
        if (meaningPolish.isNotEmpty) return meaningPolish;
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      } else {
        return meaningUserVal.isNotEmpty ? meaningUserVal : meaningEnglish;
      }
    }

    final meaningUser = getActiveMeaning();
    final textForAR = meaningUser.trim().isNotEmpty
        ? meaningUser
        : meaningEnglish;

    return ValueListenableBuilder<bool>(
      valueListenable: showArabicEnglishNotifier,
      builder: (context, showArEn, _) {
        final currentLangName = selectedLanguageNotifier.value;
        final bool isEnglish = currentLangName == 'English';
        final bool isArabic = currentLangName == 'Arabic';

        final rows = <Widget>[];

        if (gardiner.trim().isNotEmpty) {
          rows.add(
            _buildKeyValueRow(
              AppTranslations.translate('gardiner_label'),
              gardiner,
              fontColor,
            ),
          );
        }

        if (showArEn) {
          if (meaningArabic.trim().isNotEmpty) {
            rows.add(
              _buildKeyValueRow(
                AppTranslations.translate('arabic_label'),
                meaningArabic,
                fontColor,
              ),
            );
          }
          if (meaningEnglish.trim().isNotEmpty) {
            rows.add(
              _buildKeyValueRow(
                AppTranslations.translate('english_label'),
                meaningEnglish,
                fontColor,
              ),
            );
          }
          if (!isEnglish && !isArabic && meaningUser.trim().isNotEmpty) {
            rows.add(
              _buildKeyValueRow(currentLangName, meaningUser, fontColor),
            );
          }
        } else {
          if (isEnglish) {
            if (meaningEnglish.trim().isNotEmpty) {
              rows.add(
                _buildKeyValueRow(
                  AppTranslations.translate('english_label'),
                  meaningEnglish,
                  fontColor,
                ),
              );
            }
          } else if (isArabic) {
            if (meaningArabic.trim().isNotEmpty) {
              rows.add(
                _buildKeyValueRow(
                  AppTranslations.translate('arabic_label'),
                  meaningArabic,
                  fontColor,
                ),
              );
            }
          } else {
            if (meaningUser.trim().isNotEmpty) {
              rows.add(
                _buildKeyValueRow(currentLangName, meaningUser, fontColor),
              );
            }
          }
        }

        if (rows.isEmpty && gardiner.trim().isEmpty) {
          rows.add(
            _buildKeyValueRow(
              AppTranslations.translate('results'),
              'N/A',
              fontColor,
            ),
          );
        }

        final animSize = screenWidth < 520
            ? screenWidth * 0.4
            : screenWidth * 0.3;

        return Column(
          children: [
            Text(
              AppTranslations.translate('results'),
              style: TextStyle(
                color: fontColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              child: AnimatedBuilder(
                animation: _glowController,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Lottie.asset(
                            'assets/lottie_files/NileKey_Animation.json',
                            width: animSize,
                            height: animSize,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...rows,
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          color: Temple_Gold,
                          size: 28,
                        ),
                        onPressed: _toggleBookmark,
                      ),
                    ),
                  ],
                ),
                builder: (context, child) {
                  final angle = -_glowController.value * -2 * math.pi;
                  return Center(
                    child: SizedBox(
                      width: screenWidth * 0.78,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: SweepGradient(
                            transform: GradientRotation(angle),
                            colors: [
                              Colors.transparent,
                              Temple_Gold.withOpacity(0.15),
                              Temple_Gold.withOpacity(0.7),
                              Temple_Gold.withOpacity(0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Temple_Gold.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(scale: value, child: child),
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              AppTranslations.translate('confidence_ratio'),
              style: TextStyle(
                color: fontColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (_predictionResult?['confidence'] ?? 'N/A').toString(),
              style: TextStyle(
                color: isDarkMode ? Colors.greenAccent : Colors.green,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
            const SizedBox(height: 20),
            if (_apiExecutionTime != null) ...[
              const SizedBox(height: 16),
              Text(
                '${AppTranslations.translate('execution_time')}: ${_formatExecutionTime(_apiExecutionTime!)}',
                style: TextStyle(
                  color: fontColor.withAlpha(210),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: getAppFontFamily(),
                ),
              ),
            ],
            const SizedBox(height: 30),
            _buildARModeButton(textForAR),
          ],
        );
      },
    );
  }

  Widget _buildARModeButton(String text) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ARPage(
              preloadedImage: _image,
              preloadedText: text,
              isSingleSymbol: true,
            ),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2B1B0E), // Deep Umber
                  const Color(0xFFD4AF37), // Royal Gold
                  const Color(0xFFFFE5B4), // Champagne Shimmer
                  const Color(0xFFD4AF37), // Royal Gold
                  const Color(0xFF2B1B0E), // Deep Umber
                ],
                stops: [
                  0.0,
                  0.3 - (0.05 * _shimmerController.value),
                  0.5,
                  0.7 + (0.05 * _shimmerController.value),
                  1.0,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Temple_Gold.withOpacity(0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Highlight shimmer
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              _shimmerController.value * 3 - 1.5,
                              -1,
                            ),
                            end: Alignment(
                              _shimmerController.value * 3 - 0.5,
                              1,
                            ),
                            colors: const [
                              Colors.transparent,
                              Colors.white,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.view_in_ar_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          AppTranslations.translate('ar_mode').toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: getAppFontFamily(),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================== HELPER WIDGETS ==================

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color cardColor,
    required Color fontColor,
    required double screenWidth,
    required double screenHeight,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: screenWidth * 0.38,
        height: screenHeight * 0.18,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Temple_Gold.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: screenWidth * 0.1, color: Temple_Gold),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fontColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(String title, String value, Color fontColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              '$title:',
              softWrap: true,
              style: TextStyle(
                color: fontColor.withAlpha(200),
                fontSize: 16,
                fontFamily: getAppFontFamily(),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fontColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
