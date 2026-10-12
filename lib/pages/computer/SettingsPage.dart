import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/theme/app_colors.dart';

/// 音质等级名称。索引与 [Setting.qualityTier]、[Setting.downloadQualityTier]
/// 的取值一一对应（0 标准、1 高品、2 无损）。
const List<String> _kQualityTierLabels = ['标准音质', '高品音质', '无损音质'];

/// 在线播放的音质说明，与 [_kQualityTierLabels] 同序。
const List<String> _kPlayQualityDetails = [
  '128 kbps，体积最小，网络不佳时更流畅',
  '320 kbps，音质与流量的平衡之选',
  'FLAC 无损，保留录音全部细节，流量消耗最大',
];

/// 下载的音质说明，与 [_kQualityTierLabels] 同序。
const List<String> _kDownloadQualityDetails = [
  '128 kbps，占用磁盘空间最小',
  '320 kbps，日常下载的推荐选择',
  'FLAC 无损，适合长期收藏与本地回放',
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.management});

  final Management? management;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Management _management;

  final TextEditingController _pathController = TextEditingController();
  bool _editingPath = false;
  String? _pathError;

  /// 选择框开着或正在落盘，期间下载地址那几个按钮一律禁用，
  /// 免得连点开出两个系统弹窗、或者重复写一遍设置。
  bool _busy = false;

  // 两个音质模块默认收起，只露当前档位；点标题栏才展开备选。
  bool _playQualityExpanded = false;
  bool _downloadQualityExpanded = false;

  @override
  void initState() {
    super.initState();
    _management = widget.management ?? Management();
    _management.addListener(_handleManagementChanged);
  }

  @override
  void dispose() {
    _management.removeListener(_handleManagementChanged);
    _pathController.dispose();
    super.dispose();
  }

  void _handleManagementChanged() {
    if (!mounted) {
      return;
    }
    // 正在改下载地址时不跟着刷新，否则外部一次 notify 就会把输入框里的
    // 半截路径换成设置里的旧值。
    if (_editingPath) {
      return;
    }
    setState(() {});
  }

  /// 设置里保存的下载地址，空串表示「跟随默认目录」。
  String get _configuredPath => _management.setting.downloadPath;

  bool get _usingDefaultPath => _configuredPath.isEmpty;

  /// 当前实际生效的下载目录。
  String get _currentPath =>
      _usingDefaultPath ? _management.musicManagement.defaultDownloadDir : _configuredPath;

  void _toggleQualitySection({required bool forDownload}) {
    setState(() {
      if (forDownload) {
        _downloadQualityExpanded = !_downloadQualityExpanded;
      } else {
        _playQualityExpanded = !_playQualityExpanded;
      }
    });
  }

  void _selectQuality({required bool forDownload, required int tier}) {
    final Setting setting = _management.setting;
    final int current = forDownload
        ? setting.downloadQualityTier
        : setting.qualityTier;

    if (current != tier) {
      if (forDownload) {
        setting.downloadQualityTier = tier;
      } else {
        setting.qualityTier = tier;
      }

      _management.updateSetting();
    }

    // 选完就收回去，收起态本身就是「当前选的是什么」的答案。
    setState(() {
      if (forDownload) {
        _downloadQualityExpanded = false;
      } else {
        _playQualityExpanded = false;
      }
    });
  }

  /// 打开系统目录选择框挑一个目录。
  ///
  /// 选择器不可用时（平台没实现，或弹窗本身出错）退回手动输入，
  /// 免得按钮点了没反应。
  Future<void> _pickPath() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    String? picked;

    try {
      picked = await getDirectoryPath(
        initialDirectory: _currentPath,
        confirmButtonText: '选择文件夹',
      );
    } catch (e) {
      print('系统目录选择器不可用：$e');
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      _beginEditPath();
      showMusicToast(
        context,
        message: '打不开系统目录选择器，请手动输入路径',
        success: false,
      );
      return;
    }

    if (!mounted) {
      return;
    }

    // 用户在系统弹窗里点了取消
    if (picked == null) {
      setState(() {
        _busy = false;
      });
      return;
    }

    await _applyPath(picked);
  }

  void _beginEditPath() {
    setState(() {
      _editingPath = true;
      _pathError = null;
      _pathController.text = _currentPath;
      _pathController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _pathController.text.length,
      );
    });
  }

  void _cancelEditPath() {
    setState(() {
      _editingPath = false;
      _pathError = null;
    });
  }

  Future<void> _saveTypedPath() async {
    final String value = _pathController.text.trim();

    if (value.isEmpty) {
      setState(() {
        _pathError = '下载地址不能为空';
      });
      return;
    }

    await _applyPath(value);
  }

  Future<void> _applyPath(String path) async {
    setState(() {
      _busy = true;
      _pathError = null;
    });

    final bool success = await _management.applyDownloadPath(path);

    if (!mounted) {
      return;
    }

    final bool wasEditing = _editingPath;

    setState(() {
      _busy = false;
      if (success) {
        _editingPath = false;
      } else if (wasEditing) {
        // 错误提示只有编辑态才显示得出来，非编辑态走 toast。
        _pathError = '无法使用该目录，请检查路径是否正确、是否有写入权限';
      }
    });

    if (success) {
      showMusicToast(context, message: '下载地址已更新');
    } else if (!wasEditing) {
      showMusicToast(
        context,
        message: '无法使用该目录，请检查路径是否有写入权限',
        success: false,
      );
    }
  }

  Future<void> _restoreDefaultPath() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    final bool success = await _management.applyDownloadPath('');

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
    });

    showMusicToast(
      context,
      message: success ? '已恢复默认下载地址' : '恢复默认下载地址失败',
      success: success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Setting setting = _management.setting;

    return DecoratedBox(
      key: const Key('settings-page-backdrop'),
      decoration: const BoxDecoration(color: AppColors.background),
      child: EdgeFadeMask(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1275),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PageHeading(),
                  const SizedBox(height: 28),
                  _SettingSection(
                    headerKey: const Key('play-quality-header'),
                    icon: BootstrapIcons.music_note_beamed,
                    title: '音质等级',
                    description: '在线播放时优先请求的音质，音源不支持时会自动降级',
                    trailing: _CurrentValueTag(
                      key: const Key('play-quality-current'),
                      label: _kQualityTierLabels[setting.qualityTier],
                    ),
                    expanded: _playQualityExpanded,
                    onToggle: () => _toggleQualitySection(forDownload: false),
                    child: Column(
                      children: [
                        for (int i = 0; i < _kQualityTierLabels.length; i++)
                          _QualityOptionRow(
                            key: Key('play-quality-option-$i'),
                            label: _kQualityTierLabels[i],
                            detail: _kPlayQualityDetails[i],
                            isSelected: setting.qualityTier == i,
                            onTap: () =>
                                _selectQuality(forDownload: false, tier: i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SettingSection(
                    headerKey: const Key('download-quality-header'),
                    icon: BootstrapIcons.download,
                    title: '下载音质等级',
                    description: '下载歌曲时使用的音质，影响文件体积与音质',
                    trailing: _CurrentValueTag(
                      key: const Key('download-quality-current'),
                      label: _kQualityTierLabels[setting.downloadQualityTier],
                    ),
                    expanded: _downloadQualityExpanded,
                    onToggle: () => _toggleQualitySection(forDownload: true),
                    child: Column(
                      children: [
                        for (int i = 0; i < _kQualityTierLabels.length; i++)
                          _QualityOptionRow(
                            key: Key('download-quality-option-$i'),
                            label: _kQualityTierLabels[i],
                            detail: _kDownloadQualityDetails[i],
                            isSelected: setting.downloadQualityTier == i,
                            onTap: () =>
                                _selectQuality(forDownload: true, tier: i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SettingSection(
                    icon: BootstrapIcons.folder,
                    title: '下载地址',
                    description: '歌曲文件的保存位置',
                    bodyPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: _buildDownloadPathBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadPathBody() {
    final Widget pathBox = _editingPath ? _buildPathField() : _buildPathDisplay();

    final Widget actions = _editingPath
        ? _PathActions(
            children: [
              _SettingsButton(
                key: const Key('save-download-path-button'),
                icon: BootstrapIcons.check2,
                label: '保存',
                isPrimary: true,
                onPressed: _busy ? null : _saveTypedPath,
              ),
              _SettingsButton(
                key: const Key('cancel-download-path-button'),
                icon: BootstrapIcons.x_lg,
                label: '取消',
                onPressed: _busy ? null : _cancelEditPath,
              ),
            ],
          )
        : _PathActions(
            children: [
              _SettingsButton(
                key: const Key('edit-download-path-button'),
                icon: BootstrapIcons.folder2_open,
                label: '更改',
                onPressed: _busy ? null : _pickPath,
              ),
              _SettingsButton(
                key: const Key('restore-download-path-button'),
                icon: BootstrapIcons.arrow_counterclockwise,
                label: '恢复默认',
                onPressed: _busy || _usingDefaultPath
                    ? null
                    : _restoreDefaultPath,
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 窄窗口下按钮挤在路径框右边会把路径压成一条缝，改成上下排布。
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [pathBox, const SizedBox(height: 12), actions],
              );
            }

            return Row(
              // 按钮和路径框同高，居中对齐才不会一个顶着一个的边。
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: pathBox),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          _editingPath
              ? '填绝对路径，例如 D:\\Music；目录不存在时会自动创建。'
              : '点「更改」从系统文件管理器里选目录；歌词与下载中的临时文件，分别存放在该目录的 Lyric、.tmp 子目录下。',
          style: const TextStyle(
            color: AppColors.accountMutedInk,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPathDisplay() {
    return Container(
      key: const Key('download-path-display'),
      // 与旁边的按钮共用高度，两者并排时中线才对得齐
      height: _SettingsButton.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.accountGlassStrong,
        border: Border.all(color: AppColors.accountGlassOutline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            BootstrapIcons.folder2_open,
            size: 16,
            color: AppColors.accountMutedInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: _currentPath,
              child: Text(
                _currentPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.accountInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_usingDefaultPath) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accountSelection,
                border: Border.all(color: AppColors.accountSelectionBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '默认',
                style: TextStyle(
                  color: AppColors.selectedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('download-path-field'),
          controller: _pathController,
          autofocus: true,
          onSubmitted: (_) => _saveTypedPath(),
          style: const TextStyle(
            color: AppColors.accountInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '例如 D:\\Music',
            hintStyle: const TextStyle(
              color: AppColors.accountDisabledInk,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              BootstrapIcons.folder2_open,
              size: 16,
              color: AppColors.accountMutedInk,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 48,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            filled: true,
            fillColor: AppColors.accountGlassStrong,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _pathError == null
                    ? AppColors.accountGlassOutline
                    : AppColors.likeIconColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.selectedText,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (_pathError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                BootstrapIcons.exclamation_circle,
                size: 13,
                color: AppColors.likeIconColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _pathError!,
                  style: const TextStyle(
                    color: AppColors.likeIconColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设置',
          style: TextStyle(
            color: AppColors.accountInk,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '调整播放、下载与存储偏好',
          style: TextStyle(color: AppColors.accountMutedInk, fontSize: 14),
        ),
      ],
    );
  }
}

/// 设置页的卡片外壳：图标 + 标题 + 说明，下方一条分隔线再接内容区。
///
/// 传了 [expanded] 就是可折叠卡片：默认收起时只剩标题栏，点标题栏展开；
/// 收起时连分隔线一起藏掉，卡片边缘不会留一条孤零零的线。
class _SettingSection extends StatelessWidget {
  const _SettingSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    this.trailing,
    this.headerKey,
    this.bodyPadding = const EdgeInsets.fromLTRB(14, 10, 14, 14),
    this.expanded,
    this.onToggle,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final Widget? trailing;
  final Key? headerKey;
  final EdgeInsetsGeometry bodyPadding;
  final bool? expanded;
  final VoidCallback? onToggle;

  bool get _collapsible => expanded != null;

  @override
  Widget build(BuildContext context) {
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.accountDivider,
        ),
        Padding(padding: bodyPadding, child: child),
      ],
    );

    final Widget header = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accountSelection,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.selectedText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.accountInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.accountMutedInk,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (_collapsible) ...[
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: expanded! ? 0.5 : 0,
            duration: duration,
            child: const Icon(
              BootstrapIcons.chevron_down,
              size: 15,
              color: AppColors.accountMutedInk,
            ),
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accountGlass,
        border: Border.all(color: AppColors.accountGlassBorder),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.accountShadow,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_collapsible)
            Semantics(
              button: true,
              expanded: expanded,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: headerKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                    child: header,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: header,
            ),
          if (!_collapsible)
            body
          else
            AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded!
                  ? body
                  : const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
    );
  }
}

/// 卡片右上角的当前取值标签。
class _CurrentValueTag extends StatelessWidget {
  const _CurrentValueTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accountSelection,
        border: Border.all(color: AppColors.accountSelectionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.selectedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 单个音质选项：选中态走账号页同款的浅蓝底 + 蓝字 + 勾选圈。
class _QualityOptionRow extends StatefulWidget {
  const _QualityOptionRow({
    super.key,
    required this.label,
    required this.detail,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_QualityOptionRow> createState() => _QualityOptionRowState();
}

class _QualityOptionRowState extends State<_QualityOptionRow> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant _QualityOptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      _isHovering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = widget.isSelected
        ? AppColors.accountSelection
        : _isHovering
        ? AppColors.floating
        : AppColors.transparent;
    final Color labelColor = widget.isSelected
        ? AppColors.selectedText
        : AppColors.accountInk;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: '${widget.label}，${widget.detail}',
      child: Focus(
        onFocusChange: (bool isFocused) {
          setState(() {
            _isFocused = isFocused;
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (!_isHovering) {
              setState(() {
                _isHovering = true;
              });
            }
          },
          onExit: (_) {
            if (_isHovering) {
              setState(() {
                _isHovering = false;
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: AnimatedContainer(
                duration: Duration.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                constraints: const BoxConstraints(minHeight: 66),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.accountSelectionBorder
                        : _isFocused
                        ? AppColors.selectedText
                        : AppColors.transparent,
                    width: _isFocused && !widget.isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.accountMutedInk,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SelectionMark(isSelected: widget.isSelected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 选项右侧的圆形勾选标记。
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.selectedText : AppColors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? AppColors.selectedText
              : AppColors.accountGlassOutline,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _PathActions extends StatelessWidget {
  const _PathActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  /// 与下载地址路径框同高，两者并排时中线才对得齐。
  static const double height = 48;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, size: 15);
    final Widget labelWidget = Text(
      label,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    );
    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    if (isPrimary) {
      return SizedBox(
        height: height,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: labelWidget,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.selectedText,
            foregroundColor: Colors.white,
            minimumSize: const Size(96, height),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: shape,
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: labelWidget,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accountInk,
          backgroundColor: AppColors.accountDisabledFill,
          disabledForegroundColor: AppColors.accountDisabledInk,
          side: const BorderSide(color: AppColors.accountGlassOutline),
          minimumSize: const Size(96, height),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: shape,
        ),
      ),
    );
  }
}
