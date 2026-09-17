import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/AccountLoginDialog.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/pages/computer/SettingsPage.dart';
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/components/CreatePlaylistDialog.dart';

class ChocolateNavBar extends StatefulWidget {
  // final selectedPage;
  // final Function(String) onDestinationSelected; // 添加回调函数参数

  const ChocolateNavBar({
    Key? key,
    // required this.selectedPage,
    // required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<ChocolateNavBar> createState() => _ChocolateNavBarState();
}

class _ChocolateNavBarState extends State<ChocolateNavBar> {
  @override
  late Management management = Management();

  List navItems = [
    {
      'icon': BootstrapIcons.house_door,
      'selectedIcon': BootstrapIcons.house_door_fill,
      'title': '推荐',
      'pageId': 'RecommendPage',
    },
    {
      'icon': BootstrapIcons.heart,
      'selectedIcon': BootstrapIcons.heart_fill,
      'title': '我喜欢',
      'pageId': 'LikedPage',
    },
    {
      'icon': BootstrapIcons.clock,
      'selectedIcon': BootstrapIcons.clock_fill,
      'title': '最近播放',
      'pageId': 'RecentPage',
    },
    {
      'icon': BootstrapIcons.arrow_down_square,
      'selectedIcon': BootstrapIcons.arrow_down_square_fill,
      'title': '本地下载',
      'pageId': 'DownloadPage',
    },
  ];

  bool isAccountHovering = false;

  String get _collectionListId {
    if (management.accountData.login[0] == -1) {
      return '';
    }

    // CloudService does not expose provider-specific collection metadata.
    // Read it from the active provider while keeping the navbar safe before
    // the first login initializes Management.cloud.
    try {
      final dynamic cloud = management.cloud;
      final dynamic collectionListId = cloud.collectionListId;
      return collectionListId is String ? collectionListId : '';
    } catch (_) {
      return '';
    }
  }

  List<Playlist> get _sidebarPlaylists {
    final String collectionListId = _collectionListId;
    return management.playlists
        .where(
          (playlist) =>
              collectionListId.isEmpty || playlist.listId != collectionListId,
        )
        .toList(growable: false);
  }

  Playlist get _likedPlaylist {
    final String collectionListId = _collectionListId;
    for (final Playlist playlist in management.playlists) {
      if (collectionListId.isNotEmpty && playlist.listId == collectionListId) {
        return playlist;
      }
    }

    return Playlist(
      name: '我喜欢',
      listId: collectionListId.isEmpty ? 'starred' : collectionListId,
      cover: '',
      audioCount: 0,
    );
  }

  Future<void> _createPlaylist() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreatePlaylistDialog(
        onConfirm: (String name) async {
          final bool success = await management.createPlaylist(name);
          if (!mounted) return;

          showMusicToast(
            context,
            message: success ? '创建歌单《$name》成功' : '创建歌单《$name》失败',
            success: success,
          );

          if (success) Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: EdgeInsets.all(10), // 和边框的间距
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15), // 圆角
      ),
      // padding: EdgeInsets.all(10),
      // color: Colors.deepPurple[50],
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              // if (management.account.type != '') {
              if (management.accountData.data.any(
                (accounts) => accounts.isNotEmpty,
              )) {
                // selectedIndex = 'AccountPage';
                // widget.onDestinationSelected('AccountPage');
                Management().selectedPage = 'AccountPage';
              } else {
                unawaited(
                  showAccountLoginDialog(context).whenComplete(() {
                    management.judgeLoginStatus();
                    if (mounted) {
                      setState(() {});
                    }
                  }),
                );
              }
            },
            child: AccountDisplay(),
          ),

          SizedBox(height: 10),

          for (int i = 0; i < navItems.length; i++)
            Column(
              children: [
                NavItem(
                  icon: navItems[i]['icon'],
                  selectedIcon: navItems[i]['selectedIcon'],
                  title: navItems[i]['title'],
                  isSelected:
                      Management().selectedPage == navItems[i]['pageId'],
                  onTap: () {
                    // selectedIndex = navItems[i]['pageId'];
                    // widget.onDestinationSelected(navItems[i]['pageId']);
                    Management().selectedPage = navItems[i]['pageId'];
                    if (navItems[i]['pageId'] == 'LikedPage') {
                      Management().displayList = _likedPlaylist;
                      Management().displayListType = 'Playlist';

                      Management().displayMusics = [];
                      Management().displayAlbums = [];
                      Management().getDisplayPlaylist(_likedPlaylist);

                      Management().refresh();
                    }
                  },
                ),
                if (i != navItems.length - 1) const SizedBox(height: 5),
              ],
            ),

          SizedBox(height: 40),

          Row(
            children: [
              SizedBox(width: 5),
              Text(
                '我的歌单',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.appName,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(child: SizedBox()),

              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // 打开创建歌单窗口
                    unawaited(_createPlaylist());
                  },
                  child: Icon(Icons.add, size: 25, color: AppColors.buttonIcon),
                ),
              ),

