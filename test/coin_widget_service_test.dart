import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cara_o_cruz/features/widget/coin_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('saves a cara/cruz result and refreshes the Android widget', () async {
    await coinWidgetFlipCallback(Uri.parse('caraocruz://flip'));

    final saveCall = calls.firstWhere((c) => c.method == 'saveWidgetData');
    expect(saveCall.arguments['id'], 'widget_flip_result');
    expect(saveCall.arguments['data'], anyOf('cara', 'cruz'));

    final updateCall = calls.firstWhere((c) => c.method == 'updateWidget');
    expect(updateCall.arguments['android'], 'CoinWidgetProvider');
  });

  test('waits out the remaining time toward a 1s reveal from the tap',
      () async {
    final tappedAtMillis = DateTime.now().millisecondsSinceEpoch - 700;
    final stopwatch = Stopwatch()..start();

    await coinWidgetFlipCallback(
      Uri.parse('caraocruz://flip?tappedAtMillis=$tappedAtMillis'),
    );

    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(250));
  });

  test('does not add extra waiting once the tap is already ~1s old', () async {
    final tappedAtMillis = DateTime.now().millisecondsSinceEpoch - 2000;
    final stopwatch = Stopwatch()..start();

    await coinWidgetFlipCallback(
      Uri.parse('caraocruz://flip?tappedAtMillis=$tappedAtMillis'),
    );

    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(200));
  });
}
