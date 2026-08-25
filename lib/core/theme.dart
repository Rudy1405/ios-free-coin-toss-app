import 'package:flutter/cupertino.dart';

abstract class AppTheme {
  static const darkBackground = Color(0xFF1C1C1E);
  static const lightBackground = Color(0xFFF2F2F7);

  static CupertinoThemeData get dark => const CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
      );

  static CupertinoThemeData get light => const CupertinoThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
      );
}
