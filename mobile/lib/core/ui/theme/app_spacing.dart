import 'package:flutter/widgets.dart';

/// The MoMo Plus four-point spacing scale.
///
/// Feature UI should compose layouts from these values instead of introducing
/// one-off gaps. The default phone gutter is [screenGutter].
abstract final class AppSpacing {
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  static const double screenGutter = space5;
  static const double compactScreenGutter = space4;
  static const double sectionBand = space2;
  static const double sectionPadding = space6;

  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: screenGutter,
  );
  static const EdgeInsets compactScreenHorizontal = EdgeInsets.symmetric(
    horizontal: compactScreenGutter,
  );
  static const EdgeInsets sectionInsets = EdgeInsets.all(sectionPadding);
  static const EdgeInsets controlInsets = EdgeInsets.symmetric(
    horizontal: space4,
    vertical: space3,
  );

  /// Returns the responsive horizontal page gutter for [width].
  static double gutterFor(double width) {
    return width < 360 ? compactScreenGutter : screenGutter;
  }
}
