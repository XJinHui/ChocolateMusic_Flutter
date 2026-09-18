import 'package:flutter/material.dart';

import 'package:chocolate_music/pages/computer/DownloadPage.dart';
import 'package:chocolate_music/theme/app_colors.dart';

Future<void> showDownloadDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DownloadDialog(),
  );
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog();

  /// 小窗尺寸，后续需要调整时改这里。
  static const Size _windowSize = Size(400, 500);

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
        width: _windowSize.width,
        height: _windowSize.height,
        child: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: DownloadPage(),
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