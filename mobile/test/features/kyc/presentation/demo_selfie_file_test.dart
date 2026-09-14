import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/features/kyc/data/demo_selfie_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates a non-empty PNG for simulator demos', () async {
    final file = await DemoSelfieFile.create();
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    expect(file.path, endsWith('.png'));
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
  });
}
