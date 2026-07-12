import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/widgets/app_logo.dart';

void main() {
  testWidgets('uses the logo asset for the active brightness', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppLogo()),
    );

    var image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/logo.png');

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const AppLogo()),
    );
    await tester.pumpAndSettle();

    image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/logo-light.png');
  });
}
