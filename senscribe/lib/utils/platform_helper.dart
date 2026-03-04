import 'dart:io';
import 'package:flutter/material.dart';

class PlatformHelper {
  PlatformHelper._();

  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;

  static double iosTopPadding(BuildContext context) {
    if (!isIOS) return 0.0;
    return MediaQuery.of(context).padding.top + kToolbarHeight;
  }

  static double topSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double bottomSafeArea(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
}
