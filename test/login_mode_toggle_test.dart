import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/pages/computer/LoginPage.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 切换按钮外层那圈 AnimatedContainer 的装饰。
BoxDecoration _buttonDecoration(WidgetTester tester, IconData icon) {
  final AnimatedContainer container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

Color _borderColor(BoxDecoration decoration) =>
    (decoration.border! as Border).top.color;

Widget _host() => MaterialApp(
  home: Scaffold(
    // LoginPage 里是 Center + Column，给个有界的高度才铺得开。
    body: SizedBox(width: 500, height: 700, child: LoginPage()),
  ),
);

void main() {
  testWidgets('手机号 / 二维码切换按钮：选中浅蓝底 + 蓝边，未选中保持原样', (WidgetTester tester) async {
    // 首次访问 Management 会触发 init()，它必然抛异常，必须在用例内部触发。
    Management();

    await tester.pumpWidget(_host());
    await tester.pump();

    // 默认停在手机号登录。
    final BoxDecoration phone = _buttonDecoration(tester, BootstrapIcons.phone);
    expect(phone.color, AppColors.selected);
    expect(_borderColor(phone), AppColors.selectedText);

    final BoxDecoration qr = _buttonDecoration(
      tester,
      BootstrapIcons.qr_code_scan,
    );
    expect(qr.color, AppColors.transparent);
    expect(_borderColor(qr), AppColors.border, reason: '未选中沿用原来的浅灰边');
  });

  testWidgets('点二维码按钮，高亮跟着切过去，并真的换到二维码页', (WidgetTester tester) async {
    Management();

    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byIcon(BootstrapIcons.qr_code_scan));
    await tester.pumpAndSettle();

    final BoxDecoration qr = _buttonDecoration(
      tester,
      BootstrapIcons.qr_code_scan,
    );
    expect(qr.color, AppColors.selected);
    expect(_borderColor(qr), AppColors.selectedText);

    final BoxDecoration phone = _buttonDecoration(tester, BootstrapIcons.phone);
    expect(phone.color, AppColors.transparent, reason: '高亮不该同时留在两个按钮上');
    expect(_borderColor(phone), AppColors.border);

    // 高亮只是外观，切换本身也要生效。
    expect(find.text('刷新二维码'), findsOneWidget);
  });

  testWidgets('点回手机号按钮，高亮切回去', (WidgetTester tester) async {
    Management();

    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byIcon(BootstrapIcons.qr_code_scan));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(BootstrapIcons.phone));
    await tester.pumpAndSettle();

    final BoxDecoration phone = _buttonDecoration(tester, BootstrapIcons.phone);
    expect(phone.color, AppColors.selected);
    expect(_borderColor(phone), AppColors.selectedText);
    expect(find.text('刷新二维码'), findsNothing);
  });
}
