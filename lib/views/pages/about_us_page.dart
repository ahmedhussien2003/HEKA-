import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import '../../data/translations.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  // ==========================================================
  // EDIT TEAM MEMBERS HERE
  // ==========================================================
  static const List<Map<String, String>> _teamMembers = [
    {
      'name': 'Maryam Nabil Al-Berry',
      'role': 'Supervisor / Assistant Professor',
      'image': 'assets/images/placeholder.png', // Add your image path here
    },
    {
      'name': 'Radwa Reda Hossieny',
      'role': 'Supervisor / Assistant Lecturer',
      'image':
          'assets/images/placeholder.png', // Leave empty to use default icon
    },
    {
      'name': 'Ahmad Muhammad Abdelraouf',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/Ahmad_Muhmmad.jpeg',
    },
    {
      'name': 'Ahmed Khaled Eissa',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/Ahmad_Khaled_Eissa.png',
    },
    {
      'name': 'Ahmed Hussien Sultan',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/Ahmad_Hussien.jpeg',
    },
    {
      'name': 'Ahmed Ali Mohammed',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/Ahmad_Ali.png',
    },
    {
      'name': 'Soad Saeed Ibrahim',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/placeholder.png',
    },
    {
      'name': 'Mennatullah Hassan Afify',
      'role': 'Senior Computer Science student',
      'image': 'assets/images/placeholder.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final backgroundColor = isDarkMode
            ? Temple_Background_Dark
            : Temple_Background_Light;
        final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
        final textColor = isDarkMode ? Temple_White : Temple_Black;
        final subTextColor = isDarkMode ? Temple_Light_Gray : Temple_Dark_Gray;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppTranslations.translate('about_us').toUpperCase(),
              style: TextStyle(
                color: Temple_Gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: getAppFontFamily(),
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildMainDescription(screenWidth, textColor, subTextColor),
                  const SizedBox(height: 40),
                  Text(
                    AppTranslations.translate('our_team'),
                    style: TextStyle(
                      color: Temple_Gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontFamily: getAppFontFamily(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTeamGrid(
                    screenWidth,
                    cardColor,
                    textColor,
                    subTextColor,
                  ),
                  const SizedBox(height: 120), // Spacer for floating navbar
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainDescription(
    double screenWidth,
    Color textColor,
    Color subTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.translate('about_description'),
          style: TextStyle(
            color: textColor,
            fontSize: (screenWidth * 0.055).clamp(20, 24),
            fontWeight: FontWeight.w700,
            fontFamily: getAppFontFamily(),
            height: 1.4,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          AppTranslations.translate('about_mission'),
          style: TextStyle(
            color: subTextColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: getAppFontFamily(),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamGrid(
    double screenWidth,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth > 600 ? 2 : 1,
        crossAxisSpacing: 15,
        mainAxisSpacing: 12,
        childAspectRatio: screenWidth > 600 ? 2.5 : 3.5,
      ),
      itemCount: _teamMembers.length,
      itemBuilder: (context, index) {
        final member = _teamMembers[index];
        return _buildTeamCard(
          name: member['name']!,
          role: member['role']!,
          imagePath: member['image']!,
          cardColor: cardColor,
          textColor: textColor,
          subTextColor: subTextColor,
          screenWidth: screenWidth,
        );
      },
    );
  }

  Widget _buildTeamCard({
    required String name,
    required String role,
    required String imagePath,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required double screenWidth,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (screenWidth * 0.04).clamp(12, 16),
        vertical: (screenWidth * 0.03).clamp(10, 14),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Temple_Gold.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: (screenWidth * 0.12).clamp(45, 55),
            height: (screenWidth * 0.12).clamp(45, 55),
            decoration: BoxDecoration(
              color: Temple_Gold.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Temple_Gold, width: 1.5),
            ),
            child: ClipOval(
              child: imagePath.isNotEmpty
                  ? Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Temple_Gold,
                        size: 24,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: Temple_Gold,
                      size: (screenWidth * 0.06).clamp(20, 26),
                    ),
            ),
          ),
          SizedBox(width: (screenWidth * 0.04).clamp(12, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Temple_Gold,
                    fontSize: (screenWidth * 0.038).clamp(14, 16),
                    fontWeight: FontWeight.w800,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: (screenWidth * 0.03).clamp(11, 13),
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
}
