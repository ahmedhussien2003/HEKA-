import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';

class SignupHeader extends StatelessWidget implements PreferredSizeWidget {
  const SignupHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: isDarkModeNotifier,
        builder: (context, isDarkMode, child) {
          final fontColor =
              isDarkMode ? Font_Color_dark_mode : Font_Color_light_mode;
          return AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: fontColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Create Account',
              style: TextStyle(
                color: fontColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: getAppFontFamily(),
              ),
            ),
            centerTitle: true,
          );
        });
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}