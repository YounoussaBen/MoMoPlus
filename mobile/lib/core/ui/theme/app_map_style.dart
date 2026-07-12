import 'package:flutter/material.dart';

abstract final class AppMapStyle {
  static String forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const light = '''
[
  {"elementType":"geometry","stylers":[{"color":"#F2F8EC"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5B625B"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#F2F8EC"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#E9ECE6"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#DCEBE4"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#E2E7DF"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E9ECE6"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#DCE9E1"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#697069"}]}
]
''';

  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#121512"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#A8AFA8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#121512"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1A1E1A"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#19372B"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#232823"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#31402E"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1A1E1A"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#173047"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#91CAFF"}]}
]
''';
}
