import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chocolate_music/Cloud/KuGou.dart';
import 'package:chocolate_music/Cloud/Navidrome.dart';
import 'package:chocolate_music/Cloud/NetEaseCloud.dart';
import 'package:chocolate_music/FileManage.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/AccountLoginDialog.dart';

/// 弹窗打开后会预取二维码。测试里不需要真实网络：让请求直接失败，
/// 既避免残留定时器，也避免落入 loginByQrCode 的轮询循环。
class _NoNetworkKuGou extends KuGou {
  _NoNetworkKuGou({required super.accountData, required super.management});

  @override
  dynamic getQrCode(String mainUrl) async {
    throw StateError('测试环境不发起二维码请求');
  }
}

class _NoNetworkNetease extends Neteasecloud {
  _NoNetworkNetease({required super.accountData, required super.management});

  @override
  dynamic getQrCode(String mainUrl) async {
    throw StateError('测试环境不发起二维码请求');
  }
}

/// 取二维码时把「本次登录的状态」记下来，再让请求失败。
///
/// 真实云服务取到二维码后会紧接着起一个以 `loginType == 0` 为继续条件的轮询，
/// 所以这里记录的快照必须已经是复位后的状态。
class _RecordingQrKuGou extends KuGou {
  _RecordingQrKuGou({required super.accountData, required super.management});

  int? loginTypeAtFetch;
  int? qrCodeTypeAtFetch;

  @override
  dynamic getQrCode(String mainUrl) async {
    loginTypeAtFetch = management.loginType;
    qrCodeTypeAtFetch = qrCodeType;
    throw StateError('测试环境不发起二维码请求');
  }
}

class _RecordingQrNetease extends Neteasecloud {
  _RecordingQrNetease({required super.accountData, required super.management});

  int? loginTypeAtFetch;
  int? qrCodeTypeAtFetch;

  @override
  dynamic getQrCode(String mainUrl) async {
    loginTypeAtFetch = management.loginType;
    qrCodeTypeAtFetch = qrCodeType;
    throw StateError('测试环境不发起二维码请求');
  }
}

/// 二维码请求立刻成功返回空串（跳过图片解码），好让
/// `Management.loginByQrCode` 的轮询真的跑起来 —— 读残留状态的就是它。
class _InstantQrKuGou extends KuGou {
  _InstantQrKuGou({required super.accountData, required super.management});

  @override
  dynamic getQrCode(String mainUrl) async => '';
}

class _InstantQrNetease extends Neteasecloud {
  _InstantQrNetease({required super.accountData, required super.management});

  @override
  dynamic getQrCode(String mainUrl) async => '';
}

/// 把 `/login/qr/check` 拦成「已扫码，待确认」，让轮询循环一直转下去。
///
/// 既不碰真实网络，也走不到收尾那段（那段会往账号列表里写数据）。
/// 返回体同时带上两家的字段形状：酷狗读 `data.status`，网易云读 `code`。
Interceptor _holdQrCheck() {
  return InterceptorsWrapper(
    onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'code': 802,
            'data': <String, dynamic>{'status': 1},
          },
        ),
      );
    },
  );
}

/// 不落盘的 FileManage：登录收尾会写 accountData.json，
/// 测试里不该往 flutter_tester 的安装目录里写东西。
class _NoDiskFileManage extends FileManage {
  @override
  Future<void> writeAccountData(AccountData accountData) async {}

  @override
  Future<void> writeRecommendListDate(
    List<RecommendList> recommendListDate,
  ) async {}
}

/// 登录路径只关心「登录成功后登记账号」那一段。取 dfid、拉歌单之类是与账户
/// 列表无关的旁支，跳过它们，测试里就只需要拦登录接口本身。
class _LoginOnlyKuGou extends KuGou {
  _LoginOnlyKuGou({required super.accountData, required super.management});

  @override
  dynamic getDfid() async => 'dfid-new';

  @override
  dynamic getData() async {}
}

class _LoginOnlyNetease extends Neteasecloud {
  _LoginOnlyNetease({required super.accountData, required super.management});

  @override
  dynamic getData() async {}
}

class _LoginOnlyNavidrome extends Navidrome {
  _LoginOnlyNavidrome({required super.accountData, required super.management});

  @override
  dynamic getData() async {}
}

/// 按路径片段返回假响应，没匹配到的一律给空对象。
Interceptor _respondWith(Map<String, Map<String, dynamic>> byPathFragment) {
  return InterceptorsWrapper(
    onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
      Map<String, dynamic> body = <String, dynamic>{};
      for (final MapEntry<String, Map<String, dynamic>> entry
          in byPathFragment.entries) {
        if (options.path.contains(entry.key)) {
          body = entry.value;
          break;
        }
      }
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: body,
        ),
      );
    },
  );
}