              SizedBox(width: 5),
            ],
          ),

          SizedBox(height: 10),

          Expanded(
            child: EdgeFadeMask(
              child: ListView.separated(
                shrinkWrap: true,
                // 让 ListView 在 Column 中按内容高度显示（配合 Expanded 使用）
                // itemCount: cardList.length,
                itemCount: _sidebarPlaylists.length,
                separatorBuilder: (context, index) {
                  // 返回一个表示间隙的 Widget
                  // 例如，一个固定高度的 SizedBox 或者带有颜色的 Container
                  return SizedBox(height: 5); // 这里设置你想要的间隙高度
                  // 或者使用 Container 添加带颜色的分割线
                  // return Container(height: 1, color: Colors.grey.shade300);
                },
                itemBuilder: (context, index) {
                  final Playlist playlist = _sidebarPlaylists[index];
                  return playlistItem(
                    playlist: playlist,
                    isSelected:
                        Management().selectedPage == 'PlaylistPage' &&
                        Management().displayListType == 'Playlist' &&
                        Management().displayList == playlist,
                    onTap: () {
                      // selectedIndex = playlist.listId;
                      // widget.onDestinationSelected('PlaylistPage');
                      Management().selectedPage = 'PlaylistPage';
                      Management().displayList = playlist;
                      Management().displayListType = 'Playlist';

                      Management().displayMusics = [];
                      Management().displayAlbums = [];
                      Management().getDisplayPlaylist(playlist);

                      Management().refresh();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountDisplay extends StatefulWidget {
  // final Account account;

  // const AccountDisplay({Key? key, required this.account}) : super(key: key);

  @override
  State<AccountDisplay> createState() => _AccountDisplayState();
}

class _AccountDisplayState extends State<AccountDisplay> {
  late bool isAccountHovering = false;
  late Management management = Management();

  @override
  void initState() {
    super.initState();
    management.addListener(_updateAccountDisplay);
  }

  @override
  void dispose() {
    management.removeListener(_updateAccountDisplay);
    super.dispose();
  }

  void _updateAccountDisplay() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isAccountHovering = true; // 鼠标进入，更新状态
        });
      },
      onExit: (_) {
        setState(() {
          isAccountHovering = false; // 鼠标离开，恢复状态
        });
      },
      child: management.account.type != ''
          ? Container(
              padding: EdgeInsets.all(10), // 和边框的间距
              decoration: BoxDecoration(
                color: isAccountHovering
                    ? AppColors.loginButtonColor
                    : AppColors.panel,
                borderRadius: BorderRadius.circular(20), // 圆角
              ),
              child: Row(
                children: [
                  RemoteImage(
                    management.account.cover,
                    headers: const {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                    },
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    borderRadius: 40,
                    // 加载失败时，errorBuilder 会被调用
                    errorBuilder: (context, error, stackTrace) {
                      // 返回你的本地图片
                      // return Image.asset(
                      //   'assets/images/app_photo.png',
                      //   width: 40,
                      //   height: 40,
                      //   fit: BoxFit.cover,
                      // );
                      return SvgPicture.asset(
                        management.account.type == '酷狗音乐'
                            ? 'assets/images/KuGouConcept.svg'
                            : management.account.type == '网易云'
                            ? 'assets/images/NetEaseCloud.svg'
                            : 'assets/images/Navidrome.svg',
                        width: 40,
                        height: 40,
                      );
                    },
                  ),

                  SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      // mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                      crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
                      children: [
                        Text(
                          management.account.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.musicNameColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          '来自 ${management.account.type}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.musicSingerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Container(
              alignment: Alignment.center,
              // ✅ 一行搞定
              height: 60,
              width: double.infinity,
              padding: EdgeInsets.all(10),
              // 和边框的间距
              decoration: BoxDecoration(
                color: isAccountHovering
                    ? AppColors.loginButtonColor
                    : AppColors.panel,
                borderRadius: BorderRadius.circular(20), // 圆角
              ),
              child: Text(
                '未登录',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.musicNameColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}

class NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final bool isSelected;
  final Function() onTap;

  const NavItem({
    Key? key,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  @override
  bool isHovering = false;

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, // 点击时调用回调函数
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            isHovering = true; // 鼠标进入，更新状态
          });
        },
        onExit: (_) {
          setState(() {
            isHovering = false; // 鼠标离开，恢复状态
          });
        },
        child: Container(
          padding: EdgeInsets.all(10), // 和边框的间距
          // width: 190,
          height: 50,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.selected
                : isHovering
                ? AppColors.floating
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(13.5), // 圆角
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                // widget.selectedIcon,
                size: 20,
                color: widget.isSelected
                    ? AppColors.selectedText
                    : AppColors.normalText,
              ),

              SizedBox(width: 10),

              Text(
                widget.title,
                style: TextStyle(
                  color: widget.isSelected
                      ? AppColors.selectedText
                      : AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class playlistItem extends StatefulWidget {
  // final String name;
  // final String cover;
  final bool isSelected;
  final Playlist playlist;
  final Function() onTap;

  const playlistItem({
    Key? key,
    // required this.name,
    // required this.cover,
    required this.isSelected,
    required this.playlist,
    required this.onTap,
  }) : super(key: key);

  @override
  State<playlistItem> createState() => _playlistItemState();
}

class _playlistItemState extends State<playlistItem> {
  @override
  bool isHovering = false;

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, // 点击时调用回调函数
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            isHovering = true; // 鼠标进入，更新状态
          });
        },
        onExit: (_) {
          setState(() {
            isHovering = false; // 鼠标离开，恢复状态
          });
        },
        child: Container(
          padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 15),
          // 和边框的间距
          // width: 190,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.selected
                : isHovering
                ? AppColors.floating
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(14), // 圆角
          ),
          child: Row(
            children: [
              RemoteImage(
                widget.playlist.cover,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                },
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                borderRadius: 8,
                boxShadow: kImageBoxShadow,
                // 加载失败时，errorBuilder 会被调用
                errorBuilder: (context, error, stackTrace) {
                  // 返回你的本地图片
                  return Image.asset(
                    'assets/images/app_photo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  );
                },
              ),

              SizedBox(width: 10),

              Text(
                widget.playlist.name,
                style: TextStyle(
                  color: widget.isSelected
                      ? AppColors.selectedText
                      : AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
