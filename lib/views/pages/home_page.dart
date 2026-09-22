import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../data/translations.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import 'many_symbols_page.dart';
import 'one_symbol_page.dart';
import 'history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
            final topInset = MediaQuery.of(context).padding.top;

            final backgroundColor = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
            final textColor = isDarkMode ? Temple_White : Temple_Black;
            final subTextColor = isDarkMode
                ? Temple_Light_Gray
                : Temple_Dark_Gray;

            return Scaffold(
              backgroundColor: backgroundColor,
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: topInset + 20),
                    _buildHeader(screenWidth, textColor),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildARScanCard(
                        screenWidth,
                        screenHeight,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSymbolGrid(
                        context,
                        screenWidth,
                        cardColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildExplorerTip(
                        screenWidth,
                        cardColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildRecentTranslationsHeader(
                        screenWidth,
                        textColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _auth.currentUser == null
                          ? Text(
                              AppTranslations.translate('home_login_history'),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: subTextColor,
                                fontFamily: getAppFontFamily(),
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: _firestoreService.getTranslationHistory(
                                _auth.currentUser!.uid,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    AppTranslations.translate(
                                      'home_error_history',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(color: Colors.red),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Text(
                                    AppTranslations.translate(
                                      'home_no_history',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontFamily: getAppFontFamily(),
                                    ),
                                  );
                                }

                                final docs = snapshot.data!.docs
                                    .take(2)
                                    .toList();
                                return Column(
                                  children: docs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final rawType =
                                        data['Type'] ?? 'Unknown Type';
                                    
                                    final meaning = AppTranslations.getTranslationMeaning(data, selectedLanguageNotifier.value);

                                    // Map Firestore type to translation key
                                    String typeKey;
                                    if (rawType == 'Single Symbol') {
                                      typeKey = 'type_single';
                                    } else if (rawType == 'Multi Symbols') {
                                      typeKey = 'type_multi';
                                    } else if (rawType == 'Saved Single Symbol') {
                                      typeKey = 'saved_single';
                                    } else if (rawType == 'Saved Multi Symbols') {
                                      typeKey = 'saved_multi';
                                    } else {
                                      typeKey = rawType.toString();
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: _buildRecentTranslationCard(
                                        AppTranslations.translate(typeKey),
                                        meaning.toString(),
                                        'assets/images/NileKey_edit.png',
                                        screenWidth,
                                        cardColor,
                                        textColor,
                                        subTextColor,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildDailyArchetypeCard(
                        screenWidth,
                        cardColor,
                        textColor,
                        subTextColor,
                      ),
                    ),
                    const SizedBox(height: 120), // Spacer for floating navbar
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(double screenWidth, Color textColor) {
    return Center(
      child: Text(
        AppTranslations.translate('home_explore'),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          color: textColor,
          fontSize: (screenWidth * 0.08).roundToDouble(),
          fontFamily: getAppFontFamily(),
          fontWeight: FontWeight.w800, // Extra bold for header
        ),
      ),
    );
  }

  Widget _buildARScanCard(
    double screenWidth,
    double screenHeight,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      width: double.infinity,
      height: (screenWidth * 0.55).clamp(200, 240), // Responsive height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        image: const DecorationImage(
          image: AssetImage('assets/images/egyptian_hieroglyphs_wall.png'),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
        ),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Temple_Gold.withOpacity(0.2),
              border: Border.all(color: Temple_Gold, width: 2),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Temple_Gold,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppTranslations.translate('home_ar_scan'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: (screenWidth * 0.06).clamp(22, 28).toDouble(),
              fontWeight: FontWeight.w900,
              fontFamily: getAppFontFamily(),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              AppTranslations.translate('home_ar_desc'),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: getAppFontFamily(),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolGrid(
    BuildContext context,
    double screenWidth,
    Color cardColor,
    Color subTextColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align to top
      children: [
        Expanded(
          child: _buildFeatureBox(
            screenWidth: screenWidth,
            title: AppTranslations.translate('home_single_title'),
            description: AppTranslations.translate('home_single_desc'),
            icon: Icons.unfold_more,
            iconColor: Colors.black,
            boxColor: Temple_Gold,
            titleColor: Temple_Gold,
            cardColor: cardColor,
            subTextColor: subTextColor,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const OneSymbolPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildFeatureBox(
            screenWidth: screenWidth,
            title: AppTranslations.translate('home_multi_title'),
            description: AppTranslations.translate('home_multi_desc'),
            icon: Icons.menu_book,
            iconColor: Colors.white,
            boxColor: Temple_Teal,
            titleColor: Temple_Teal,
            cardColor: cardColor,
            subTextColor: subTextColor,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ManySymbolsPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBox({
    required double screenWidth,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color boxColor,
    required Color titleColor,
    required Color cardColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minHeight: (screenWidth * 0.58).clamp(220, 280),
        ), // Responsive minHeight
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: titleColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 55, // Slightly smaller icon box
              height: 55,
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 30)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: titleColor,
                fontSize: (screenWidth * 0.045).clamp(
                  16,
                  20,
                ), // Responsive size
                fontWeight: FontWeight.w800,
                fontFamily: getAppFontFamily(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                color: subTextColor,
                fontSize: (screenWidth * 0.035).clamp(
                  12,
                  14,
                ), // Responsive size
                fontWeight: FontWeight.w600,
                fontFamily: getAppFontFamily(),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorerTip(
    double screenWidth,
    Color cardColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: const Border(left: BorderSide(color: Temple_Gold, width: 6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Temple_Gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.lightbulb, color: Temple_Gold, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.translate('home_tip_title'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Temple_Gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: getAppFontFamily(),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppTranslations.translate('home_tip_desc'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: (screenWidth * 0.04).clamp(
                      14,
                      17,
                    ), // Responsive size
                    fontWeight: FontWeight.w600,
                    fontFamily: getAppFontFamily(),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTranslationsHeader(double screenWidth, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            AppTranslations.translate('home_recent'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              fontFamily: getAppFontFamily(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const HistoryPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
            child: Text(
              AppTranslations.translate('home_view_history'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: Temple_Gold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFamily: getAppFontFamily(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTranslationCard(
    String title,
    String subtitle,
    String imagePath,
    double screenWidth,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyArchetypeCard(
    double screenWidth,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Temple_Gold.withOpacity(0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, Temple_Gold.withOpacity(0.08)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Temple_Gold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppTranslations.translate('home_daily_title'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppTranslations.translate('home_djed_pillar'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: (screenWidth * 0.09).clamp(30, 42), // Responsive size
              fontWeight: FontWeight.w900,
              fontFamily: getAppFontFamily(),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            AppTranslations.translate('home_djed_desc'),
            overflow: TextOverflow.ellipsis,
            maxLines: 4,
            style: TextStyle(
              color: subTextColor,
              fontSize: (screenWidth * 0.042).clamp(15, 18), // Responsive size
              fontFamily: getAppFontFamily(),
              fontWeight: FontWeight.w600,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate('home_freq'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Temple_Gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.translate('home_common'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate('home_element'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Temple_Gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.translate('home_earth'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
