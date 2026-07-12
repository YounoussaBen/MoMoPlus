import 'package:flutter/widgets.dart';

/// Shared shape tokens for the MoMo Plus rounded surface language.
abstract final class AppRadii {
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 28;
  static const double radiusPill = 999;

  static const double small = radiusSmall;
  static const double medium = radiusMedium;
  static const double large = radiusLarge;
  static const double xLarge = radiusXLarge;
  static const double pill = radiusPill;

  static const BorderRadius smallBorderRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumBorderRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeBorderRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius xLargeBorderRadius = BorderRadius.all(
    Radius.circular(xLarge),
  );
  static const BorderRadius pillBorderRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
