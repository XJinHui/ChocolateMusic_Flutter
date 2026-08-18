import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/AccountLoginDialog.dart';
import 'package:chocolate_music/pages/computer/SettingsPage.dart';

class ChocolateNavBar extends StatefulWidget {
  // final selectedPage;
  final Function(String) onDestinationSelected; // 添加回调函数参数

  const ChocolateNavBar({
    Key? key,
    // required this.selectedPage,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<ChocolateNavBar> createState() => _ChocolateNavBarState();
}

class _ChocolateNavBarState extends State<ChocolateNavBar> {
  @override
  late String selectedIndex = 'RecommendPage';
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
          // SizedBox(height: 10),
          // Text(
          //   'Chocolate',
          //   style: TextStyle(
          //     fontSize: 20,
          //     fontWeight: FontWeight.bold,
          //     fontStyle: FontStyle.italic,
          //     color: AppColors.appName,
          //   ),
          // ),
          // Text(
          //   'Music',
          //   style: TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     fontStyle: FontStyle.italic,
          //     color: AppColors.appName,
          //   ),
          // ),
          // // Text('音乐', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.appName)),
          // SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // if (management.account.type != '') {
              if ( management.accountData.data.any((accounts) => accounts.isNotEmpty) ) {
                selectedIndex = 'AccountPage';
                widget.onDestinationSelected('AccountPage');
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
                  isSelected: selectedIndex == navItems[i]['pageId'],
                  onTap: () {
                    selectedIndex = navItems[i]['pageId'];
                    widget.onDestinationSelected(navItems[i]['pageId']);
                    if (navItems[i]['pageId'] == 'LikedPage') {
                      Management().displayList = Playlist(
                        name: '我喜欢',
                        listId: 'starred',
                        cover: '',
                        audioCount: 0,
                      );
                      Management().displayListType = 'Playlist';
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
              Icon(Icons.add, size: 25, color: AppColors.buttonIcon),
              SizedBox(width: 5),
            ],
          ),

          SizedBox(height: 10),

          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              // 让 ListView 在 Column 中按内容高度显示（配合 Expanded 使用）
              // itemCount: cardList.length,
              itemCount: management.playlists.length,
              separatorBuilder: (context, index) {
                // 返回一个表示间隙的 Widget
                // 例如，一个固定高度的 SizedBox 或者带有颜色的 Container
                return SizedBox(height: 5); // 这里设置你想要的间隙高度
                // 或者使用 Container 添加带颜色的分割线
                // return Container(height: 1, color: Colors.grey.shade300);
              },
              itemBuilder: (context, index) {
                return playlistItem(
                  playlist: management.playlists[index],
                  isSelected:
                      selectedIndex == management.playlists[index].listId,
                  onTap: () {
                    selectedIndex = management.playlists[index].listId;
                    widget.onDestinationSelected('PlaylistPage');
                    Management().displayList = management.playlists[index];
                    Management().displayListType = 'Playlist';
                  },
                );
              },
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40), // 根据需要设置圆角大小
                    child: Image.network(
                      // widget.cover,
                      management.account.cover,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
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
                          management.account.type == '酷狗音乐' ? 'assets/images/KuGouConcept.svg' :
                          management.account.type == '网易云' ? 'assets/images/NetEaseCloud.svg' :
                          'assets/images/Navidrome.svg',
                          width: 40,
                          height: 40,
                        );
                      },
                    ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8), // 根据需要设置圆角大小
                child: Image.network(
                  widget.playlist.cover,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
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
