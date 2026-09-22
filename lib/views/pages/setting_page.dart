import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import 'login_page.dart';

/// A page that displays various settings for the application.
///
/// This page includes options for managing preferences like notifications and
/// appearance, as well as support options and the ability to log out.
class SettingsPage extends StatefulWidget {
  /// Creates a new [SettingsPage] widget.
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// The state for the [SettingsPage] widget.
///
/// It manages the state of the settings, such as whether notifications are
/// enabled, and builds the UI for the settings page.
class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;

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

            final fontColor = isDarkMode
                ? Font_Color_dark_mode
                : Font_Color_light_mode;
            final backgroundColor = isDarkMode
                ? background_Color_dark_mode
                : background_Color_light_mode;
            final subFontColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
            final borderColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
            final gradientColors = isDarkMode
                ? [Gradint_Color_dark_mode1, Gradint_Color_dark_mode2]
                : [Gradint_Color_light_mode1, Gradint_Color_light_mode2];

            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Text(
              'SETTINGS',
              style: TextStyle(
                color: Temple_Gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontFamily: getAppFontFamily(),
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    'PREFERENCES',
                    style: TextStyle(
                      color: subFontColor,
                      fontSize: (screenWidth * 0.035).roundToDouble(),
                      fontFamily: getAppFontFamily(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  _buildSettingTile(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notifications',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                      activeThumbColor: gradientColors[1],
                    ),
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  _buildSettingTile(
                    icon: isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    title: 'Appearance',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDarkMode ? 'Dark Mode' : 'Light Mode',
                          style: TextStyle(
                            color: subFontColor,
                            fontSize: (screenWidth * 0.035).roundToDouble(),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: subFontColor,
                          size: 16,
                        ),
                      ],
                    ),
                    onTap: () => isDarkModeNotifier.value = !isDarkMode,
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  _buildSettingTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: subFontColor,
                      size: 16,
                    ),
                    onTap: () {
                      // TODO: Navigate to Change Password page
                    },
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  _buildSettingTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone Number',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: subFontColor,
                      size: 16,
                    ),
                    onTap: () {
                      // TODO: Navigate to Phone Number page
                    },
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  _buildSettingTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'English',
                          style: TextStyle(
                            color: subFontColor,
                            fontSize: (screenWidth * 0.035).roundToDouble(),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: subFontColor,
                          size: 16,
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Navigate to Language page
                    },
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    'SUPPORT',
                    style: TextStyle(
                      color: subFontColor,
                      fontSize: (screenWidth * 0.035).roundToDouble(),
                      fontFamily: getAppFontFamily(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  _buildSettingTile(
                    icon: Icons.help_outline,
                    title: 'Help & FAQ',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: subFontColor,
                      size: 16,
                    ),
                    onTap: () {
                      // TODO: Navigate to Help & FAQ page
                    },
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  _buildSettingTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Support',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: subFontColor,
                      size: 16,
                    ),
                    onTap: () {
                      // TODO: Navigate to Contact Support page
                    },
                    fontColor: fontColor,
                    borderColor: borderColor,
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: RadialGradient(
                        colors: gradientColors,
                        center: Alignment.center,
                        radius: 3.4,
                      ),
                    ),
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: (screenWidth * 0.05)
                                      .roundToDouble(),
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to log out?',
                                style: TextStyle(
                                  fontSize: (screenWidth * 0.04)
                                      .roundToDouble(),
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: (screenWidth * 0.04)
                                          .roundToDouble(),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: (screenWidth * 0.04)
                                          .roundToDouble(),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Text(
                        'LOG OUT',
                        style: TextStyle(
                          color: isDarkMode ? Colors.black : Colors.white,
                          fontSize: (screenWidth * 0.04).roundToDouble(),
                          fontWeight: FontWeight.w600,
                          fontFamily: getAppFontFamily(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                ],
              ),
            ),
          ),
            );
          },
        );
      },
    );
  }

  /// A helper widget to build a consistent looking tile for each setting.
  ///
  /// This widget displays an icon, a title, and a trailing widget, and can
  /// handle tap events.
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    required Color fontColor,
    required Color borderColor,
    required double screenWidth,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: fontColor),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: fontColor,
                  fontFamily: getAppFontFamily(),
                  fontWeight: FontWeight.w600,
                  fontSize: (screenWidth * 0.04).roundToDouble(),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
