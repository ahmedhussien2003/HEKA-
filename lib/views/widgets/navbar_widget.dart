import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';
import '../../data/translations.dart';

class NavbarWidget extends StatelessWidget {
  const NavbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedLanguageNotifier,
      builder: (context, language, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDarkMode, _) {
        final backgroundColor = isDarkMode
            ? const Color(0xFF0D0C09)
            : const Color(0xFFF7F0E8);
        final activeColor = Temple_Gold;
        final inactiveColor = isDarkMode ? Temple_Light_Gray : Temple_Dark_Gray;

        return ValueListenableBuilder<int>(
          valueListenable: selectedPageNotifier,
          builder: (context, selectedIndex, _) {
            return SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 80,
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          context,
                          index: 0,
                          icon: Icons.home,
                          label: AppTranslations.translate('nav_home'),
                          currentIndex: selectedIndex,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                        _buildNavItem(
                          context,
                          index: 1,
                          icon: Icons.history,
                          label: AppTranslations.translate('nav_history'),
                          currentIndex: selectedIndex,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                        const SizedBox(width: 60), // Space for center button
                        _buildNavItem(
                          context,
                          index: 3,
                          icon: Icons.bookmark,
                          label: AppTranslations.translate('nav_saved'),
                          currentIndex: selectedIndex,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                        _buildNavItem(
                          context,
                          index: 4,
                          icon: Icons.person,
                          label: AppTranslations.translate('nav_profile'),
                          currentIndex: selectedIndex,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: _buildCenterButton(context, selectedIndex),
                  ),
                ],
              ),
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required int currentIndex,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final bool isSelected = currentIndex == index;
    final Color color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () {
        selectedPageNotifier.value = index;
        selectedHeaderNotifier.value = index;
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 13, // Increased size
                fontWeight: isSelected
                    ? FontWeight.w900
                    : FontWeight.w700, // Much bolder
                fontFamily: getAppFontFamily(),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, int currentIndex) {
    return GestureDetector(
      onTap: () {
        selectedPageNotifier.value = 2;
        selectedHeaderNotifier.value = 2;
      },
      child: Container(
        width: 70, // Slightly larger
        height: 70,
        decoration: BoxDecoration(
          color: Temple_Gold,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF0D0C09).withOpacity(0.5),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Temple_Gold.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.camera, color: Colors.black, size: 38),
        ),
      ),
    );
  }
}
