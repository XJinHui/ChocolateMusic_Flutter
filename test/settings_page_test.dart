import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/pages/computer/SettingsPage.dart';

/// file_selector 在非移动端走的就是这个 method channel。
const MethodChannel _pickerChannel = MethodChannel(
  'plugins.flutter.io/file_selector',
);

/// 顶替系统目录选择弹窗。真实弹窗在测试里既不响应也不抛错，会一直挂着。
Future<void> _mockPicker(
  WidgetTester tester,
  Future<Object?>? Function(MethodCall call) handler,
) async {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pickerChannel, handler);
  addTearDown(() => messenger.setMockMethodCallHandler(_pickerChannel, null));
}

/// 三个音质档位的文案在两个模块里各出现一次，所以断言一律走 key，
/// 不用 find.text 数文案，否则分不清命中的是哪个模块。
Finder _tagText(String key, String text) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.text(text),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SettingsPage())),
  );
}

void main() {
  testWidgets('三个模块都在，两个音质模块默认只露当前档位', (WidgetTester tester) async {
    final Management management = Management();
    management.setting.qualityTier = 1;
    management.setting.downloadQualityTier = 2;
    management.setting.downloadPath = '';

    await _pump(tester);

    expect(find.text('音质等级'), findsOneWidget);
    expect(find.text('下载音质等级'), findsOneWidget);
    expect(find.text('下载地址'), findsOneWidget);

    // 右上角标签显示的是各模块自己的当前档位，两处互不影响
    expect(_tagText('play-quality-current', '高品音质'), findsOneWidget);
    expect(_tagText('download-quality-current', '无损音质'), findsOneWidget);

    // 默认收起：备选项一个都不在树里
    for (int i = 0; i < 3; i++) {
      expect(find.byKey(Key('play-quality-option-$i')), findsNothing);
      expect(find.byKey(Key('download-quality-option-$i')), findsNothing);
    }

    // 未设置过下载地址时，展示实际生效的默认目录并打上「默认」标记
    expect(
      find.text(management.musicManagement.defaultDownloadDir),
      findsOneWidget,
    );
    expect(find.text('默认'), findsOneWidget);
  });

  testWidgets('点标题栏展开备选项，选中后收起且只改对应模块的设置项', (WidgetTester tester) async {
    final Management management = Management();
    management.setting.qualityTier = 1;
    management.setting.downloadQualityTier = 2;

    await _pump(tester);

    await tester.tap(find.byKey(const Key('play-quality-header')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('play-quality-option-0')), findsOneWidget);
    // 只展开被点的那一个，另一个保持收起
    expect(find.byKey(const Key('download-quality-option-0')), findsNothing);

    await tester.tap(find.byKey(const Key('play-quality-option-0')));
    await tester.pumpAndSettle();

    expect(management.setting.qualityTier, 0);
    expect(management.setting.downloadQualityTier, 2);
    expect(_tagText('play-quality-current', '标准音质'), findsOneWidget);
    // 选完自动收起
    expect(find.byKey(const Key('play-quality-option-0')), findsNothing);

    await tester.tap(find.byKey(const Key('download-quality-header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download-quality-option-1')));
    await tester.pumpAndSettle();

    expect(management.setting.qualityTier, 0);
    expect(management.setting.downloadQualityTier, 1);
    expect(_tagText('download-quality-current', '高品音质'), findsOneWidget);
  });

  testWidgets('点「更改」调起系统目录选择器，取消则什么都不改', (WidgetTester tester) async {
    final Management management = Management();
    management.setting.downloadPath = '';

    // 测试环境没有真的系统弹窗，用假 handler 顶替，
    // 返回 null 就等于用户在系统弹窗里点了取消。
    await _mockPicker(tester, (MethodCall call) async => null);

    await _pump(tester);

    expect(find.byKey(const Key('download-path-display')), findsOneWidget);
    expect(find.byKey(const Key('download-path-field')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-download-path-button')));
    await tester.pumpAndSettle();

    expect(management.setting.downloadPath, '');
    expect(find.byKey(const Key('download-path-display')), findsOneWidget);
    expect(find.byKey(const Key('download-path-field')), findsNothing);
  });

  testWidgets('系统目录选择器打不开时退回手动输入', (WidgetTester tester) async {
    final Management management = Management();
    management.setting.downloadPath = '';

    await _mockPicker(
      tester,
      (MethodCall call) async => throw PlatformException(code: 'unavailable'),
    );

    await _pump(tester);

    // 已经是默认目录，没有可恢复的东西，按钮保持禁用。
    // OutlinedButton.icon 的运行时类型是私有子类，find.byType 匹配不到，
    // 这里按类型断言用 predicate 找。
    final Finder restoreButton = find.descendant(
      of: find.byKey(const Key('restore-download-path-button')),
      matching: find.byWidgetPredicate((Widget w) => w is OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(restoreButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('edit-download-path-button')));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(
      find.byKey(const Key('download-path-field')),
    );
    expect(field.controller?.text, management.musicManagement.defaultDownloadDir);
    expect(find.byKey(const Key('download-path-display')), findsNothing);

    await tester.tap(find.byKey(const Key('cancel-download-path-button')));
    await tester.pump();

    expect(find.byKey(const Key('download-path-field')), findsNothing);
    expect(find.byKey(const Key('download-path-display')), findsOneWidget);
  });
}
