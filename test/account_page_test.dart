import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/AccountPage.dart';
import 'package:chocolate_music/theme/app_colors.dart';

AccountData _defaultAccountData() {
  return AccountData(
    login: [0, 0],
    data: [
      [
        KugouData(
          token: 'kugou-token-0',
          userid: 'summer-radio',
          t_expire_time: 0,
          cover: '',
          nickname: '夏日电台',
          dfid: '',
          url: 'https://kugou.example',
        ),
        KugouData(
          token: 'kugou-token-1',
          userid: 'night-voyage',
          t_expire_time: 0,
          cover: '',
          nickname: '夜航船',
          dfid: '',
          url: 'https://kugou.example',
        ),
      ],
      [
        NetEaseCloudData(
          cookies: 'netease-cookie-0',
          loginType: 0,
          token: 'netease-token-0',
          userid: 'evening-sea',
          cover: '',
          nickname: '晚风与海',
          url: 'https://netease.example',
        ),
        NetEaseCloudData(
          cookies: 'netease-cookie-1',
          loginType: 0,
          token: 'netease-token-1',
          userid: 'listen-together',
          cover: '',
          nickname: '一起听歌',
          url: 'https://netease.example',
        ),
        NetEaseCloudData(
          cookies: 'netease-cookie-2',
          loginType: 0,
          token: 'netease-token-2',
          userid: 'private',
          cover: '',
          nickname: '私人账号',
          url: 'https://netease.example',
        ),
      ],
      [
        NavidromeData(
          u: 'local-library',
          t: 'token',
          p: 'password',
          s: 'salt',
          name: 'Local Library',
          url: 'https://navidrome.example',
        ),
      ],
    ],
  );
}

void _seedManagement(AccountData accountData) {
  final Management management = Management();
  management.accountData = accountData;
  management.updateAccount();
}

