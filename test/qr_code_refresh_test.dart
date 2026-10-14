import 'dart:async';

import 'package:chocolate_music/Cloud/KuGou.dart';
import 'package:chocolate_music/Cloud/NetEaseCloud.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/LoginPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录每次取码时本轮登录的状态，并让请求失败。
///
/// 失败是刻意的：真实取码成功后云服务会紧接着起一个每 2 秒的轮询循环，
/// 测试里留着它跑不完。抛异常既跳过轮询，又能让调用方看出取码确实发生过。
class _RecordingQrKuGou extends KuGou {
  _RecordingQrKuGou({required super.accountData, required super.management});

  int fetchCount = 0;
  int? loginTypeAtFetch;
  int? qrCodeTypeAtFetch;

  @override
  dynamic getQrCode(String mainUrl) async {
    fetchCount++;
    loginTypeAtFetch = management.loginType;
    qrCodeTypeAtFetch = qrCodeType;
    throw StateError('测试环境不发起二维码请求');
  }
}

class _RecordingQrNetease extends Neteasecloud {
  _RecordingQrNetease({required super.accountData, required super.management});

  int fetchCount = 0;

  @override
  dynamic getQrCode(String mainUrl) async {
    fetchCount++;
    throw StateError('测试环境不发起二维码请求');
  }
}

/// 取码一直挂着，直到 [release] 被完成——「刷新中」这个中间态才好观察。
class _GatedQrKuGou extends KuGou {
  _GatedQrKuGou({required super.accountData, required super.management});

  final Completer<void> release = Completer<void>();
  int fetchCount = 0;

  @override
  dynamic getQrCode(String mainUrl) async {
    fetchCount++;
    await release.future;
    throw StateError('测试环境不发起二维码请求');
  }
}

/// 取单例并换上不打网络的云服务桩。
///
/// 必须在用例内部取：首次访问 Management 会触发 [Management.init]，它在
/// 测试环境下必然抛异常，落在用例之外就会被记到整个测试文件头上。
Management _seed({KuGou Function(Management)? kuGou}) {
  final Management management = Management();
  management.accountData = AccountData(login: [0, 0], data: [[], [], []]);
  management.loginType = -1;
  management.KuGouCloud =
      kuGou?.call(management) ??
      _RecordingQrKuGou(
        accountData: management.accountData,
        management: management,
      );
  management.NeteasecloudCloud = _RecordingQrNetease(
    accountData: management.accountData,
    management: management,
  );
  return management;
}

void main() {
  testWidgets('刷新二维码先复位本轮登录再取码，并推进世代号', (WidgetTester tester) async {
    final Management management = _seed();
    // 上一次扫码成功留下的锁存：两个云服务的 qrCodeType 都停在 1。
    management.KuGouCloud.qrCodeType = 1;
    management.NeteasecloudCloud.qrCodeType = 1;

    final int attemptBefore = management.loginAttempt;

    await expectLater(management.refreshQrCode(), throwsA(isA<StateError>()));

    expect(
      management.loginAttempt,
      attemptBefore + 1,
      reason: '世代号不推进，上一轮的轮询循环会跟新一轮一起轮询同一个 key',
    );
    expect(management.loginType, 0, reason: '取码时就必须已经是「本次登录中」');

    final _RecordingQrKuGou kuGou = management.KuGouCloud as _RecordingQrKuGou;
    expect(kuGou.fetchCount, 1, reason: '刷新应当真的去取一张新码');
    expect(kuGou.loginTypeAtFetch, 0);
    expect(
      kuGou.qrCodeTypeAtFetch,
      0,
      reason: '残留的锁存不清掉，loginByQrCode 会把它当成这次的结果',
    );
    expect(management.NeteasecloudCloud.qrCodeType, 0);

    final _RecordingQrNetease netease =
        management.NeteasecloudCloud as _RecordingQrNetease;
    expect(netease.fetchCount, 1, reason: '两家都要重取');
  });

  testWidgets('点击「刷新二维码」会重新取码', (WidgetTester tester) async {
    final Management management = _seed(
      kuGou: (Management m) =>
          _GatedQrKuGou(accountData: m.accountData, management: m),
    );
    management.loginType = 0;
    final _GatedQrKuGou kuGou = management.KuGouCloud as _GatedQrKuGou;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QrCodeLogin(service: 'KuGou')),
      ),
    );
    expect(kuGou.fetchCount, 0, reason: '挂载本身不该取码，那是登录界面打开时的活');

    await tester.tap(find.text('刷新二维码'));
    await tester.pump();

    expect(kuGou.fetchCount, 1, reason: '按钮点了却什么都没发生');
    expect(find.text('刷新中...'), findsOneWidget);

    kuGou.release.complete();
    await tester.pumpAndSettle();

    // 取码失败后按钮要恢复可点，否则用户只点得了一次。
    expect(find.text('刷新二维码'), findsOneWidget);
  });
}
