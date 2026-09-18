import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';

import 'package:chocolate_music/theme/app_colors.dart';

/// 二次确认小窗。
///
/// 一般用 [showConfirmDialog] 弹出，它会等到用户做出选择后返回结果；
/// 需要自己安排弹出时机时，也可以直接 showDialog 弹本组件。
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message = '',
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.danger = false,
  });

  /// 小窗标题。
  final String title;

  /// 标题下方的说明文字，为空时不占位置。
  final String message;

  /// 确认按钮文案。
  final String confirmText;

  /// 取消按钮文案。
  final String cancelText;

  /// 危险操作（如删除）传 true：标题带警示图标，确认按钮用警示色，
  /// 避免用户顺手点过去。
  final bool danger;

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
      // 只有标题和一行说明，高度跟着内容走，不用固定尺寸
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (danger) ...[
                    const Icon(
                      BootstrapIcons.exclamation_circle,
                      color: AppColors.likeIconColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.normalText,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ],
              ),

              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.musicSingerColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.buttonIcon,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(cancelText),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: danger
                              ? AppColors.likeIconColor
                              : AppColors.selectedText,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(confirmText),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出二次确认小窗。
///
/// 点确认（或直接回车）返回 true；点取消、点小窗外部返回 false，
/// 所以调用方不用处理 null。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String message = '',
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
    ),
  );

  return confirmed ?? false;
}