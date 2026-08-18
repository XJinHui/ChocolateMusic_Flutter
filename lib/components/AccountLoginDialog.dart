import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/pages/computer/LoginPage.dart';
import 'package:chocolate_music/theme/app_colors.dart';

Future<void> showAccountLoginDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AccountLoginDialog(),
  );
}

class _AccountLoginDialog extends StatefulWidget {
  const _AccountLoginDialog();

  @override
  State<_AccountLoginDialog> createState() => _AccountLoginDialogState();
}

class _AccountLoginDialogState extends State<_AccountLoginDialog> {
  final Management _management = Management();
  bool _isClosingAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _management.loginType = 0;
    _management.addListener(_handleLoginTypeChanged);
    unawaited(_loadQrCodesInBackground());
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
    Navigator.of(context).pop();
  }

  Future<void> _loadQrCodesInBackground() async {
    try {
      await _management.getQrCode();
    } catch (_) {
      // The QR code view renders its own failure state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: LoginPage(),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: '关闭窗口',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
