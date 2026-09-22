import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

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
            final fontColor = isDarkMode ? Temple_White : Temple_Black;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
            final subTextColor = isDarkMode ? Temple_Light_Gray : Temple_Dark_Gray;

            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Text(
                  AppTranslations.translate('nav_saved').toUpperCase(),
                  style: TextStyle(
                    color: Temple_Gold,
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.bold,
                    fontSize: (screenWidth * 0.045).clamp(16, 22),
                    letterSpacing: 2,
                  ),
                ),
                centerTitle: true,
              ),
              body: user == null
                  ? Center(
                      child: Text(
                        AppTranslations.translate('login_prompt_saved'),
                        style: TextStyle(
                          color: fontColor,
                          fontFamily: getAppFontFamily(),
                          fontSize: (screenWidth * 0.04).clamp(14, 18),
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestoreService.getTranslationHistory(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'Error: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: (screenWidth * 0.035).clamp(12, 16),
                                ),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              AppTranslations.translate('no_saved_translations'),
                              style: TextStyle(
                                color: subTextColor,
                                fontFamily: getAppFontFamily(),
                                fontSize: (screenWidth * 0.04).clamp(14, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        // Filter only "Saved" types on client side
                        final savedDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final type = data['Type'] ?? '';
                          return type.toString().startsWith('Saved');
                        }).toList();

                        if (savedDocs.isEmpty) {
                          return Center(
                            child: Text(
                              AppTranslations.translate('no_saved_translations'),
                              style: TextStyle(
                                color: subTextColor,
                                fontFamily: getAppFontFamily(),
                                fontSize: (screenWidth * 0.04).clamp(14, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.only(
                            left: screenWidth * 0.05,
                            right: screenWidth * 0.05,
                            top: 10,
                            bottom: 80,
                          ),
                          itemCount: savedDocs.length,
                          itemBuilder: (context, index) {
                            try {
                              final docId = savedDocs[index].id;
                              final data =
                                  savedDocs[index].data() as Map<String, dynamic>;
                              return _buildSavedCard(
                                docId: docId,
                                uid: user.uid,
                                data: data,
                                cardColor: cardColor,
                                fontColor: fontColor,
                                subTextColor: subTextColor,
                                isDarkMode: isDarkMode,
                                screenWidth: screenWidth,
                              );
                            } catch (e) {
                              debugPrint(
                                'Error rendering saved card at index $index: $e',
                              );
                              return const SizedBox.shrink();
                            }
                          },
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedCard({
    required String docId,
    required String uid,
    required Map<String, dynamic> data,
    required Color cardColor,
    required Color fontColor,
    required Color subTextColor,
    required bool isDarkMode,
    required double screenWidth,
  }) {
    final timestamp = data['Date'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate())
        : 'Unknown Date';
    final rawType = data['Type'] ?? 'Saved';
    // Friendly displays: Saved Single Symbol -> Single Symbol, Saved Multi Symbols -> Multi Symbols
    final String typeDisplay = rawType.toString() == 'Saved Single Symbol'
        ? AppTranslations.translate('saved_single')
        : rawType.toString() == 'Saved Multi Symbols'
            ? AppTranslations.translate('saved_multi')
            : AppTranslations.translate('nav_saved');

    final meaning = AppTranslations.getTranslationMeaning(data, selectedLanguageNotifier.value);
    final base64ImageStr = data['image_base64'] as String?;
    final imageBytes = base64ImageStr != null ? base64Decode(base64ImageStr) : null;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.04),
      padding: EdgeInsets.all(screenWidth * 0.045),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Temple_Gold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved Image
          if (imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                width: 85,
                height: 85,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black26 : Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Temple_Gold.withOpacity(0.15)),
              ),
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: fontColor.withOpacity(0.4),
                  size: 28,
                ),
              ),
            ),
          const SizedBox(width: 16),
          // Translation details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: rawType == 'Saved Single Symbol'
                                ? Temple_Gold
                                : Temple_Teal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeDisplay.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.bookmark_rounded,
                        color: Temple_Gold,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        try {
                          await _firestoreService.deleteTranslation(uid, docId);
                          await _firestoreService.decrementSavedGlyphsCount(uid);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppTranslations.translate('removed_saved_success'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: getAppFontFamily(),
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
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
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meaning,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fontColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: getAppFontFamily(),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
