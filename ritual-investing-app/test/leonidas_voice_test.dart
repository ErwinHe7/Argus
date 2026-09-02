import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ritual_investing/leonidas_voice');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'passes reviewed narration and voice controls to the platform',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'speak';
          });

      const voice = PlatformLeonidasVoice();
      expect(await voice.speak('Direction, not urgency.'), isTrue);
      await voice.stop();

      expect(calls.map((call) => call.method), ['speak', 'stop']);
      expect(calls.first.arguments, <String, Object>{
        'text': 'Direction, not urgency.',
        'rate': 0.91,
        'pitch': 0.78,
      });
    },
  );

  test('fails closed to captions when no native voice is registered', () async {
    const voice = PlatformLeonidasVoice();

    expect(await voice.speak('Caption this line.'), isFalse);
    await expectLater(voice.stop(), completes);
  });
}
