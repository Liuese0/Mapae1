import 'package:flutter/material.dart';

/// Responsive design utilities for adaptive layouts across screen sizes.
class Responsive {
  Responsive._();

  // Breakpoints
  static const double mobileSmall = 320;
  static const double mobile = 375;
  static const double mobileLarge = 428;
  static const double tablet = 768;
  static const double desktop = 1024;

  static bool isMobileSmall(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  /// Returns a value based on screen size.
  static T value<T>(
      BuildContext context, {
        required T mobile,
        T? tablet,
        T? desktop,
      }) {
    final w = MediaQuery.of(context).size.width;
    if (w >= Responsive.desktop && desktop != null) return desktop;
    if (w >= Responsive.tablet && tablet != null) return tablet;
    return mobile;
  }

  /// Horizontal padding that scales with screen width.
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= desktop) return w * 0.15;
    if (w >= tablet) return 40;
    if (w >= mobileLarge) return 24;
    return 20;
  }

  /// Card height that scales with screen height.
  static double cardHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    if (h < 667) return 220; // small phones (SE)
    if (h < 812) return 260; // regular phones
    return 280; // tall phones & tablets
  }

  /// Font scale factor based on width.
  static double fontScale(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < mobileSmall) return 0.85;
    if (w < mobile) return 0.92;
    if (w >= tablet) return 1.1;
    return 1.0;
  }
}