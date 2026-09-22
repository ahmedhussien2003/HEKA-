import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../data/translations.dart';
import '../../general_files/color_hex.dart';

class FaqsPage extends StatefulWidget {
  const FaqsPage({super.key});

  @override
  State<FaqsPage> createState() => _FaqsPageState();
}

class _FaqsPageState extends State<FaqsPage> {
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
            final fontColor = isDarkMode ? Temple_White : Temple_Black;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
            final subTextColor = isDarkMode ? Temple_Light_Gray : Temple_Dark_Gray;

            // Define FAQ keys
            final List<Map<String, String>> faqsList = [
              {
                'q': AppTranslations.translate('faq_1_q'),
                'a': AppTranslations.translate('faq_1_a'),
              },
              {
                'q': AppTranslations.translate('faq_2_q'),
                'a': AppTranslations.translate('faq_2_a'),
              },
              {
                'q': AppTranslations.translate('faq_3_q'),
                'a': AppTranslations.translate('faq_3_a'),
              },
              {
                'q': AppTranslations.translate('faq_4_q'),
                'a': AppTranslations.translate('faq_4_a'),
              },
              {
                'q': AppTranslations.translate('faq_5_q'),
                'a': AppTranslations.translate('faq_5_a'),
              },
            ];

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
                  AppTranslations.translate('faqs').toUpperCase(),
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
              body: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: 16,
                ),
                itemCount: faqsList.length,
                itemBuilder: (context, index) {
                  final faq = faqsList[index];
                  return FAQCard(
                    question: faq['q'] ?? '',
                    answer: faq['a'] ?? '',
                    fontColor: fontColor,
                    cardColor: cardColor,
                    subTextColor: subTextColor,
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class FAQCard extends StatefulWidget {
  final String question;
  final String answer;
  final Color fontColor;
  final Color cardColor;
  final Color subTextColor;
  final bool isDarkMode;

  const FAQCard({
    super.key,
    required this.question,
    required this.answer,
    required this.fontColor,
    required this.cardColor,
    required this.subTextColor,
    required this.isDarkMode,
  });

  @override
  State<FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<FAQCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? Temple_Gold : Temple_Muted_Gold.withOpacity(0.2),
          width: _isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _toggleExpand,
          splashColor: Temple_Gold.withOpacity(0.1),
          highlightColor: Temple_Gold.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.045),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: TextStyle(
                          color: widget.fontColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: getAppFontFamily(),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Temple_Gold,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: 1.0,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Divider(
                        color: Temple_Muted_Gold.withOpacity(0.2),
                        height: 1,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.answer,
                        style: TextStyle(
                          color: widget.subTextColor,
                          fontSize: 14,
                          fontFamily: getAppFontFamily(),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
