import 'dart:convert';

import 'package:chocolate_music/services/independent_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('existing account window is shown and requested to activate', () async {
    final List<MethodCall> windowCalls = <MethodCall>[];
    final List<MethodCall> channelCalls = <MethodCall>[];
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    const MethodChannel windowChannel = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel crossWindowChannel = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );

    messenger.setMockMethodCallHandler(windowChannel, (MethodCall call) async {
      windowCalls.add(call);
      if (call.method == 'getAllWindows') {
        return <Map<String, String>>[
          <String, String>{
            'windowId': '7',
            'windowArgument': jsonEncode(<String, String>{
              'windowType': 'account_login',
            }),
          },
        ];
      }
      return null;
    });
    messenger.setMockMethodCallHandler(crossWindowChannel, (
      MethodCall call,
    ) async {
      channelCalls.add(call);
      return null;
    });

    addTearDown(() {
      messenger.setMockMethodCallHandler(windowChannel, null);
      messenger.setMockMethodCallHandler(crossWindowChannel, null);
    });

    await IndependentWindowService.openAccountWindow();

    expect(
      windowCalls.map((MethodCall call) => call.method),
      containsAllInOrder(<String>['getAllWindows', 'window_show']),
    );
    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.method, 'invokeMethod');
    expect(
      channelCalls.single.arguments,
      containsPair('method', 'activateWindow'),
    );
  });
}
