import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chocolate_music/components/MusicComponents.dart';

void main() {
  testWidgets('11 字文案的轻提示不溢出', (WidgetTester tester) async {
    const String message = '创建歌单《测试曲》成功';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () => showMusicToast(context, message: message),
                child: const Text('show'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 提示确实渲染出来了，避免测试变成空跑
    expect(find.text(message), findsOneWidget);

    // 溢出会通过 FlutterError.reportError 冒出来，被 takeException 捕获
    expect(tester.takeException(), isNull);
  });
}
