import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';
import 'ar_page.dart';

class ManySymbolsPage extends StatefulWidget {
  const ManySymbolsPage({super.key});

  @override
  State<ManySymbolsPage> createState() => _ManySymbolsPageState();
}

class _ManySymbolsPageState extends State<ManySymbolsPage>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  File? _image;
  bool _imageSelected = false;
  bool _isLoading = false;
  bool _isPickingImage = false;
  String? _errorMessage;
  List<String> _gardinerCodes = [];
  List<String> _englishWords = [];
  List<String> _arabicWords = [];
  String? _nlpSentence;
  String? _arabicNlpSentence;
  String? _userLanguageSentence;
  String? _italianNlpSentence;
  String? _germanNlpSentence;
  String? _spanishNlpSentence;
  String? _russianNlpSentence;
  String? _polishNlpSentence;
  Duration? _apiExecutionTime;
  bool _showARButton = false;
  bool _isSaved = false;
  String? _savedDocId;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 60),
      sendTimeout: const Duration(minutes: 60),
      receiveTimeout: const Duration(minutes: 60),
    ),
  );

  static const String _translatePath = "/translate";
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
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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
        File finalImage = File(image.path);
        bool shouldProceed = true;

        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: image.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Hieroglyphs',
                toolbarColor: Theme.of(context).primaryColor,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
              ),
              IOSUiSettings(
                title: 'Crop Hieroglyphs',
                aspectRatioLockEnabled: false,
              ),
            ],
          );
          if (croppedFile != null) {
            finalImage = File(croppedFile.path);
          } else {
            shouldProceed = false;
          }
        } catch (e) {
          debugPrint('Cropping failed, falling back to original image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cropper not initialized. Using original image.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
            );
          }
        }

        if (shouldProceed) {
          setState(() {
            _image = finalImage;
            _imageSelected = true;
            _errorMessage = null;
            _gardinerCodes = [];
            _englishWords = [];
            _arabicWords = [];
            _nlpSentence = null;
            _arabicNlpSentence = null;
            _apiExecutionTime = null;
            _isSaved = false;
            _savedDocId = null;
          });
          await _sendImageToAPI();
        }
      }
    } on PlatformException catch (e) {
      if (e.code != 'already_active') {
        _setStateIfMounted(() {
          _errorMessage = 'Failed to pick image: ${e.message ?? e.code}';
        });
      }
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _cropImage() async {
    if (_image == null || _isLoading) return;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _image!.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Hieroglyphs',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Hieroglyphs',
            aspectRatioLockEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _image = File(croppedFile.path);
          _gardinerCodes = [];
          _englishWords = [];
          _arabicWords = [];
          _nlpSentence = null;
          _arabicNlpSentence = null;
          _apiExecutionTime = null;
          _isSaved = false;
          _savedDocId = null;
        });
        await _sendImageToAPI();
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cropper not initialized. Please rebuild/restart the app, or use the original image.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _imageSelected = false;
      _isLoading = false;
      _errorMessage = null;
      _gardinerCodes = [];
      _englishWords = [];
      _arabicWords = [];
      _nlpSentence = null;
      _arabicNlpSentence = null;
      _userLanguageSentence = null;
      _italianNlpSentence = null;
      _germanNlpSentence = null;
      _spanishNlpSentence = null;
      _russianNlpSentence = null;
      _polishNlpSentence = null;
      _apiExecutionTime = null;
      _showARButton = false;
      _isSaved = false;
      _savedDocId = null;
    });
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
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

  Future<void> _saveResult() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.translate('login_prompt_saved') ??
                'Please login to save translations',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
      );
      return;
    }
    final text = _getPrimaryDisplaySentence();
    if (text == null || text.isEmpty) return;

    try {
      final base64Image = await _resizeAndCompressImage(_image);

      final docRef = await _firestoreService.recordTranslation(user.uid, {
        'Date': Timestamp.now(),
        'Type': 'Saved Multi Symbols',
        'Meaning': text,
        'MeaningEnglish': _nlpSentence ?? _buildEnglishStatement(),
        'MeaningArabic': _arabicNlpSentence ?? 'N/A',
        'MeaningItalian': _italianNlpSentence ?? 'N/A',
        'MeaningGerman': _germanNlpSentence ?? 'N/A',
        'MeaningSpanish': _spanishNlpSentence ?? 'N/A',
        'MeaningRussian': _russianNlpSentence ?? 'N/A',
        'MeaningPolish': _polishNlpSentence ?? 'N/A',
        'MeaningUser': _userLanguageSentence ?? 'N/A',
        'SavedLanguage': selectedLanguageNotifier.value,
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

  String _resolveApiBaseUrl() {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return "http://localhost:8001";
    if (Platform.isAndroid) return "http://10.187.52.11:8001";
    return "http://localhost:8001";
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

  Future<void> _sendImageToAPI() async {
    if (_image == null) return;

    debugPrint('\n${'=' * 60}');
    debugPrint('[Multi-Symbol] Starting translation request...');
    debugPrint('${'=' * 60}');

    _setStateIfMounted(() {
      _isLoading = true;
      _errorMessage = null;
      _gardinerCodes = [];
      _englishWords = [];
      _arabicWords = [];
      _nlpSentence = null;
      _arabicNlpSentence = null;
      _userLanguageSentence = null;
      _apiExecutionTime = null;
      _isSaved = false;
      _savedDocId = null;
    });

    final stopwatch = Stopwatch()..start();

    // Periodic heartbeat timer so we know the request is still alive
    int heartbeatCount = 0;
    final heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      heartbeatCount++;
      final elapsed = stopwatch.elapsed;
      debugPrint(
        '[Multi-Symbol] ⏳ Still waiting for server response... '
        '(${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed)',
      );
    });

    try {
      // --- Step 1: Prepare the image file ---
      final fileSize = await _image!.length();
      String fileName = _image!.path.split('/').last;
      debugPrint(
        '[Multi-Symbol] 📁 Preparing image: $fileName '
        '(${(fileSize / 1024).toStringAsFixed(1)} KB)',
      );

      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(_image!.path, filename: fileName),
      });
      debugPrint('[Multi-Symbol] ✅ FormData created successfully');

      // --- Step 2: Resolve language ---
      final currentLang = kSupportedLanguages.firstWhere(
        (l) => l['name'] == selectedLanguageNotifier.value,
        orElse: () => kSupportedLanguages[1],
      );
      final langCode = currentLang['code'] ?? 'en';
      final requestUrl = "$_apiBaseUrl$_translatePath?target_lang=$langCode";
      debugPrint('[Multi-Symbol] 🌐 Target language: $langCode');
      debugPrint('[Multi-Symbol] 🚀 Sending POST to: $requestUrl');

      // --- Step 3: Send request with upload progress ---
      var response = await _dio.post(
        requestUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final percent = ((sent / total) * 100).toStringAsFixed(0);
            debugPrint(
              '[Multi-Symbol] 📤 Upload progress: $percent% '
              '($sent / $total bytes)',
            );
          }
        },
        onReceiveProgress: (received, total) {
          debugPrint(
            '[Multi-Symbol] 📥 Receiving response data... '
            '($received bytes received)',
          );
        },
      );

      // --- Step 4: Process response ---
      final elapsed = stopwatch.elapsed;
      debugPrint(
        '[Multi-Symbol] ✅ Response received! '
        'Status: ${response.statusCode} '
        '(took ${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s)',
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final serverError = data['error'] ?? data['detail'];
        if (serverError != null) {
          debugPrint('[Multi-Symbol] ❌ Server returned error: $serverError');
          _setStateIfMounted(() {
            _errorMessage = serverError.toString();
          });
        } else {
          // --- Step 5: Parse results ---
          final gardinerList = (data['gardiner_code'] as List<dynamic>? ?? []);
          final englishList = (data['english'] as List<dynamic>? ?? []);
          debugPrint('[Multi-Symbol] 📊 Parsed results:');
          debugPrint(
            '  • Gardiner codes: ${gardinerList.length} symbols detected',
          );
          debugPrint('  • Gardiner: ${gardinerList.join(", ")}');
          debugPrint('  • English words: ${englishList.join(", ")}');
          debugPrint('  • NLP Sentence: ${data['Sentence']}');
          debugPrint('  • Arabic Sentence: ${data['Arabic_NLP_result']}');
          if (data['server_execution_time_ms'] != null) {
            debugPrint(
              '  • Server processing time: '
              '${data['server_execution_time_ms']} ms',
            );
          }

          _setStateIfMounted(() {
            _gardinerCodes = gardinerList.map((e) => e.toString()).toList();
            _englishWords = englishList.map((e) => e.toString()).toList();
            _arabicWords = (data['arabic'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            _nlpSentence = data['Sentence']?.toString();
            _arabicNlpSentence = data['Arabic_NLP_result']?.toString();
            _userLanguageSentence = data['Target_Language_Result']?.toString();
            _italianNlpSentence = data['meaning_italian']?.toString();
            _germanNlpSentence = data['meaning_german']?.toString();
            _spanishNlpSentence = data['meaning_spanish']?.toString();
            _russianNlpSentence = data['meaning_russian']?.toString();
            _polishNlpSentence = data['meaning_polish']?.toString();
          });

          // Record translation in Firestore
          final User? user = _auth.currentUser;
          if (user != null) {
            try {
              debugPrint(
                '[Multi-Symbol] 💾 Recording translation to Firestore...',
              );
              await _firestoreService.incrementTranslationCount(user.uid);
              await _firestoreService.recordTranslation(user.uid, {
                'Date': Timestamp.now(),
                'Type': 'Multi Symbols',
                'Meaning':
                    _getPrimaryDisplaySentence() ?? _buildEnglishStatement(),
                'MeaningEnglish': _nlpSentence ?? _buildEnglishStatement(),
                'MeaningArabic': _arabicNlpSentence ?? 'N/A',
                'MeaningItalian': _italianNlpSentence ?? 'N/A',
                'MeaningGerman': _germanNlpSentence ?? 'N/A',
                'MeaningSpanish': _spanishNlpSentence ?? 'N/A',
                'MeaningRussian': _russianNlpSentence ?? 'N/A',
                'MeaningPolish': _polishNlpSentence ?? 'N/A',
                'MeaningUser': _userLanguageSentence ?? 'N/A',
                'SavedLanguage': selectedLanguageNotifier.value,
              });
              debugPrint(
                '[Multi-Symbol] ✅ Translation recorded for ${user.uid}',
              );
            } catch (e) {
              debugPrint('[Multi-Symbol] ⚠️ Firestore recording failed: $e');
            }
          }
        }
      } else {
        debugPrint(
          '[Multi-Symbol] ❌ Unexpected response: '
          'status=${response.statusCode}, body=${response.data}',
        );
        _setStateIfMounted(() {
          _errorMessage =
              response.data?['error'] ??
              response.data?['detail'] ??
              'Failed to translate symbols';
        });
      }
    } on DioException catch (e) {
      final elapsed = stopwatch.elapsed;
      debugPrint(
        '\n[Multi-Symbol] ❌ DioException after '
        '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s:',
      );
      debugPrint('  • Type: ${e.type}');
      debugPrint('  • Message: ${e.message}');
      if (e.response != null) {
        debugPrint('  • Status code: ${e.response?.statusCode}');
        debugPrint('  • Response body: ${e.response?.data}');
      }

      _setStateIfMounted(() {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          _errorMessage =
              data['error']?.toString() ??
              data['detail']?.toString() ??
              'Network error occurred';
        } else if (e.type == DioExceptionType.connectionTimeout) {
          _errorMessage =
              'Connection timeout: Could not reach the server at '
              '$_apiBaseUrl. Make sure the Python server is running.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          _errorMessage =
              'Server is taking too long to respond. '
              'The model may still be processing — check the Python '
              'server terminal for progress.';
        } else if (e.type == DioExceptionType.sendTimeout) {
          _errorMessage =
              'Upload timeout: Failed to send the image '
              'to the server in time.';
        } else if (e.type == DioExceptionType.connectionError) {
          _errorMessage =
              'Connection error: Cannot connect to '
              '$_apiBaseUrl. Is the Python server running?';
        } else {
          _errorMessage =
              data?.toString() ?? e.message ?? 'Network error occurred';
        }
      });
    } catch (e) {
      debugPrint('[Multi-Symbol] ❌ Unexpected error: $e');
      _setStateIfMounted(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      heartbeatTimer.cancel();
      stopwatch.stop();
      debugPrint(
        '\n[Multi-Symbol] 🏁 Request finished in '
        '${stopwatch.elapsed.inMinutes}m '
        '${stopwatch.elapsed.inSeconds % 60}s',
      );
      if (_errorMessage != null) {
        debugPrint('[Multi-Symbol] ❌ Final error: $_errorMessage');
      } else {
        debugPrint('[Multi-Symbol] ✅ Translation completed successfully!');
      }
      debugPrint('${'=' * 60}\n');

      _setStateIfMounted(() {
        _isLoading = false;
        _apiExecutionTime = stopwatch.elapsed;
        if (_errorMessage == null && _getPrimaryDisplaySentence() != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _setStateIfMounted(() {
              _showARButton = true;
            });
          });
        }
      });
    }
  }

  String _buildEnglishStatement() {
    if (_englishWords.isEmpty) return '';
    if (_englishWords.length == 1) return '${_englishWords.first}.';
    if (_englishWords.length == 2) {
      return '${_englishWords[0]} and ${_englishWords[1]}.';
    }
    final allButLast = _englishWords
        .sublist(0, _englishWords.length - 1)
        .join(', ');
    final last = _englishWords.last;
    return '$allButLast, and $last.';
  }

  String _formatExecutionTime(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return "${duration.inMilliseconds} ms";
    }
    return "${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: selectedLanguageNotifier,
          builder: (context, language, child) {
            final screenWidth = MediaQuery.of(context).size.width;
            final fontColor = isDarkMode ? Temple_White : Temple_Black;
            final backgroundColor = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;

            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: fontColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(-0.05),
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      for (double i = 2; i > 0; i -= 0.5)
                        Transform.translate(
                          offset: Offset(i, i),
                          child: Text(
                            AppTranslations.translate('multi_symbols_title'),
                            style: TextStyle(
                              color: const Color(0xFF3E2723),
                              fontFamily: getAppFontFamily(),
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      Text(
                        AppTranslations.translate('multi_symbols_title'),
                        style: TextStyle(
                          color: Temple_Gold,
                          fontFamily: getAppFontFamily(),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: _imageSelected
                          ? _buildShrunkenCards(
                              context,
                              cardColor,
                              fontColor,
                              screenWidth,
                            )
                          : _buildInitialCards(
                              context,
                              cardColor,
                              fontColor,
                              screenWidth,
                            ),
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
                    if (_imageSelected && !_isLoading)
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
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
                        )
                      else
                        _buildResultsSection(fontColor, screenWidth, cardColor),
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
    return Column(
      key: const ValueKey('initialCards'),
      children: [
        Row(
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
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildARModeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ARPage(
              preloadedImage: _image,
              preloadedText: _getPrimaryDisplaySentence(),
              isSingleSymbol: false,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final tween = Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 500),
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
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 1,
                  offset: const Offset(-1, -1),
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
                  // Liquid gold shimmer overlay
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

  Widget _buildShrunkenCards(
    BuildContext context,
    Color cardColor,
    Color fontColor,
    double screenWidth,
  ) {
    return Container(
      key: const ValueKey('shrunkenCards'),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
            onPressed: _isLoading ? null : _cropImage,
            icon: Icon(
              Icons.crop,
              color: _isLoading ? fontColor.withAlpha(80) : fontColor,
            ),
            tooltip: AppTranslations.translate('crop_image') ?? 'Crop Image',
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

  Widget _buildResultsSection(
    Color fontColor,
    double screenWidth,
    Color cardColor,
  ) {
    final maxRows = [
      _gardinerCodes.length,
      _englishWords.length,
      _arabicWords.length,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Stack(
          children: [
            for (double i = 2; i > 0; i -= 0.5)
              Transform.translate(
                offset: Offset(i, i),
                child: Text(
                  AppTranslations.translate('detected_symbols'),
                  style: TextStyle(
                    color: const Color(0xFF3E2723),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: getAppFontFamily(),
                    letterSpacing: 2,
                  ),
                ),
              ),
            Text(
              AppTranslations.translate('detected_symbols'),
              style: TextStyle(
                color: fontColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: Temple_Gold.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
          },
          children: List<TableRow>.generate(maxRows == 0 ? 1 : maxRows + 1, (
            rowIndex,
          ) {
            if (rowIndex == 0) {
              return TableRow(
                decoration: BoxDecoration(
                  color: Temple_Gold.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                children: [
                  _buildHeaderCell(
                    AppTranslations.translate('gardiner_label'),
                    fontColor,
                  ),
                  _buildHeaderCell(
                    AppTranslations.translate('english_label'),
                    fontColor,
                  ),
                  _buildHeaderCell(
                    AppTranslations.translate('arabic_label'),
                    fontColor,
                  ),
                ],
              );
            }

            final dataIndex = rowIndex - 1;
            final gardiner = dataIndex < _gardinerCodes.length
                ? _gardinerCodes[dataIndex]
                : '—';
            final english = dataIndex < _englishWords.length
                ? _englishWords[dataIndex]
                : '—';
            final arabic = dataIndex < _arabicWords.length
                ? _arabicWords[dataIndex]
                : '—';

            return TableRow(
              children: [
                _buildCell(gardiner, fontColor, isGardiner: true),
                _buildCell(english, fontColor),
                _buildCell(arabic, fontColor),
              ],
            );
          }),
        ),
        const SizedBox(height: 24),
        if (_englishWords.isNotEmpty) ...[
          ValueListenableBuilder<bool>(
            valueListenable: showArabicEnglishNotifier,
            builder: (context, showArEn, _) {
              final currentLang = selectedLanguageNotifier.value;
              final bool isEnglish = currentLang == 'English';
              final bool isArabic = currentLang == 'Arabic';

              List<Widget> statementWidgets = [];

              if (showArEn) {
                // Show Arabic
                if (_arabicNlpSentence != null &&
                    _arabicNlpSentence!.isNotEmpty) {
                  statementWidgets.add(
                    _buildStatementCard(
                      title: AppTranslations.translate(
                        'arabic_statement_label',
                      ),
                      statement: _arabicNlpSentence!,
                      fontColor: fontColor,
                      cardColor: cardColor,
                      showBookmark: isArabic,
                      isBookmarked: _isSaved,
                      onBookmarkTap: _toggleBookmark,
                    ),
                  );
                  statementWidgets.add(const SizedBox(height: 24));
                }

                // Show English
                final englishStatement =
                    (_nlpSentence != null && _nlpSentence!.isNotEmpty)
                    ? _nlpSentence!
                    : _buildEnglishStatement();
                if (englishStatement.isNotEmpty) {
                  statementWidgets.add(
                    _buildStatementCard(
                      title: AppTranslations.translate('statement_label'),
                      statement: englishStatement,
                      fontColor: fontColor,
                      cardColor: cardColor,
                      showBookmark: isEnglish,
                      isBookmarked: _isSaved,
                      onBookmarkTap: _toggleBookmark,
                    ),
                  );
                  statementWidgets.add(const SizedBox(height: 24));
                }

                // Show User Language (if not English or Arabic)
                if (!isEnglish && !isArabic) {
                  final userStmt = _getPrimaryDisplaySentence();
                  if (userStmt != null && userStmt.isNotEmpty) {
                    statementWidgets.add(
                      _buildStatementCard(
                        title:
                            "${AppTranslations.translate('statement_label')} ($currentLang)",
                        statement: userStmt,
                        fontColor: fontColor,
                        cardColor: cardColor,
                        showBookmark: !isEnglish && !isArabic,
                        isBookmarked: _isSaved,
                        onBookmarkTap: _toggleBookmark,
                      ),
                    );
                    statementWidgets.add(const SizedBox(height: 24));
                  }
                }
              } else {
                // Show only User Language
                String? displayStatement = _getPrimaryDisplaySentence();
                String displayTitle = AppTranslations.translate(
                  'statement_label',
                );

                if (isArabic) {
                  displayTitle = AppTranslations.translate(
                    'arabic_statement_label',
                  );
                } else if (!isEnglish) {
                  displayTitle = "$displayTitle ($currentLang)";
                }

                if (displayStatement != null && displayStatement.isNotEmpty) {
                  statementWidgets.add(
                    _buildStatementCard(
                      title: displayTitle,
                      statement: displayStatement,
                      fontColor: fontColor,
                      cardColor: cardColor,
                      showBookmark: true,
                      isBookmarked: _isSaved,
                      onBookmarkTap: _toggleBookmark,
                    ),
                  );
                  statementWidgets.add(const SizedBox(height: 24));
                }
              }

              return Column(children: statementWidgets);
            },
          ),
        ],
        if (_apiExecutionTime != null)
          Text(
            '${AppTranslations.translate('execution_time')}: ${_formatExecutionTime(_apiExecutionTime!)}',
            style: TextStyle(
              color: fontColor.withOpacity(0.7),
              fontSize: 22,
              fontFamily: getAppFontFamily(),
              fontWeight: FontWeight.w600,
            ),
          ),
        // ── AR Mode button — appears after translation result ──────────────
        if (_image != null && _showARButton) ...[
          const SizedBox(height: 28),
          AnimatedOpacity(
            opacity: _showARButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: _buildResultsARButton(fontColor),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// Returns the best single-sentence translation in the user's language.
  String? _getPrimaryDisplaySentence() {
    final currentLang = selectedLanguageNotifier.value;
    if (currentLang == 'English') {
      final String s = (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence!
          : _buildEnglishStatement();
      return s.isEmpty ? null : s;
    } else if (currentLang == 'Arabic') {
      return (_arabicNlpSentence != null && _arabicNlpSentence!.isNotEmpty)
          ? _arabicNlpSentence
          : null;
    } else if (currentLang == 'Italian') {
      return (_italianNlpSentence != null && _italianNlpSentence!.isNotEmpty)
          ? _italianNlpSentence
          : (_userLanguageSentence != null && _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    } else if (currentLang == 'German') {
      return (_germanNlpSentence != null && _germanNlpSentence!.isNotEmpty)
          ? _germanNlpSentence
          : (_userLanguageSentence != null && _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    } else if (currentLang == 'Spanish') {
      return (_spanishNlpSentence != null && _spanishNlpSentence!.isNotEmpty)
          ? _spanishNlpSentence
          : (_userLanguageSentence != null && _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    } else if (currentLang == 'Russian') {
      return (_russianNlpSentence != null && _russianNlpSentence!.isNotEmpty)
          ? _russianNlpSentence
          : (_userLanguageSentence != null && _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    } else if (currentLang == 'Polish') {
      return (_polishNlpSentence != null && _polishNlpSentence!.isNotEmpty)
          ? _polishNlpSentence
          : (_userLanguageSentence != null && _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    } else {
      return (_userLanguageSentence != null &&
              _userLanguageSentence!.isNotEmpty)
          ? _userLanguageSentence
          : (_nlpSentence != null && _nlpSentence!.isNotEmpty)
          ? _nlpSentence
          : null;
    }
  }

  Widget _buildResultsARButton(Color fontColor) {
    return GestureDetector(
      onTap: () {
        final text = _getPrimaryDisplaySentence();
        if (_image == null || text == null) return;
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ARPage(
              preloadedImage: _image,
              preloadedText: text,
              isSingleSymbol: false,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final tween = Tween(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF6B4F00),
              Temple_Gold,
              Color(0xFFFFE57F),
              Temple_Gold,
              Color(0xFF6B4F00),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Temple_Gold.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.view_in_ar_rounded,
              color: Colors.black87,
              size: 26,
            ),
            const SizedBox(width: 12),
            Text(
              AppTranslations.translate('ar_mode'),
              style: TextStyle(
                color: Colors.black87,
                fontFamily: getAppFontFamily(),
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, Color fontColor) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fontColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: getAppFontFamily(),
        ),
      ),
    );
  }

  Widget _buildCell(String text, Color fontColor, {bool isGardiner = false}) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fontColor,
          fontSize: isGardiner ? 22 : 18,
          fontWeight: FontWeight.w600,
          fontFamily: isGardiner ? 'Gardiner' : getAppFontFamily(),
        ),
      ),
    );
  }

  Widget _buildStatementCard({
    required String title,
    required String statement,
    required Color fontColor,
    required Color cardColor,
    bool showBookmark = false,
    bool isBookmarked = false,
    VoidCallback? onBookmarkTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: fontColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: getAppFontFamily(),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(right: showBookmark ? 40.0 : 0.0),
                child: Text(
                  statement,
                  style: TextStyle(
                    color: fontColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ),
            ],
          ),
          if (showBookmark)
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: Temple_Gold,
                  size: 26,
                ),
                onPressed: onBookmarkTap,
              ),
            ),
        ],
      ),
    );
  }
}
