import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:chocolate_music/Computer.dart';
import 'package:chocolate_music/Phone.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';


bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final management = Management();
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
        child: ColoredBox(
          color: AppColors.background,
          child: child,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
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
