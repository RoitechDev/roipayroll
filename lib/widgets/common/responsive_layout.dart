import 'package:flutter/material.dart';

/// Responsive Layout Helper
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Responsive Value Helper
T responsiveValue<T>({
  required BuildContext context,
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  final width = MediaQuery.of(context).size.width;

  if (width >= 1200) {
    return desktop ?? tablet ?? mobile;
  } else if (width >= 600) {
    return tablet ?? mobile;
  } else {
    return mobile;
  }
}