void main() {
  setUp(() {
    _seedManagement(_defaultAccountData());
  });

  testWidgets(
    'renders Management account data and switches the current account',
    (WidgetTester tester) async {
      final Management management = Management();
      _seedManagement(
        AccountData(
          login: [1, 0],
          data: [
            [
              KugouData(
                token: 'kugou-token',
                userid: 'data-kugou',
                t_expire_time: 0,
                cover: '',
                nickname: '酷狗数据账号',
                dfid: '',
                url: 'https://kugou.example',
              ),
            ],
            [
              NetEaseCloudData(
                cookies: 'netease-cookie',
                loginType: 0,
                token: 'netease-token',
                userid: 'data-netease',
                cover: '',
                nickname: '网易数据账号',
                url: 'https://netease.example',
              ),
            ],
            [
              NavidromeData(
                u: 'nas-user',
                t: 'token',
                p: 'password',
                s: 'salt',
                name: '家庭音乐库',
                url: 'https://navidrome.example',
              ),
            ],
          ],
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountPage())),
      );

      expect(find.text('网易数据账号'), findsNWidgets(2));
      expect(find.text('酷狗数据账号'), findsNothing);

      await tester.tap(find.text('Navidrome'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('account-switch-item-navidrome-nas-user')),
      );
      await tester.pumpAndSettle();

      expect(management.account.nickname, 'nas-user');
      expect(management.account.type, 'Navidrome');
      expect(find.text('nas-user'), findsNWidgets(2));
      expect(
        find.byKey(const Key('stage-avatar-service-navidrome')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'filters accounts by provider without changing current identity',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

      expect(find.text('当前正在聆听'), findsOneWidget);
      expect(find.text('夏日电台'), findsNWidgets(2));
      expect(find.text('夜航船'), findsOneWidget);
      expect(find.text('晚风与海'), findsNothing);

      await tester.tap(find.text('网易云音乐'));
      await tester.pumpAndSettle();

      expect(find.text('晚风与海'), findsOneWidget);
      expect(find.text('一起听歌'), findsOneWidget);
      expect(find.text('夏日电台'), findsOneWidget);
    },
  );

  testWidgets('selecting an account updates the current listening identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    await tester.tap(find.text('网易云音乐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晚风与海'));
    await tester.pumpAndSettle();

    expect(find.text('晚风与海'), findsNWidgets(2));
    expect(find.text('网易云音乐 · 当前使用'), findsOneWidget);
    expect(find.text('当前账号'), findsOneWidget);
  });

  testWidgets('clears the previous account hover after same-provider switch', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('account-hover-region-kugou-night-voyage')),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('account-switch-item-kugou-night-voyage')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('account-switch-item-kugou-summer-radio')),
    );
    await tester.pump();

    final Finder previousAccountSurface = find.descendant(
      of: find.byKey(const Key('account-switch-item-kugou-night-voyage')),
      matching: find.byType(AnimatedContainer),
    );
    final Finder selectedAccountSurface = find.descendant(
      of: find.byKey(const Key('account-switch-item-kugou-summer-radio')),
      matching: find.byType(AnimatedContainer),
    );

    expect(
      (tester.widget<AnimatedContainer>(previousAccountSurface).decoration!
              as BoxDecoration)
          .color,
      AppColors.transparent,
    );
    expect(
      (tester.widget<AnimatedContainer>(selectedAccountSurface).decoration!
              as BoxDecoration)
          .color,
      AppColors.accountSelection,
    );
  });

  testWidgets('deletes an account from its fixed icon and shows success feedback', (
    WidgetTester tester,
  ) async {
    final Management management = Management();
    final int accountCount = management.accountData.data[0].length;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    await tester.tap(
      find.byKey(const Key('delete-account-button-kugou-night-voyage')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-delete-confirmation-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-account-deletion-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const Key('account-delete-confirmation-dialog')),
      findsNothing,
    );
    expect(find.text('删除成功'), findsOneWidget);
    final SnackBar snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.width, 156);
    expect(snackBar.backgroundColor, Colors.white);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());
    expect(management.accountData.data[0], hasLength(accountCount - 1));
    expect(management.accountData.data[1], hasLength(3));
    expect(management.accountData.data[2], hasLength(1));
  });

  testWidgets('opens LoginPage in the current app when adding an account', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    await tester.tap(find.byKey(const Key('add-account-button')));
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('renders the account page on a white backdrop', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final DecoratedBox backdrop = tester.widget<DecoratedBox>(
      find.byKey(const Key('account-page-backdrop')),
    );

    expect((backdrop.decoration as BoxDecoration).color, Colors.white);
  });

  testWidgets('uses rounded glass surfaces for account controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    expect(find.byKey(const Key('provider-rail-tray')), findsOneWidget);
    expect(find.byKey(const Key('account-directory')), findsOneWidget);
  });

  testWidgets(
    'keeps a provider highlighted while the pointer remains over it',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

      final Finder providerLabel = find.text('网易云音乐').first;
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: tester.getCenter(providerLabel));
      await mouse.moveTo(tester.getCenter(providerLabel));
      await tester.pump();
      final Finder providerIcon = find.descendant(
        of: find.ancestor(
          of: providerLabel,
          matching: find.byType(AnimatedContainer),
        ),
        matching: find.byType(SvgPicture),
      );
      await mouse.moveTo(tester.getCenter(providerIcon));
      await tester.pump(const Duration(milliseconds: 250));

      final AnimatedContainer providerSurface = tester
          .widget<AnimatedContainer>(
            find.ancestor(
              of: providerLabel,
              matching: find.byType(AnimatedContainer),
            ),
          );
      expect(
        (providerSurface.decoration! as BoxDecoration).color,
        AppColors.floating,
      );
    },
  );

  testWidgets('uses a single mouse region for each account page surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    expect(
      find.ancestor(
        of: find.text('网易云音乐').first,
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(of: find.text('夜航船'), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.byKey(const Key('provider-hover-region-netease-cloud')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-hover-region-kugou-night-voyage')),
      findsOneWidget,
    );
  });

  testWidgets('keeps switch items to one stable hover surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder providerItem = find.byKey(
      const Key('provider-switch-item-netease-cloud'),
    );
    final Finder accountItem = find.byKey(
      const Key('account-switch-item-kugou-night-voyage'),
    );

    expect(providerItem, findsOneWidget);
    expect(accountItem, findsOneWidget);
    expect(
      find.descendant(of: providerItem, matching: find.byType(MouseRegion)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: accountItem, matching: find.byType(MouseRegion)),
      findsOneWidget,
    );
  });

  testWidgets('uses a visibly distinct hover color on the white page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder hoverRegion = find.byKey(
      const Key('provider-hover-region-netease-cloud'),
    );
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(hoverRegion));
    await tester.pump(const Duration(milliseconds: 250));

    final Finder providerSurface = find.descendant(
      of: find.byKey(const Key('provider-switch-item-netease-cloud')),
      matching: find.byType(AnimatedContainer),
    );
    final AnimatedContainer surface = tester.widget<AnimatedContainer>(
      providerSurface,
    );
    final Color hoverColor =
        (surface.decoration! as BoxDecoration).color ?? Colors.transparent;

    expect(hoverColor, isNot(AppColors.background));
    expect(
      (hoverColor.computeLuminance() - AppColors.background.computeLuminance())
          .abs(),
      greaterThan(0.01),
    );
  });

  testWidgets('uses a gray hover color without interpolating switch surfaces', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder hoverRegion = find.byKey(
      const Key('provider-hover-region-netease-cloud'),
    );
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(hoverRegion));
    await tester.pump();

    final Finder providerSurface = find.descendant(
      of: find.byKey(const Key('provider-switch-item-netease-cloud')),
      matching: find.byType(AnimatedContainer),
    );
    final Finder accountSurface = find.descendant(
      of: find.byKey(const Key('account-switch-item-kugou-night-voyage')),
      matching: find.byType(AnimatedContainer),
    );

    expect(
      (tester.widget<AnimatedContainer>(providerSurface).decoration!
              as BoxDecoration)
          .color,
      AppColors.floating,
    );
    expect(
      tester.widget<AnimatedContainer>(providerSurface).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedContainer>(accountSurface).duration,
      Duration.zero,
    );
  });

  testWidgets('keeps account switch rows taller than provider chips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder providerSurface = find.descendant(
      of: find.byKey(const Key('provider-switch-item-netease-cloud')),
      matching: find.byType(AnimatedContainer),
    );
    final Finder accountSurface = find.descendant(
      of: find.byKey(const Key('account-switch-item-kugou-night-voyage')),
      matching: find.byType(AnimatedContainer),
    );

    expect(tester.getSize(providerSurface).height, 44);
    expect(tester.getSize(accountSurface).height, 76);
  });

  testWidgets('keeps the final provider hovered during rapid pointer moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('provider-hover-region-kugou'))),
    );
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('provider-hover-region-netease-cloud')),
      ),
    );
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('provider-hover-region-navidrome')),
      ),
    );
    await tester.pump();

    final AnimatedContainer finalSurface = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('provider-switch-item-navidrome')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (finalSurface.decoration! as BoxDecoration).color,
      AppColors.floating,
    );
  });

  testWidgets('keeps the final account hovered during rapid pointer moves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('account-hover-region-kugou-summer-radio')),
      ),
    );
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('account-hover-region-kugou-night-voyage')),
      ),
    );
    await tester.pump();

    final AnimatedContainer finalSurface = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('account-switch-item-kugou-night-voyage')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (finalSurface.decoration! as BoxDecoration).color,
      AppColors.floating,
    );
  });

  testWidgets('keeps the selected provider gray during rapid pointer moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('provider-hover-region-navidrome')),
      ),
    );
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('provider-hover-region-kugou'))),
    );
    await tester.pump();

    final AnimatedContainer selectedSurface = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('provider-switch-item-kugou')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (selectedSurface.decoration! as BoxDecoration).color,
      AppColors.floating,
    );
  });

  testWidgets('keeps the current account selected while hovered', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('account-hover-region-kugou-night-voyage')),
      ),
    );
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('account-hover-region-kugou-summer-radio')),
      ),
    );
    await tester.pump();

    final AnimatedContainer selectedSurface = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('account-switch-item-kugou-summer-radio')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (selectedSurface.decoration! as BoxDecoration).color,
      AppColors.accountSelection,
    );
  });

  testWidgets(
    'keeps an account highlighted while the pointer stays in its row',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

      final Finder accountLabel = find.text('夜航船');
      final Finder accountSurfaceFinder = find.ancestor(
        of: accountLabel,
        matching: find.byType(AnimatedContainer),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(accountLabel));
      await tester.pump(const Duration(milliseconds: 250));

      AnimatedContainer accountSurface = tester.widget<AnimatedContainer>(
        accountSurfaceFinder,
      );
      expect(
        (accountSurface.decoration! as BoxDecoration).color,
        AppColors.floating,
      );

      final Finder accountAvatar = find.descendant(
        of: accountSurfaceFinder,
        matching: find.text('夜'),
      );
      await mouse.moveTo(tester.getCenter(accountAvatar));
      await tester.pump(const Duration(milliseconds: 250));

      accountSurface = tester.widget<AnimatedContainer>(accountSurfaceFinder);
      expect(
        (accountSurface.decoration! as BoxDecoration).color,
        AppColors.floating,
      );
    },
  );

  testWidgets('does not show account counts for individual providers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('2 个账号'), findsNothing);
  });

  testWidgets('uses one surface for an account row and its tap target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder accountLabel = find.text('夜航船');
    final AnimatedContainer accountSurface = tester.widget<AnimatedContainer>(
      find.ancestor(of: accountLabel, matching: find.byType(AnimatedContainer)),
    );

    expect(accountSurface.margin, isNull);
  });

  testWidgets('does not highlight an account from its outer row spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder accountLabel = find.text('夜航船');
    final Finder accountSurfaceFinder = find.ancestor(
      of: accountLabel,
      matching: find.byType(AnimatedContainer),
    );
    final Rect accountSurfaceRect = tester.getRect(accountSurfaceFinder);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(
      location: Offset(
        accountSurfaceRect.left - 4,
        accountSurfaceRect.center.dy,
      ),
    );
    await mouse.moveTo(
      Offset(accountSurfaceRect.left - 4, accountSurfaceRect.center.dy),
    );
    await tester.pumpAndSettle();

    final AnimatedContainer accountSurface = tester.widget<AnimatedContainer>(
      accountSurfaceFinder,
    );
    expect(
      (accountSurface.decoration! as BoxDecoration).color,
      AppColors.transparent,
    );
  });

  testWidgets('renders the listening record in white', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final DecoratedBox disc = tester.widget<DecoratedBox>(
      find.byKey(const Key('record-disc')),
    );

    expect((disc.decoration as BoxDecoration).color, Colors.white);
  });

  testWidgets('places listening details close to the profile avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final Finder stageAvatar = find.ancestor(
      of: find.text('夏'),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.constraints?.minWidth == 92 &&
            widget.constraints?.minHeight == 92,
      ),
    );
    final Rect avatarRect = tester.getRect(stageAvatar);
    final Rect detailsRect = tester.getRect(find.text('当前正在聆听'));

    expect(detailsRect.left - avatarRect.right, 12);
  });

  testWidgets('uses a rounded listening-stage surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    final AnimatedContainer stage = tester.widget<AnimatedContainer>(
      find.byKey(const Key('listening-stage')),
    );

    expect(
      (stage.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(32),
    );
  });

  testWidgets('keeps the listening stage to a single visual surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsNothing,
    );
  });

  testWidgets('respects the system reduced-motion preference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: AccountPage())),
      ),
    );

    final AnimatedContainer stage = tester.widget<AnimatedContainer>(
      find.byKey(const Key('listening-stage')),
    );

    expect(stage.duration, Duration.zero);
  });

  testWidgets('changes the listening stage color with the selected provider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage())));

    AnimatedContainer stage = tester.widget<AnimatedContainer>(
      find.byKey(const Key('listening-stage')),
    );
    expect(
      ((stage.decoration! as BoxDecoration).gradient! as LinearGradient)
          .colors
          .first,
      AppColors.accountStageKuGou,
    );

    await tester.tap(find.text('网易云音乐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晚风与海'));
    await tester.pumpAndSettle();

    stage = tester.widget<AnimatedContainer>(
      find.byKey(const Key('listening-stage')),
    );
    expect(
      ((stage.decoration! as BoxDecoration).gradient! as LinearGradient)
          .colors
          .first,
      AppColors.accountStageNetEaseCloud,
    );
  });

  testWidgets('expands account content across the available desktop width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountPage())),
    );

    expect(
      tester.getSize(find.byKey(const Key('listening-stage'))).width,
      1144,
    );

    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('listening-stage'))).width,
      1275,
    );
  });

  testWidgets(
    'keeps the listening stage height stable throughout an account switch',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountPage())),
      );

      final Finder stage = find.byKey(const Key('listening-stage'));
      final double initialHeight = tester.getSize(stage).height;
      expect(initialHeight, 200);

      await tester.tap(find.text('Navidrome'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('account-switch-item-navidrome-local-library')),
      );
      await tester.pump();
      expect(tester.getSize(stage).height, initialHeight);

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(stage).height, initialHeight);

      await tester.pumpAndSettle();
      expect(tester.getSize(stage).height, initialHeight);
    },
  );

  testWidgets('keeps the listening stage within bounds at larger text scales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
        child: const MaterialApp(home: Scaffold(body: AccountPage())),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('listening-stage'))).height,
      greaterThanOrEqualTo(186),
    );
  });

}
