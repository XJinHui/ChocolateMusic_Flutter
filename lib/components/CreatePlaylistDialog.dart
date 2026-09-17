import 'package:flutter/material.dart';

import 'package:chocolate_music/theme/app_colors.dart';

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({
    super.key,
    required this.onConfirm,
    this.onCancel,
    this.title = '新建歌单',
    this.hintText = '请输入歌单名',
    this.initialName = '',
  });

  /// 点「创建」或在输入框里按回车时调用，参数是去掉首尾空格后的歌单名。
  ///
  /// 组件会 await 这个回调：等待期间输入框、两个按钮和右上角关闭按钮全部禁用，
  /// 「创建」按钮内显示转圈，避免连点建出多个同名歌单。
  final Future<void> Function(String name) onConfirm;

  /// 点「取消」或右上角关闭按钮时调用。不传则默认关闭小窗。
  final VoidCallback? onCancel;

  /// 小窗标题。
  final String title;

  /// 输入框的提示文字。
  final String hintText;

  /// 输入框的初始内容。
  final String initialName;

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );

  /// 是否正在等待 [CreatePlaylistDialog.onConfirm] 完成。
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 输入框内容变了要重算「创建」按钮的可用状态
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _name => _nameController.text.trim();

  /// 歌单名为空或正在提交时，不允许再点「创建」。
  bool get _canSubmit => !_submitting && _name.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onConfirm(_name);
    } finally {
      // 回调里一般会自己 pop 掉小窗，这时候本 State 已经卸载，不能再 setState
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _cancel() {
    // 请求已经发出去了，这时候关窗只会让用户看不到结果，所以提交期间不允许取消
    if (_submitting) {
      return;
    }

    final VoidCallback? onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
      return;
    }

    Navigator.of(context).pop();
  }

  /// 输入框样式，与登录小窗里的输入框保持一致。
  InputDecoration _inputDecoration() {
    const BorderRadius borderRadius = BorderRadius.all(Radius.circular(26));
    const Color borderColor = Color(0xFFD6D6D6);

    return InputDecoration(
      hintText: widget.hintText,
      hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: AppColors.background,
      border: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      // 提交期间输入框被禁用，边框保持在同一种灰上，避免闪一下黑边
      disabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: AppColors.selectedText, width: 2),
      ),
    );
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
      // 只有一个输入框，高度跟着内容走，不用登录小窗那种 400x500 的固定尺寸
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.normalText,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭窗口',
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: _submitting ? null : _cancel,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !_submitting,
                // 只能用「创建」按钮提交，回车不做任何事
                textInputAction: TextInputAction.none,
                decoration: _inputDecoration(),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: _submitting ? null : _cancel,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.buttonIcon,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.selectedText,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.loginButtonColor,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('创建'),
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