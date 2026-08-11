import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

const String activateWindowMethod = 'activateWindow';

class IndependentWindowService {
  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<void>? _openingAccountWindow;
  static WindowController? _accountWindow;

  static Future<void> openAccountWindow() async {
    if (!_isDesktop) {
      return;
    }

    // Coalesce concurrent taps before doing any platform enumeration.
    final Future<void>? opening = _openingAccountWindow;
    if (opening != null) {
      await opening;
      return;
    }

    final WindowController? cachedWindow = _accountWindow;
    if (cachedWindow != null) {
      try {
        await _showAndActivate(cachedWindow);
        return;
      } catch (_) {
        // The child may have been closed externally; rediscover it below.
        _accountWindow = null;
      }
    }

    final WindowController? existingWindow = await _findAccountWindow();
    if (existingWindow != null) {
      _accountWindow = existingWindow;
      await _showAndActivate(existingWindow);
      return;
    }

    final Future<void> createTask = _createAccountWindow();
    _openingAccountWindow = createTask;
    try {
      await createTask;
    } finally {
      if (identical(_openingAccountWindow, createTask)) {
        _openingAccountWindow = null;
      }
    }
  }

  static Future<WindowController?> _findAccountWindow() async {
    final List<WindowController> windows = await WindowController.getAll();
    for (final WindowController controller in windows) {
      if (_windowType(controller.arguments) == 'account_login') {
        return controller;
      }
    }
    return null;
  }

  static Future<void> _createAccountWindow() async {
    Rect? parentBounds;
    try {
      parentBounds = await windowManager.getBounds();
    } catch (_) {
      parentBounds = null;
    }

    final WindowController controller = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({
          'windowType': 'account_login',
          'parentLeft': parentBounds?.left,
          'parentTop': parentBounds?.top,
          'parentWidth': parentBounds?.width,
          'parentHeight': parentBounds?.height,
        }),
        // Keep the native window hidden until the child has applied its
        // complete size and title-bar configuration.
        hiddenAtLaunch: true,
      ),
    );
    _accountWindow = controller;
  }

  static Future<void> _showAndActivate(WindowController controller) async {
    await controller.show();
    await controller.invokeMethod<void>(activateWindowMethod);
  }

  static String _windowType(String rawArguments) {
    try {
      final dynamic decoded = jsonDecode(rawArguments);
      if (decoded is Map<String, dynamic>) {
        return decoded['windowType'] as String? ?? '';
      }
    } catch (_) {
      // Ignore malformed arguments and treat the window as unrelated.
    }
    return '';
  }
}