KugouData _kugouAccount(String userid, String nickname) {
  return KugouData(
    token: 'token-$userid',
    userid: userid,
    t_expire_time: 4102444800,
    cover: 'pic-$userid',
    nickname: nickname,
    dfid: 'dfid-$userid',
    url: '',
  );
}

NetEaseCloudData _neteaseAccount(String userid, String nickname) {
  return NetEaseCloudData(
    cookies: 'MUSIC_U=$userid',
    loginType: 2,
    token: 'token-$userid',
    userid: userid,
    cover: 'pic-$userid',
    nickname: nickname,
    url: '',
  );
}

NavidromeData _navidromeAccount(String user) {
  return NavidromeData(
    u: user,
    t: 'token-$user',
    p: 'password',
    s: 'salt',
    name: '服务器',
    url: 'http://nav.example/rest',
  );
}

String _useridOf(dynamic account) {
  if (account is KugouData) {
    return account.userid;
  }
  if (account is NetEaseCloudData) {
    return account.userid;
  }
  if (account is NavidromeData) {
    return account.u;
  }
  throw StateError('未知账号类型: ${account.runtimeType}');
}

/// 加完账号之后：新账号追加在末尾，原来那个原样留着，登录索引指向新的。
void _expectAppended(Management management, int type, List<String> userids) {
  expect(
    management.accountData.data[type].map(_useridOf).toList(),
    userids,
    reason: '新账号该追加在末尾，原来那个必须原样留着',
  );
  expect(management.accountData.login, <int>[type, 1]);
}

/// 模拟导航栏 AccountDisplay、账号页这类监听 Management 的组件。
///
/// 它们在对话框子树之外，且已经先于对话框完成构建——正是
/// "setState() called during build" 断言会命中的目标。
class _OutsideManagementListener extends StatefulWidget {
  const _OutsideManagementListener({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  State<_OutsideManagementListener> createState() =>
      _OutsideManagementListenerState();
}

class _OutsideManagementListenerState
    extends State<_OutsideManagementListener> {
  @override
  void initState() {
    super.initState();
    Management().addListener(_handleManagementChanged);
  }

  @override
  void dispose() {
    Management().removeListener(_handleManagementChanged);
    super.dispose();
  }

  void _handleManagementChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(onPressed: widget.onAddAccount, child: const Text('添加账号')),
        Text('loginType=${Management().loginType}'),
      ],
    );
  }
}

Management _seedManagement({String qr = 'none'}) {
  final Management management = Management();
  management.accountData = AccountData(login: [0, 0], data: [[], [], []]);
  management.loginType = -1;
  switch (qr) {
    case 'recording':
      management.KuGouCloud = _RecordingQrKuGou(
        accountData: management.accountData,
        management: management,
      );
      management.NeteasecloudCloud = _RecordingQrNetease(
        accountData: management.accountData,
        management: management,
      );
    case 'instant':
      management.KuGouCloud = _InstantQrKuGou(
        accountData: management.accountData,
        management: management,
      );
      management.NeteasecloudCloud = _InstantQrNetease(
        accountData: management.accountData,
        management: management,
      );
    default:
      management.KuGouCloud = _NoNetworkKuGou(
        accountData: management.accountData,
        management: management,
      );
      management.NeteasecloudCloud = _NoNetworkNetease(
        accountData: management.accountData,
        management: management,
      );
  }
  return management;
}

