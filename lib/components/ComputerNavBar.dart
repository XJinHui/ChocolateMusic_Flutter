import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';

class ChocolateNavBar extends StatefulWidget {
  final selectedIndex;
  final Function(String) onDestinationSelected; // 添加回调函数参数

  const ChocolateNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<ChocolateNavBar> createState() => _ChocolateNavBarState();
}

class _ChocolateNavBarState extends State<ChocolateNavBar> {
  @override
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

  List<Playlist> playlists = [
    Playlist(name: '周杰伦', listId: '1', cover: 'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg', audioCount: 5),
    Playlist(name: '林俊杰', listId: '2', cover: 'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg', audioCount: 5),
  ];

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

          for (int i = 0; i < navItems.length; i++)
            Column(
              children: [
                NavItem(
                  icon: navItems[i]['icon'],
                  selectedIcon: navItems[i]['selectedIcon'],
                  title: navItems[i]['title'],
                  isSelected: widget.selectedIndex == navItems[i]['pageId'],
                  onTap: () =>
                      widget.onDestinationSelected(navItems[i]['pageId']),
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
              itemCount: playlists.length,
              separatorBuilder: (context, index) {
                // 返回一个表示间隙的 Widget
                // 例如，一个固定高度的 SizedBox 或者带有颜色的 Container
                return SizedBox(height: 5); // 这里设置你想要的间隙高度
                // 或者使用 Container 添加带颜色的分割线
                // return Container(height: 1, color: Colors.grey.shade300);
              },
              itemBuilder: (context, index) {
                return playlistItem(
                  playlist: playlists[index],
                  isSelected: widget.selectedIndex == playlists[index].listId,
                  onTap: () => widget.onDestinationSelected(playlists[index].listId),
                );
              },
            ),
          ),
        ],
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
          padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 15), // 和边框的间距
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
