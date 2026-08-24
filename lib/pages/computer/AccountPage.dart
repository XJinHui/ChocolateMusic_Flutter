import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/AccountLoginDialog.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.management});

  final Management? management;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const List<Color> _kugouAvatarColors = [
    Color(0xFF7BB9FF),
    Color(0xFF97D7D0),
  ];
  static const List<Color> _neteaseAvatarColors = [
    Color(0xFFFFB794),
    Color(0xFFE7A6C3),
    Color(0xFFC7B7F1),
  ];
  static const List<Color> _navidromeAvatarColors = [Color(0xFFA6DAD7)];

  late final Management _management;
  late String _activeProviderId;

  @override
  void initState() {
    super.initState();
    _management = widget.management ?? Management();
    _activeProviderId =
        _providerIdForAccountType(_management.account.type) ?? 'kugou';
    _management.addListener(_handleManagementChanged);
  }

  @override
  void dispose() {
    _management.removeListener(_handleManagementChanged);
    super.dispose();
  }

  void _handleManagementChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _activeProviderId =
          _providerIdForAccountType(_management.account.type) ??
          _activeProviderId;
    });
  }

  List<dynamic> _accountsFor(int loginType) {
    final List<List<dynamic>> data = _management.accountData.data;
    if (loginType < 0 || loginType >= data.length) {
      return const [];
    }
    return data[loginType];
  }

  List<_ProviderPreview> get _providers => [
    _ProviderPreview(
      id: 'kugou',
      loginType: 0,
      name: '酷狗音乐',
      asset: 'assets/images/KuGouConcept.svg',
      stageColor: AppColors.accountStageKuGou,
      stageBorderColor: AppColors.accountStageKuGouBorder,
      accounts: _buildKugouAccounts(),
    ),
    _ProviderPreview(
      id: 'netease-cloud',
      loginType: 1,
      name: '网易云音乐',
      asset: 'assets/images/NetEaseCloud.svg',
      stageColor: AppColors.accountStageNetEaseCloud,
      stageBorderColor: AppColors.accountStageNetEaseCloudBorder,
      accounts: _buildNetEaseAccounts(),
    ),
    _ProviderPreview(
      id: 'navidrome',
      loginType: 2,
      name: 'Navidrome',
      asset: 'assets/images/Navidrome.svg',
      stageColor: AppColors.accountStageNavidrome,
      stageBorderColor: AppColors.accountStageNavidromeBorder,
      accounts: _buildNavidromeAccounts(),
    ),
  ];

  List<_AccountPreview> _buildKugouAccounts() {
    final List<KugouData> accounts = _accountsFor(
      0,
    ).whereType<KugouData>().toList();
    return List<_AccountPreview>.generate(accounts.length, (int index) {
      final KugouData account = accounts[index];
      return _AccountPreview(
        id: _accountId('kugou', account.userid, index),
        loginType: 0,
        sourceIndex: index,
        nickname: account.nickname,
        avatarLabel: _avatarLabel(account.nickname),
        avatarUrl: account.cover,
        avatarColor: _avatarColor(_kugouAvatarColors, index),
      );
    });
  }

  List<_AccountPreview> _buildNetEaseAccounts() {
    final List<NetEaseCloudData> accounts = _accountsFor(
      1,
    ).whereType<NetEaseCloudData>().toList();
    return List<_AccountPreview>.generate(accounts.length, (int index) {
      final NetEaseCloudData account = accounts[index];
      return _AccountPreview(
        id: _accountId('netease', account.userid, index),
        loginType: 1,
        sourceIndex: index,
        nickname: account.nickname,
        avatarLabel: _avatarLabel(account.nickname),
        avatarUrl: account.cover,
        avatarColor: _avatarColor(_neteaseAvatarColors, index),
      );
    });
  }

  List<_AccountPreview> _buildNavidromeAccounts() {
    final List<NavidromeData> accounts = _accountsFor(
      2,
    ).whereType<NavidromeData>().toList();
    return List<_AccountPreview>.generate(accounts.length, (int index) {
      final NavidromeData account = accounts[index];
      return _AccountPreview(
        id: _accountId('navidrome', account.u, index),
        loginType: 2,
        sourceIndex: index,
        nickname: account.u,
        avatarLabel: _avatarLabel(account.u),
        avatarUrl: '',
        avatarColor: _avatarColor(_navidromeAvatarColors, index),
      );
    });
  }

  Color _avatarColor(List<Color> colors, int index) {
    return colors[index % colors.length];
  }

  String _accountId(String providerId, String identity, int index) {
    final String normalized = identity
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$providerId-${normalized.isEmpty ? index : normalized}';
  }

  String _avatarLabel(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '音' : trimmed.substring(0, 1);
  }

  String? _providerIdForAccountType(String accountType) {
    switch (accountType) {
      case '酷狗音乐':
        return 'kugou';
      case '网易云':
        return 'netease-cloud';
      case 'Navidrome':
        return 'navidrome';
      default:
        return null;
    }
  }

  int get _selectedLoginType => _management.accountData.login.first;

  int get _selectedAccountIndex => _management.accountData.login.last;

  int get _accountCount => _providers.fold(
    0,
    (int total, _ProviderPreview provider) => total + provider.accounts.length,
  );

  _ProviderPreview get _activeProvider {
    return _providers.firstWhere(
      (_ProviderPreview provider) => provider.id == _activeProviderId,
      orElse: () => _providers.first,
    );
  }

  _ProviderPreview? get _selectedProvider {
    final String? providerId = _providerIdForAccountType(
      _management.account.type,
    );
    if (providerId == null) {
      return null;
    }
    for (final _ProviderPreview provider in _providers) {
      if (provider.id == providerId) {
        return provider;
      }
    }
    return null;
  }

  _AccountPreview? get _selectedAccount {
    final _ProviderPreview? provider = _selectedProvider;
    if (provider == null) {
      return null;
    }
    for (final _AccountPreview account in provider.accounts) {
      if (account.loginType == _selectedLoginType &&
          account.sourceIndex == _selectedAccountIndex) {
        return account.copyWith(
          nickname: _management.account.nickname,
          avatarUrl: _management.account.cover,
        );
      }
    }
    return null;
  }

  void _activateProvider(String providerId) {
    if (_activeProviderId == providerId) {
      return;
    }
    setState(() {
      _activeProviderId = providerId;
    });
  }

  Future<void> _selectAccount(
    _ProviderPreview provider,
    _AccountPreview account,
  ) async {
    if (account.loginType == _selectedLoginType &&
        account.sourceIndex == _selectedAccountIndex) {
      return;
    }
    await _management.switchLogin(account.loginType, account.sourceIndex);
    if (!mounted) {
      return;
    }
    setState(() {
      _activeProviderId = provider.id;
    });
  }

  void _deleteAccount(_ProviderPreview provider, _AccountPreview account) {
    _management.deleteAccount(provider.loginType, account.sourceIndex);
    if (mounted) {
      setState(() {});
      final ScaffoldMessengerState? messenger =
          ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6FD19C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.accountInk,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  '删除成功',
                  style: TextStyle(
                    color: AppColors.accountInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            width: 156,
            backgroundColor: Colors.white,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.accountGlassOutline),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration switchDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final _ProviderPreview? selectedProvider = _selectedProvider;
    final _AccountPreview? selectedAccount = _selectedAccount;

    return DecoratedBox(
      key: const Key('account-page-backdrop'),
      decoration: const BoxDecoration(color: AppColors.background),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showStageDisc = constraints.maxWidth >= 700;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 44),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1275),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PageHeading(),
                    const SizedBox(height: 28),
                    if (selectedProvider != null && selectedAccount != null)
                      _ListeningStage(
                        account: selectedAccount,
                        provider: selectedProvider,
                        accountCount: _accountCount,
                        showRecordDisc: showStageDisc,
                      )
                    else
                      const _EmptyListeningStage(),
                    const SizedBox(height: 36),
                    _DirectoryHeading(accountCount: _accountCount),
                    const SizedBox(height: 16),
                    _ProviderRail(
                      providers: _providers,
                      activeProviderId: _activeProviderId,
                      onProviderSelected: _activateProvider,
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: switchDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.025),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: _AccountDirectory(
                        key: ValueKey<String>(_activeProvider.id),
                        provider: _activeProvider,
                        selectedLoginType: _selectedLoginType,
                        selectedAccountIndex: _selectedAccountIndex,
                        onAccountSelected: _selectAccount,
                        onAccountDeleted: _deleteAccount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    const Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账号管理',
          style: TextStyle(
            color: AppColors.accountInk,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '管理不同音乐服务中的聆听身份',
          style: TextStyle(color: AppColors.accountMutedInk, fontSize: 14),
        ),
      ],
    );
    final Widget addAccountButton = OutlinedButton.icon(
      key: const Key('add-account-button'),
      onPressed: () async {
        await showAccountLoginDialog(context);
      },
      icon: const Icon(BootstrapIcons.plus, size: 16),
      label: const Text('添加账号'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accountInk,
        backgroundColor: AppColors.accountDisabledFill,
        side: const BorderSide(color: AppColors.accountGlassOutline),
        minimumSize: const Size(116, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              addAccountButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: title),
            const SizedBox(width: 16),
            addAccountButton,
          ],
        );
      },
    );
  }
}