Widget _loginHost() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => _OutsideManagementListener(
          onAddAccount: () => showAccountLoginDialog(context),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('打开登录弹窗时不会在 build 阶段通知 Management 监听者', (
    WidgetTester tester,
  ) async {
    final Management management = _seedManagement();

    await tester.pumpWidget(_loginHost());
    expect(find.text('loginType=-1'), findsOneWidget);

    await tester.tap(find.text('添加账号'));
    // 弹窗路由在这一帧的 build 阶段挂载。initState 里若同步写 loginType，
    // setter 会立刻 notifyListeners，把对话框子树之外的监听者标脏，
    // 断言 "setState() called during build" 就在这里抛出。
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // 状态写入被推迟到本帧末尾，监听者随后正常重建。
    expect(management.loginType, 0);
    expect(find.text('loginType=0'), findsOneWidget);
  });

  testWidgets('关闭登录弹窗会把 loginType 复位为 -1', (WidgetTester tester) async {
    final Management management = _seedManagement();

    await tester.pumpWidget(_loginHost());
    await tester.tap(find.text('添加账号'));
    await tester.pump();
    await tester.pump();
    expect(management.loginType, 0);

    await tester.tap(find.byTooltip('关闭窗口'));
    await tester.pumpAndSettle();

    // 复位同样发生在卸载阶段，不能把弹窗子树之外的监听者写崩。
    expect(tester.takeException(), isNull);
    expect(management.loginType, -1);
    expect(find.text('loginType=-1'), findsOneWidget);
  });

  testWidgets('切换到二维码页不会放弃本次登录', (WidgetTester tester) async {
    final Management management = _seedManagement();

    await tester.pumpWidget(_loginHost());
    await tester.tap(find.text('添加账号'));
    await tester.pump();
    await tester.pump();
    expect(management.loginType, 0);

    // 手机号表单与二维码页是同一个槽位上的两种 widget，切换会 dispose 掉前者。
    // 复位逻辑若挂在 AccountLogin 上，这里就会把 loginType 打成 -1，二维码轮询
    // 随之退出——二维码显示着，却永远等不到扫码结果。
    await tester.tap(find.byIcon(BootstrapIcons.qr_code_scan));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(management.loginType, 0, reason: '换页只是换视图，不该放弃本次登录');

    // 真正退出登录界面（关弹窗）时才该复位。
    await tester.tap(find.byTooltip('关闭窗口'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(management.loginType, -1);
  });

  testWidgets('登录成功后关闭弹窗不会把 loginType 覆盖成 -1', (WidgetTester tester) async {
    final Management management = _seedManagement();

    await tester.pumpWidget(_loginHost());
    await tester.tap(find.text('添加账号'));
    await tester.pump();
    await tester.pump();
    expect(management.loginType, 0);

    // 模拟二维码登录成功：登录界面应当自己关掉，并且复位逻辑要放过这个结果。
    management.loginType = 1;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(management.loginType, 1);
    expect(find.text('loginType=1'), findsOneWidget);
  });

  test('loginType 复位后，二维码轮询循环会退出', () async {
    final Management management = _seedManagement();
    management.loginType = 0;

    final Future<void> polling = management.loginByQrCode();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(management.loginType, 0, reason: '还没放弃登录，轮询应当继续');

    management.cancelLogin();

    // 复位前这里的 while(true) 永远不会返回。
    await polling.timeout(const Duration(seconds: 1));
    expect(management.loginType, -1);
  });

  test('登录已经出结果时 cancelLogin 不覆盖结果', () {
    final Management management = _seedManagement();

    management.loginType = 1;
    management.cancelLogin();
    expect(management.loginType, 1);

    management.loginType = 2;
    management.cancelLogin();
    expect(management.loginType, 2);
  });

  testWidgets('取二维码之前，本次登录已经复位（含上一次扫码成功的残留锁存）', (
    WidgetTester tester,
  ) async {
    final Management management = _seedManagement(qr: 'recording');
    // 上一次扫码登录成功留下的状态：loginType=1，两个云服务的 qrCodeType=1。
    // qrCodeType 是「本轮扫码成功了」的锁存，成功后没人清它。
    management.loginType = 1;
    management.KuGouCloud.qrCodeType = 1;
    management.NeteasecloudCloud.qrCodeType = 1;

    await tester.pumpWidget(_loginHost());
    await tester.tap(find.text('添加账号'));
    await tester.pump();
    await tester.pump();

    final _RecordingQrKuGou kuGou =
        management.KuGouCloud as _RecordingQrKuGou;
    expect(
      kuGou.loginTypeAtFetch,
      0,
      reason: '二维码一回来就会起轮询，取码时就必须已经是「本次登录中」',
    );
    expect(
      kuGou.qrCodeTypeAtFetch,
      0,
      reason: '残留的锁存不清掉，loginByQrCode 会把它当成这次的结果',
    );
    expect(
      management.NeteasecloudCloud.qrCodeType,
      0,
      reason: '两个云服务都要复位',
    );
  });

  testWidgets('上一次扫码成功后重新打开弹窗，弹窗不会被残留状态立刻关掉', (
    WidgetTester tester,
  ) async {
    final Management management = _seedManagement(qr: 'instant');
    management.loginType = 1;
    management.KuGouCloud.qrCodeType = 1;

    await tester.pumpWidget(_loginHost());
    await tester.tap(find.text('添加账号'));
    await tester.pump();
    await tester.pump();
    expect(management.loginType, 0);

    // 二维码取回后 Management.loginByQrCode 开始轮询。残留的 qrCodeType
    // 会让它在第一轮就把 loginType 判成 1，弹窗随即自己关掉。
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(management.loginType, 0, reason: '刚打开就被判成登录成功了');
    expect(find.byTooltip('关闭窗口'), findsOneWidget, reason: '弹窗不该自己关掉');

    // 收尾：关掉弹窗让轮询退出，免得测试结束时还挂着定时器。
    await tester.tap(find.byTooltip('关闭窗口'));
    await tester.pumpAndSettle();
  });

  test('关掉登录界面又打开，上一轮的二维码轮询不会复活', () async {
    final Management management = _seedManagement();
    // 让 updateAccount 走空账户分支，免得它去读空列表。
    management.accountData = AccountData(login: [-1, -1], data: [[], [], []]);

    management.loginType = 0;
    final Future<void> staleLoop = management.loginByQrCode();

    // 关掉登录界面（loginType → -1），紧接着又开一轮（→ 0，世代号 +1）。
    // 上一轮的循环还睡在 10ms 的间隔里，醒来时只看 loginType 的话会以为
    // 自己还活着，然后把新一轮的扫码结果当成自己的。
    management.cancelLogin();
    management.startLogin();
    management.KuGouCloud.qrCodeType = 1;

    await staleLoop.timeout(const Duration(seconds: 2));
    expect(management.loginType, 0, reason: '旧循环不该认领新一轮的扫码结果');
  });

  test('关掉登录界面又打开，上一轮的酷狗轮询会退出', () async {
    final Management management = _seedManagement();
    final Interceptor interceptor = _holdQrCheck();
    KuGou.dio.interceptors.add(interceptor);
    addTearDown(() => KuGou.dio.interceptors.remove(interceptor));

    management.loginType = 0;
    final Future<dynamic> staleLoop = management.KuGouCloud.loginByQrCode('');

    // 二维码 key 是共享字段，新一轮会把它覆盖掉。上一轮的循环若还活着，
    // 两个循环就一起轮询同一个 key —— 扫一次把账号加两遍。
    management.cancelLogin();
    management.startLogin();

    // 能返回就说明它认出了「这已经不是我这轮了」；退不出来会一直转下去。
    await staleLoop.timeout(const Duration(seconds: 5));
    expect(management.loginType, 0, reason: '旧循环不该动新一轮的状态');
  });

  test('关掉登录界面又打开，上一轮的网易云轮询会退出', () async {
    final Management management = _seedManagement();
    final Interceptor interceptor = _holdQrCheck();
    Neteasecloud.dio.interceptors.add(interceptor);
    addTearDown(() => Neteasecloud.dio.interceptors.remove(interceptor));

    management.loginType = 0;
    final Future<dynamic> staleLoop = management.NeteasecloudCloud
        .loginByQrCode('');

    management.cancelLogin();
    management.startLogin();

    await staleLoop.timeout(const Duration(seconds: 5));
    expect(management.loginType, 0, reason: '旧循环不该动新一轮的状态');
  });

  test('已登录时用酷狗扫码加账号，不会顶掉原本登录的那个', () async {
    final Management management = _seedManagement();
    management.fileManage = _NoDiskFileManage();

    // 已经登录着酷狗账号 111，登录索引指向它。
    management.accountData = AccountData(
      login: [0, 0],
      data: [
        [_kugouAccount('111', '原账号')],
        [],
        [],
      ],
    );

    final KuGou kuGou = _LoginOnlyKuGou(
      accountData: management.accountData,
      management: management,
    );

    final Interceptor interceptor = _respondWith(<String, Map<String, dynamic>>{
      '/login/qr/check': <String, dynamic>{
        'status': 1,
        'data': <String, dynamic>{
          'status': 4,
          'token': 'token-new',
          'userid': 222,
          'nickname': '新账号',
          'pic': 'pic-new',
        },
      },
      '/login/token': <String, dynamic>{
        'status': 1,
        'data': <String, dynamic>{
          'token': 'token-new-refreshed',
          'userid': 222,
          't_expire_time': 4102444800,
          'nickname': '新账号',
          'pic': 'pic-new',
        },
      },
    });
    KuGou.dio.interceptors.add(interceptor);
    addTearDown(() => KuGou.dio.interceptors.remove(interceptor));

    management.loginType = 0;
    await kuGou.loginByQrCode('').timeout(const Duration(seconds: 5));

    _expectAppended(management, 0, <String>['111', '222']);
  });

  test('已登录时用酷狗手机号加账号，不会顶掉原本登录的那个', () async {
    final Management management = _seedManagement();
    management.fileManage = _NoDiskFileManage();
    management.accountData = AccountData(
      login: [0, 0],
      data: [
        [_kugouAccount('111', '原账号')],
        [],
        [],
      ],
    );

    final KuGou kuGou = _LoginOnlyKuGou(
      accountData: management.accountData,
      management: management,
    );

    final Interceptor interceptor = _respondWith(<String, Map<String, dynamic>>{
      '/login/cellphone': <String, dynamic>{
        'status': 1,
        'data': <String, dynamic>{
          'token': 'token-new',
          'userid': 222,
          't_expire_time': 4102444800,
          'nickname': '新账号',
          'pic': 'pic-new',
        },
      },
    });
    KuGou.dio.interceptors.add(interceptor);
    addTearDown(() => KuGou.dio.interceptors.remove(interceptor));

    expect(await kuGou.loginByMobile('13800000000', '', '1234'), isTrue);

    _expectAppended(management, 0, <String>['111', '222']);
  });

  test('已登录时用网易云扫码加账号，不会顶掉原本登录的那个', () async {
    final Management management = _seedManagement();
    management.fileManage = _NoDiskFileManage();
    management.accountData = AccountData(
      login: [1, 0],
      data: [
        [],
        [_neteaseAccount('111', '原账号')],
        [],
      ],
    );

    final Neteasecloud netease = _LoginOnlyNetease(
      accountData: management.accountData,
      management: management,
    );

    final Interceptor interceptor = _respondWith(<String, Map<String, dynamic>>{
      '/login/qr/check': <String, dynamic>{
        'code': 803,
        'cookie': 'MUSIC_U=new',
      },
      '/user/account': <String, dynamic>{
        'token': 'token-new',
        'account': <String, dynamic>{'id': 222},
        'profile': <String, dynamic>{
          'avatarUrl': 'pic-new',
          'nickname': '新账号',
        },
      },
    });
    Neteasecloud.dio.interceptors.add(interceptor);
    addTearDown(() => Neteasecloud.dio.interceptors.remove(interceptor));

    management.loginType = 0;
    await netease.loginByQrCode('').timeout(const Duration(seconds: 5));

    _expectAppended(management, 1, <String>['111', '222']);
  });

  test('已登录时用网易云手机号加账号，不会顶掉原本登录的那个', () async {
    final Management management = _seedManagement();
    management.fileManage = _NoDiskFileManage();
    management.accountData = AccountData(
      login: [1, 0],
      data: [
        [],
        [_neteaseAccount('111', '原账号')],
        [],
      ],
    );

    final Neteasecloud netease = _LoginOnlyNetease(
      accountData: management.accountData,
      management: management,
    );

    final Interceptor interceptor = _respondWith(<String, Map<String, dynamic>>{
      '/login/cellphone': <String, dynamic>{
        'code': 200,
        'cookie': 'MUSIC_U=new',
        'token': 'token-new',
        'account': <String, dynamic>{'id': 222},
        'profile': <String, dynamic>{
          'avatarUrl': 'pic-new',
          'nickname': '新账号',
        },
      },
    });
    Neteasecloud.dio.interceptors.add(interceptor);
    addTearDown(() => Neteasecloud.dio.interceptors.remove(interceptor));

    expect(await netease.loginByMobile('13800000000', '', '1234'), isTrue);

    _expectAppended(management, 1, <String>['111', '222']);
  });

  test('已登录时用 Navidrome 加账号，不会顶掉原本登录的那个', () async {
    final Management management = _seedManagement();
    management.fileManage = _NoDiskFileManage();
    management.accountData = AccountData(
      login: [2, 0],
      data: [
        [],
        [],
        [_navidromeAccount('111')],
      ],
    );

    final Navidrome navidrome = _LoginOnlyNavidrome(
      accountData: management.accountData,
      management: management,
    );

    final Interceptor interceptor = _respondWith(<String, Map<String, dynamic>>{
      '/ping.view': <String, dynamic>{
        'subsonic-response': <String, dynamic>{'status': 'ok'},
      },
    });
    Navidrome.dio.interceptors.add(interceptor);
    addTearDown(() => Navidrome.dio.interceptors.remove(interceptor));

    expect(
      await navidrome.addLogin('222', 'http://nav.example', 'pw', '服务器'),
      isTrue,
    );

    _expectAppended(management, 2, <String>['111', '222']);
  });
}
