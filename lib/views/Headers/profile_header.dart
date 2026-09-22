import 'package:flutter/material.dart';
import '../../general_files/color_hex.dart';
import '../../data/notifiers.dart';

class ProfileHeader extends StatelessWidget implements PreferredSizeWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, child) {
        final titleColor =
            isDarkMode ? Font_Color_dark_mode : Font_Color_light_mode;
        final appBarBackgroundColor = isDarkMode
            ? background_Color_dark_mode
            : background_Color_light_mode;

        return AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Profile',
            style: TextStyle(color: titleColor, fontFamily: getAppFontFamily(), fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: appBarBackgroundColor,
          elevation: 0,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
