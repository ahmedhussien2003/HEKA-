import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';
import '../../services/firestore_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
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
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: fontColor,
                    size: (screenWidth * 0.05).clamp(18, 24),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  AppTranslations.translate('history_title').toUpperCase(),
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
                        AppTranslations.translate('login_prompt_history'),
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
                              AppTranslations.translate('no_history'),
                              style: TextStyle(
                                color: subTextColor,
                                fontFamily: getAppFontFamily(),
                                fontSize: (screenWidth * 0.04).clamp(14, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        final historyDocs = snapshot.data!.docs;

                        return ListView.builder(
                          padding: EdgeInsets.only(
                            left: screenWidth * 0.05,
                            right: screenWidth * 0.05,
                            top: 10,
                            bottom: 80, // Add space after the last card
                          ),
                          itemCount: historyDocs.length,
                          itemBuilder: (context, index) {
                            try {
                              final data =
                                  historyDocs[index].data() as Map<String, dynamic>;
                              return _buildHistoryCard(
                                data: data,
                                cardColor: cardColor,
                                fontColor: fontColor,
                                subTextColor: subTextColor,
                                isDarkMode: isDarkMode,
                                screenWidth: screenWidth,
                              );
                            } catch (e) {
                              debugPrint(
                                'Error rendering card at index $index: $e',
                              );
                              return const SizedBox.shrink(); // Hide problematic card
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

  Widget _buildHistoryCard({
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
    final type = data['Type'] ?? 'Unknown Type';
    final meaning = AppTranslations.getTranslationMeaning(data, selectedLanguageNotifier.value);
    final location = data['location'];

    // Translate the type label
    final String typeDisplay = type.toString() == 'Single Symbol'
        ? AppTranslations.translate('type_single')
        : type.toString() == 'Multi Symbols'
            ? AppTranslations.translate('type_multi')
            : type.toString() == 'Saved Single Symbol'
                ? AppTranslations.translate('saved_single')
                : type.toString() == 'Saved Multi Symbols'
                    ? AppTranslations.translate('saved_multi')
                    : type.toString();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: type == 'Single Symbol' || type == 'Saved Single Symbol'
                          ? Temple_Gold
                          : Temple_Teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      typeDisplay.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: (screenWidth * 0.025).clamp(10, 12),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  dateStr,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: (screenWidth * 0.03).clamp(11, 14),
                    fontFamily: getAppFontFamily(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            AppTranslations.translate('meaning_label'),
            style: TextStyle(
              color: Temple_Gold,
              fontSize: (screenWidth * 0.035).clamp(13, 16),
              fontWeight: FontWeight.bold,
              fontFamily: getAppFontFamily(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meaning,
            style: TextStyle(
              color: fontColor,
              fontSize: (screenWidth * 0.042).clamp(16, 20),
              fontWeight: FontWeight.w600,
              fontFamily: getAppFontFamily(),
              height: 1.4,
            ),
          ),
          if (location != null && location.toString().isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.03),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Temple_Gold,
                  size: (screenWidth * 0.04).clamp(14, 18),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location.toString(),
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: (screenWidth * 0.032).clamp(11, 15),
                      fontFamily: getAppFontFamily(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
