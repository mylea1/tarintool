import 'package:flutter/material.dart';

/// An identifiable premium surface in both pearl and dark themes.
class PremiumFeatureSurface extends StatelessWidget {
  const PremiumFeatureSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff422b1d), Color(0xff221b17)]
              : const [Color(0xffffedc6), Color(0xfff2d5a4)],
        ),
        border: Border.all(
          color: dark ? const Color(0xffa77845) : const Color(0xffc99b53),
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xffa97725)).withValues(
              alpha: .10,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              backgroundColor: dark
                  ? const Color(0xffe8bb77)
                  : const Color(0xff8b531f),
              foregroundColor: dark ? const Color(0xff302012) : Colors.white,
              side: BorderSide.none,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
