import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'package:chocolate_music/Computer.dart';
import 'package:chocolate_music/pages/computer/LoginPage.dart';
import 'package:chocolate_music/Phone.dart';
import 'package:chocolate_music/services/independent_window.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/theme/app_scroll_behavior.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/src/rust/frb_generated.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // 必须调用 -- 媒体播放

  // ⚠️ 必须在使用任何 Rust 函数前调用。
  // 酷狗 API 已从「请求自建服务器」改为「进程内调用 Rust」（见
  // Cloud/KuGouRustAdapter.dart），KuGou.dio 一被访问就会用到它。
  // 子窗口是独立 engine 重跑本入口，所以这段要在多窗口分支**之前**执行。
  await RustLib.init();

  if (_isDesktop) {
    // sqflite 的原生插件在桌面端没有实现，必须切到 FFI 版实现，
    // 否则全局 openDatabase 会抛 Bad state: databaseFactory not initialized。
    // 子窗口是独立 engine 重跑本入口，所以这段要在多窗口分支之前执行。
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (_isDesktop) {
    await windowManager.ensureInitialized();
  }

  if (_isDesktop) {
    try {
      final WindowController currentWindow =
          await WindowController.fromCurrentEngine();
      final Map<String, dynamic> parsedArgs = _parseWindowArgs(
        currentWindow.arguments,
      );
      final String windowType = parsedArgs['windowType'] as String? ?? '';
      if (windowType.isNotEmpty) {
        runApp(
          SubWindowApp(
            windowId: int.tryParse(currentWindow.windowId) ?? -1,
            rawArgs: currentWindow.arguments,
          ),
        );
        return;
      }
    } catch (_) {
      // The default main engine can continue with regular app startup.
    }
  }

  Management();
  runApp(const MyApp());

  if (_isDesktop) {
    doWhenWindowReady(() {
      final initialSize = const Size(1100, 740);
      appWindow.minSize = const Size(900, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      // bitsdojo_window doesn't expose all window_manager APIs (shadow/background),
      // those are handled by the native runner or via Flutter UI. We set the
      // basic sizing/alignment and show the window.
      appWindow.show();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏 DEBUG 标签
      // 桌面端默认行为不接受鼠标拖拽，横向列表会滚不动
      scrollBehavior: const AppScrollBehavior(),
      // home: _isDesktop
      //     ? const DesktopWindowShell(child: HomePage())
      //     : const HomePage(),
      home: HomePage(),
    );
  }
}

class DesktopWindowShell extends StatelessWidget {
  const DesktopWindowShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // const borderRadius = BorderRadius.all(Radius.circular(18));

    return ColoredBox(
      color: Colors.transparent,
      child: ClipRRect(
        // borderRadius: borderRadius,
        child: ColoredBox(color: AppColors.background, child: child),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class SubWindowApp extends StatefulWidget {
  const SubWindowApp({
    super.key,
    required this.windowId,
    required this.rawArgs,
  });

  final int windowId;
  final String rawArgs;

  @override
  State<SubWindowApp> createState() => _SubWindowAppState();
}

class _SubWindowAppState extends State<SubWindowApp> {
  static const Size _accountWindowSize = Size(400, 500);
  final Management _management = Management();
  WindowController? _currentWindowController;
  bool _isClosingAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _management.addListener(_handleLoginTypeChanged);
    _handleLoginTypeChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configureSubWindow();
    });
  }

  @override
  void dispose() {
    _management.removeListener(_handleLoginTypeChanged);
    super.dispose();
  }

  void _handleLoginTypeChanged() {
    if (!mounted || _isClosingAfterLogin || _management.loginType != 1) {
      return;
    }
    _isClosingAfterLogin = true;
    unawaited(windowManager.close());
  }

  Future<void> _initializeCurrentWindowController() async {
    if (_currentWindowController != null) {
      return;
    }

    final WindowController controller =
        await WindowController.fromCurrentEngine();
    if (!mounted) {
      return;
    }

    await controller.setWindowMethodHandler((call) async {
      if (call.method == activateWindowMethod) {
        await _activateSubWindow();
      }
    });

    setState(() {
      _currentWindowController = controller;
    });
  }

  Future<void> _activateSubWindow() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
    _resetLoginType();
  }

  void _resetLoginType() {
    _management.startLogin();
  }

  Future<void> _loadQrCodesInBackground() async {
    try {
      await _management.getQrCode();
    } catch (_) {
      // The QR code view renders its own failure state.
    }
  }

  Future<void> _configureSubWindow() async {
    if (!_isDesktop) {
      return;
    }

    await _initializeCurrentWindowController();

    final Map<String, dynamic> parsedArgs = _parseWindowArgs(widget.rawArgs);
    final String windowType = parsedArgs['windowType'] as String? ?? '';
    if (windowType != 'account_login') {
      return;
    }

    unawaited(_loadQrCodesInBackground());

    final WindowOptions options = const WindowOptions(
      size: _accountWindowSize,
      minimumSize: _accountWindowSize,
      maximumSize: _accountWindowSize,
      center: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);

      final double? parentLeft = _asDouble(parsedArgs['parentLeft']);
      final double? parentTop = _asDouble(parsedArgs['parentTop']);
      final double? parentWidth = _asDouble(parsedArgs['parentWidth']);
      final double? parentHeight = _asDouble(parsedArgs['parentHeight']);

      if (parentLeft != null &&
          parentTop != null &&
          parentWidth != null &&
          parentHeight != null) {
        final double left =
            parentLeft + (parentWidth - _accountWindowSize.width) / 2;
        final double top =
            parentTop + (parentHeight - _accountWindowSize.height) / 2;
        await windowManager.setBounds(
          Rect.fromLTWH(
            left,
            top,
            _accountWindowSize.width,
            _accountWindowSize.height,
          ),
        );
      } else {
        await windowManager.center();
      }

      await windowManager.show();
      await windowManager.focus();
      _resetLoginType();
    });
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> parsedArgs = _parseWindowArgs(widget.rawArgs);
    final String windowType = parsedArgs['windowType'] as String? ?? '';

    if (windowType == 'account_login') {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭窗口',
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await windowManager.close();
                      },
                    ),
                  ],
                ),
                // Expanded(child: AccountPage()),
                Expanded(child: LoginPage()),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        body: Center(
          child: Text('Unknown sub window: $windowType (#${widget.windowId})'),
        ),
      ),
    );
  }
}

Map<String, dynamic> _parseWindowArgs(String value) {
  try {
    final dynamic decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Fallback to empty payload when child window args are malformed.
  }
  return <String, dynamic>{};
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return ComputerHomePage();
    } else {
      return PhotoHomePage();
    }
  }
}