class _ListeningStage extends StatelessWidget {
  const _ListeningStage({
    required this.account,
    required this.provider,
    required this.accountCount,
    required this.showRecordDisc,
  });

  final _AccountPreview account;
  final _ProviderPreview provider;
  final int accountCount;
  final bool showRecordDisc;

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final Duration identityDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return AnimatedContainer(
      key: const Key('listening-stage'),
      duration: animationDuration,
      curve: Curves.easeOut,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            provider.stageColor,
            Color.lerp(provider.stageColor, Colors.black, 0.18)!,
          ],
        ),
        border: Border.all(color: AppColors.accountStageBorder),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: provider.stageColor.withValues(alpha: 0.24),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (showRecordDisc)
            Positioned(
              right: -32,
              top: -38,
              child: _RecordDisc(provider: provider),
            ),
          Padding(
            padding: EdgeInsets.only(right: showRecordDisc ? 190 : 0),
            child: Row(
              children: [
                _ProfileAvatar(
                  account: account,
                  provider: provider,
                  size: 92,
                  isStageAvatar: true,
                  stageColor: provider.stageColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: identityDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:
                        (
                          Widget? currentChild,
                          List<Widget> previousChildren,
                        ) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _ListeningIdentity(
                      key: ValueKey<String>(account.id),
                      account: account,
                      provider: provider,
                      accountCount: accountCount,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListeningStage extends StatelessWidget {
  const _EmptyListeningStage();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listening-stage'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.accountStageDefault,
        border: Border.all(color: AppColors.accountStageBorder),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '暂未登录',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '登录音乐服务后，当前账号会显示在这里。',
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ListeningIdentity extends StatelessWidget {
  const _ListeningIdentity({
    super.key,
    required this.account,
    required this.provider,
    required this.accountCount,
  });

  final _AccountPreview account;
  final _ProviderPreview provider;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '当前正在聆听',
          style: TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          account.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ServiceMark(provider: provider, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${provider.name} · 当前使用',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              BootstrapIcons.collection_play,
              color: Color(0xCCFFFFFF),
              size: 14,
            ),
            const SizedBox(width: 7),
            Text(
              '$accountCount 个已连接账号',
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecordDisc extends StatelessWidget {
  const _RecordDisc({required this.provider});

  final _ProviderPreview provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 270,
      child: DecoratedBox(
        key: const Key('record-disc'),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accountGlassBorder, width: 12),
          boxShadow: [
            BoxShadow(
              color: provider.stageColor.withValues(alpha: 0.28),
              blurRadius: 34,
              spreadRadius: 3,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final double diameter in [222, 182, 142])
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accountRecordGroove,
                    width: 1.5,
                  ),
                ),
              ),
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accountRecordCenter,
                shape: BoxShape.circle,
                border: Border.all(
                  color: provider.stageColor.withValues(alpha: 0.32),
                  width: 5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.accountShadow,
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: _ServiceMark(
                provider: provider,
                size: 38,
                color: provider.stageColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryHeading extends StatelessWidget {
  const _DirectoryHeading({required this.accountCount});

  final int accountCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '你的账号',
          style: TextStyle(
            color: AppColors.accountInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$accountCount 个已连接',
          style: const TextStyle(
            color: AppColors.accountMutedInk,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProviderRail extends StatelessWidget {
  const _ProviderRail({
    required this.providers,
    required this.activeProviderId,
    required this.onProviderSelected,
  });

  final List<_ProviderPreview> providers;
  final String activeProviderId;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider-rail-tray'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.accountGlass,
        border: Border.all(color: AppColors.accountGlassBorder),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.accountShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final _ProviderPreview provider in providers)
            _ProviderRailItem(
              provider: provider,
              isSelected: provider.id == activeProviderId,
              onTap: () => onProviderSelected(provider.id),
            ),
        ],
      ),
    );
  }
}

class _ProviderRailItem extends StatefulWidget {
  const _ProviderRailItem({
    required this.provider,
    required this.isSelected,
    required this.onTap,
  });

  final _ProviderPreview provider;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ProviderRailItem> createState() => _ProviderRailItemState();
}

class _ProviderRailItemState extends State<_ProviderRailItem> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = _isHovering
        ? AppColors.floating
        : widget.isSelected
        ? AppColors.accountSelection
        : AppColors.transparent;
    final Color foregroundColor = widget.isSelected
        ? AppColors.selectedText
        : AppColors.musicNameColor;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.provider.name,
      child: Focus(
        onFocusChange: (bool isFocused) {
          setState(() {
            _isFocused = isFocused;
          });
        },
        child: _AccountSwitchSurface(
          key: Key('provider-switch-item-${widget.provider.id}'),
          hoverRegionKey: Key('provider-hover-region-${widget.provider.id}'),
          isHovering: _isHovering,
          isSelected: widget.isSelected,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          backgroundColor: backgroundColor,
          borderColor: widget.isSelected
              ? AppColors.accountSelectionBorder
              : _isFocused
              ? AppColors.selectedText
              : AppColors.transparent,
          borderWidth: _isFocused && !widget.isSelected ? 2 : 1,
          onTap: widget.onTap,
          onEnter: () {
            if (!_isHovering) {
              setState(() {
                _isHovering = true;
              });
            }
          },
          onExit: () {
            if (_isHovering) {
              setState(() {
                _isHovering = false;
              });
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.provider.stageColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              _ServiceMark(
                provider: widget.provider,
                size: 18,
                color: foregroundColor,
              ),
              const SizedBox(width: 8),
              Text(
                widget.provider.name,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSwitchSurface extends StatelessWidget {
  const _AccountSwitchSurface({
    super.key,
    required this.hoverRegionKey,
    required this.isHovering,
    required this.isSelected,
    required this.height,
    required this.padding,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.onTap,
    required this.onEnter,
    required this.onExit,
    required this.child,
  });

  final Key hoverRegionKey;
  final bool isHovering;
  final bool isSelected;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback onTap;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: hoverRegionKey,
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration.zero,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AccountDirectory extends StatelessWidget {
  const _AccountDirectory({
    super.key,
    required this.provider,
    required this.selectedLoginType,
    required this.selectedAccountIndex,
    required this.onAccountSelected,
    required this.onAccountDeleted,
  });

  final _ProviderPreview provider;
  final int selectedLoginType;
  final int selectedAccountIndex;
  final void Function(_ProviderPreview provider, _AccountPreview account)
  onAccountSelected;
  final void Function(_ProviderPreview provider, _AccountPreview account)
  onAccountDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('account-directory'),
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                _ServiceMark(provider: provider, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accountInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.accountDivider,
          ),
          if (provider.accounts.isEmpty)
            const _EmptyProviderState()
          else
            for (int index = 0; index < provider.accounts.length; index++) ...[
              _AccountRow(
                account: provider.accounts[index],
                provider: provider,
                isSelected:
                    provider.accounts[index].loginType == selectedLoginType &&
                    provider.accounts[index].sourceIndex ==
                        selectedAccountIndex,
                onTap: () =>
                    onAccountSelected(provider, provider.accounts[index]),
                onDelete: () =>
                    onAccountDeleted(provider, provider.accounts[index]),
              ),
              if (index < provider.accounts.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 86,
                  endIndent: 22,
                  color: AppColors.accountDivider,
                ),
            ],
        ],
      ),
    );
  }
}

class _EmptyProviderState extends StatelessWidget {
  const _EmptyProviderState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Row(
        children: [
          Icon(
            BootstrapIcons.person_plus,
            color: AppColors.musicSingerColor,
            size: 18,
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '暂未添加账号',
                style: TextStyle(
                  color: AppColors.accountInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '登录后，账号会显示在这里。',
                style: TextStyle(
                  color: AppColors.accountMutedInk,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatefulWidget {
  const _AccountRow({
    required this.account,
    required this.provider,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final _AccountPreview account;
  final _ProviderPreview provider;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _isHovering = false;

  Future<void> _showDeleteConfirmation() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          key: const Key('account-delete-confirmation-dialog'),
          backgroundColor: AppColors.accountGlassStrong,
          surfaceTintColor: AppColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.accountGlassOutline),
          ),
          title: const Row(
            children: [
              Icon(
                BootstrapIcons.exclamation_circle,
                color: AppColors.likeIconColor,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                '删除账号',
                style: TextStyle(
                  color: AppColors.accountInk,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            '确定要删除 ${widget.provider.name} 中的 ${widget.account.nickname} 吗？',
            style: const TextStyle(
              color: AppColors.accountMutedInk,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirm-account-deletion-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.likeIconColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.onDelete();
                Navigator.of(context).pop();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant _AccountRow oldWidget) {
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

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label:
          '${widget.provider.name}，${widget.account.nickname}${widget.isSelected ? '，当前账号' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Semantics(
          container: true,
          child: _AccountSwitchSurface(
            key: Key('account-switch-item-${widget.account.id}'),
            hoverRegionKey: Key('account-hover-region-${widget.account.id}'),
            isHovering: _isHovering,
            isSelected: widget.isSelected,
            height: 76,
            padding: EdgeInsets.zero,
            backgroundColor: backgroundColor,
            borderColor: widget.isSelected
                ? AppColors.accountSelectionBorder
                : AppColors.transparent,
            borderWidth: 1,
            onTap: widget.onTap,
            onEnter: () {
              if (!widget.isSelected && !_isHovering) {
                setState(() {
                  _isHovering = true;
                });
              }
            },
            onExit: () {
              if (!widget.isSelected && _isHovering) {
                setState(() {
                  _isHovering = false;
                });
              }
            },
            child: Row(
              children: [
                const SizedBox(width: 16),
                _ProfileAvatar(
                  account: widget.account,
                  provider: widget.provider,
                  size: 40,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    widget.account.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isSelected
                          ? AppColors.selectedText
                          : AppColors.accountInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.isSelected)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        BootstrapIcons.check2,
                        color: AppColors.selectedText,
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Text(
                        '当前账号',
                        style: TextStyle(
                          color: AppColors.selectedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 4),
                IconButton(
                  key: Key('delete-account-button-${widget.account.id}'),
                  tooltip: '删除账号',
                  onPressed: () {
                    _showDeleteConfirmation();
                  },
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.likeIconColor,
                    hoverColor: Color(0x1AFF5F57),
                    minimumSize: const Size(36, 36),
                    maximumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(BootstrapIcons.trash3, size: 17),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.account,
    required this.provider,
    required this.size,
    this.isStageAvatar = false,
    this.stageColor,
  });

  final _AccountPreview account;
  final _ProviderPreview provider;
  final double size;
  final bool isStageAvatar;
  final Color? stageColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: account.avatarColor,
        shape: BoxShape.circle,
        border: isStageAvatar
            ? Border.all(color: Colors.white, width: 3)
            : null,
        boxShadow: isStageAvatar
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipOval(child: _avatarContent()),
    );
  }

  Widget _avatarContent() {
    if (account.avatarUrl.isNotEmpty) {
      return RemoteImage(
        account.avatarUrl,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
        },
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    if (provider.id == 'navidrome' && provider.asset != null) {
      return Padding(
        padding: EdgeInsets.all(size >= 80 ? 18 : 8),
        child: SvgPicture.asset(
          provider.asset!,
          key: isStageAvatar
              ? const Key('stage-avatar-service-navidrome')
              : null,
          fit: BoxFit.contain,
        ),
      );
    }
    return Center(
      child: Text(
        account.avatarLabel,
        style: TextStyle(
          color: isStageAvatar
              ? stageColor ?? AppColors.accountStageDefault
              : AppColors.accountStageDefault,
          fontSize: size >= 80 ? 25 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ServiceMark extends StatelessWidget {
  const _ServiceMark({required this.provider, required this.size, this.color});

  final _ProviderPreview provider;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (provider.asset == null) {
      return SizedBox.square(
        dimension: size,
        child: Icon(
          BootstrapIcons.music_note_beamed,
          size: size,
          color: color ?? AppColors.buttonIcon,
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        provider.asset!,
        fit: BoxFit.contain,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
  }
}

class _ProviderPreview {
  const _ProviderPreview({
    required this.id,
    required this.loginType,
    required this.name,
    required this.stageColor,
    required this.stageBorderColor,
    required this.accounts,
    this.asset,
  });

  final String id;
  final int loginType;
  final String name;
  final String? asset;
  final Color stageColor;
  final Color stageBorderColor;
  final List<_AccountPreview> accounts;
}

class _AccountPreview {
  const _AccountPreview({
    required this.id,
    required this.loginType,
    required this.sourceIndex,
    required this.nickname,
    required this.avatarLabel,
    required this.avatarUrl,
    required this.avatarColor,
  });

  final String id;
  final int loginType;
  final int sourceIndex;
  final String nickname;
  final String avatarLabel;
  final String avatarUrl;
  final Color avatarColor;

  _AccountPreview copyWith({String? nickname, String? avatarUrl}) {
    return _AccountPreview(
      id: id,
      loginType: loginType,
      sourceIndex: sourceIndex,
      nickname: nickname ?? this.nickname,
      avatarLabel: _avatarLabelFor(nickname ?? this.nickname),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarColor: avatarColor,
    );
  }

  static String _avatarLabelFor(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '音' : trimmed.substring(0, 1);
  }
}
