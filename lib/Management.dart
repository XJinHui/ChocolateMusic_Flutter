import 'package:chocolate_music/FileManage.dart';
import 'package:chocolate_music/PlayMusicControl.dart';
import 'package:chocolate_music/MusicManagement.dart';
import 'package:chocolate_music/Cloud/KuGou.dart';
import 'package:chocolate_music/Cloud/Navidrome.dart';
import 'package:chocolate_music/Cloud/NetEaseCloud.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'package:chocolate_music/Type.dart';
import 'package:flutter/foundation.dart';

class Management extends ChangeNotifier {
  static final Management _instance = Management._internal();

  late FileManage fileManage = FileManage(); //文件管理类，负责读取和写入设置、账户数据、推荐列表数据等
  late PlayMusicControl playMusicControl = PlayMusicControl(
    this,
  ); // 播放音乐控制类，负责播放音乐、获取歌词、获取歌曲信息等
  late MusicManagement musicManagement = MusicManagement(this); // 本地音乐管理

  String _selectedPage = 'RecommendPage';

  String get selectedPage => _selectedPage;

  set selectedPage(String value) {
    if (_selectedPage == value) {
      return; // 值没变就不通知，避免整棵树无意义重建
    }
    _selectedPage = value;
    notifyListeners(); // 通知所有监听者（含 Computer.dart 的 ListenableBuilder）
  }

  bool _lyricShow = false; // 歌词显示状态，默认为false，点击歌词按钮切换状态

  bool get lyricShow => _lyricShow;

  set lyricShow(bool value) {
    if (_lyricShow == value) {
      return; // 值没变就不通知，避免整棵树无意义重建
    }
    _lyricShow = value;
    notifyListeners(); // 通知所有监听者（含 Computer.dart 的 ListenableBuilder）
  }

  late Setting setting; // 设置数据，包含当前播放歌曲信息、播放状态、音量等
  late int logining = 0; // 登录状态，0正在登录，1登录成功，-1未登录

  late List<String> collectionList = []; // 收藏列表，存储已收藏的歌单/专辑/歌手id，登录后获取，退出登录后清空

  late Account account = Account(cover: '', nickname: '', type: ''); // 当前登录账户信息
  // late Account account = Account(cover: 'http://imge.kugou.com/kugouicon/165/20170105/20170105121000731994.jpg', nickname: '光珲', type: '');
  late AccountData accountData = AccountData(
    login: [-1, -1],
    data: [[], [], []],
  ); // 账户数据，包含登录状态和账户信息，登录状态为一个数组，第一位为登录类型，-1为未登录，0为酷狗音乐，1为网易云音乐，2为Navidrome，第二位为账户索引，根据登录类型在对应的账户列表中获取账户信息
  late List<Playlist> playlists = []; // 我的歌单列表

  late Object displayList; // 显示的列表，可以是Playlist、Album、Singer等类型
  late String displayListType; // 显示的列表类型，可以是Playlist、Album、Singer等类型

  late Music selectedMusic; // 当前选择、右键的音乐

  List<Music> _displayMusics = []; // 显示的音乐列表
  List<Album> _displayAlbums = []; // 显示的专辑列表

  List<Music> get displayMusics => _displayMusics;

  set displayMusics(List<Music> value) {
    _displayMusics = value;
    notifyListeners();
  }

  List<Album> get displayAlbums => _displayAlbums;

  set displayAlbums(List<Album> value) {
    _displayAlbums = value;
    notifyListeners();
  }

  late List<Music> displayListSearchMusic = []; // 显示的搜索音乐列表

  late Map<String, List<Music>> playlistMusics = {}; // 歌单id-歌曲列表
  late Map<String, List<Music>> albumMusic = {}; // 专辑id-歌曲列表
  late Map<String, List<Music>> singerMusic = {}; // 歌手id-歌曲列表
  late Map<String, List<Album>> singerAlbum = {}; // 歌手id-专辑列表
  late int playlistMusicVersion =
      0; // 新增：歌单歌曲列表版本号，每次更新歌单歌曲列表时自增1，组件根据版本号判断是否需要更新显示的歌曲列表

  late String displayLyric = ''; //当前显示的歌词
  late List<LyricsMap> displayLyricList = []; //当前显示的歌词列表

  late int musicProgress = 0; //歌曲播放进度（毫秒）
  // late String musicDisplayProgress = '00:00';    //歌曲播放进度（分:秒）
  late int musicDuration = 0; //歌曲总时长（毫秒）
  late int lyricTime = 0; //歌词时间戳（毫秒）
  late int lyricWordTime = 0; //歌词(逐字)时间戳（毫秒）
  late bool lyricType = false; //歌词类型，false为普通歌词，true为逐字歌词

  /// 播放进度专用通知器。
  ///
  /// 进度回调每几百毫秒就会触发一次。如果走 [refresh]（即 notifyListeners），
  /// 所有监听 Management 的页面——包括歌单页那几百行的列表——都会被重建，
  /// 播放时自然就卡。这里把进度拆成独立的 ValueNotifier，
  /// 只有真正需要进度的组件（播放进度条）订阅它，列表不受影响。
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  /// 歌词当前行索引通知器，-1 表示当前没有歌词行。
  ///
  /// 与 [progressNotifier] 同理：歌词行切换也属于高频状态，
  /// 不能走 [refresh]，否则整棵页面子树（含歌单列表）会跟着重建。
  final ValueNotifier<int> lyricLineNotifier = ValueNotifier<int>(-1);

  late List<Music> playMusicList = []; //音乐播放列表
  late List<Music> currentPlayMusicList =
      []; //音乐播放列表、加入播放列表时更新，切换歌曲时不更新，更新播放列表时根据当前播放歌曲id更新播放列表索引

  late RecommendList recommendList =
      RecommendList(); //推荐列表，包含歌曲、歌单、专辑、歌手等，根据登录账户获取，未登录时为默认推荐列表，登录后根据账户获取对应的推荐列表，存储在recommendListDate数组中，索引与登录账户类型对应，登录后从数组中获取对应的推荐列表，更新推荐列表时更新数组中对应的推荐列表
  late List<RecommendList> recommendListDate = [
    RecommendList(),
    RecommendList(),
    RecommendList(),
  ]; //推荐列表数据，包含歌曲、歌单、专辑、歌手等，根据登录账户获取，未登录时为默认推荐列表，登录后根据账户获取对应的推荐列表，存储在数组中，索引与登录账户类型对应，登录后从数组中获取对应的推荐列表，更新推荐列表时更新数组中对应的推荐列表

  late RecommendList searchList =
      RecommendList(); //搜索结果列表，包含歌曲、歌单、专辑、歌手等，根据搜索关键词获取，存储在searchList中，更新搜索结果列表时更新searchList
  late String searchKeyword = ''; //搜索关键词，用户输入的搜索关键词，更新搜索结果列表时根据搜索关键词获取对应的搜索结果列表

  late CloudService cloud;

  late KuGou KuGouCloud = KuGou(
    accountData: this.accountData,
    management: this,
  );
  late Neteasecloud NeteasecloudCloud = Neteasecloud(
    accountData: this.accountData,
    management: this,
  );
  late Navidrome NavidromeCloud = Navidrome(
    accountData: this.accountData,
    management: this,
  );
  late Map<String, String> qrCodes = {'KuGou': '', 'NetEaseCloud': ''};

  int _loginType = -1; // 登录状态，-1为未登录，0正在登陆，1为登录成功，2为登录失败

  int get loginType => _loginType;

  set loginType(int value) {
    if (_loginType == value) {
      return;
    }
    _loginType = value;
    notifyListeners();
  }

  /// 通知所有依赖 Management 的页面重新读取共享状态。
  ///
  /// Management 中的模型目前仍是可变对象（例如 setting.play、
  /// recommendList.music），这些嵌套字段不会经过 Dart 的 setter，
  /// 因此所有完成状态写入的入口都应调用这个方法。
  void refresh() {
    notifyListeners();
  }

  factory Management() => _instance;

  Future<void> init() async {
    await fileManage.init();
    await playMusicControl;

    if (await fileManage.checkFile('data/setting.json')) {
      // await this.readSetting();
      this.setting = await this.fileManage.readSetting();
    } else {
      await this.fileManage.writeSetting(this.setting);
    }

    if (await fileManage.checkFile('data/accountData.json')) {
      this.accountData = await this.fileManage.readAccountData();
    } else {
      await this.fileManage.writeAccountData(this.accountData);
    }

    if (await fileManage.checkFile('data/recommendListDate.json')) {
      this.recommendListDate = await this.fileManage.readRecommendListDate();
    } else {
      await this.fileManage.writeRecommendListDate(this.recommendListDate);
    }

    await musicManagement.init();

    this.setting.play = false;

    if (this.accountData.login[0] != -1) {
      var status = await this.login();
      if (status) {
        this.updateAccount();
        this.recommendList = this.recommendListDate[this.accountData.login[0]];
        this.recommendList.music = [];
        await this.createrRecommend();

        if (this.setting.id != '') {
          this.playMusicControl.play(type: 'pause');
          this.getInitialPlaylist();
        }
      } else {
        this.initDisplay();
      }
    } else {
      print('未登录，无法加载账户信息');
      this.initDisplay();
    }

    updateAccount();
    refresh();
  }

  void initDisplay() {
    this.accountData.login = [-1, -1];
    this.account = Account(cover: '', nickname: '', type: '');
    ;
    var setting = Setting(
      name: '',
      singer: '',
      singerId: '',
      album: '',
      albumId: '',
      time: '00:00',
      cover: '',
      like: false,
      id: '',
      playType: 0,
      volume: 100,
      volumeType: true,
      play: false,
      playlistId: '',
      playlistType: 0,
      qualityTier: 0,
      downloadQualityTier: 0,
      downloadPath: this.setting.downloadPath,
    );
    this.setting = setting;
    this.fileManage.writeSetting(this.setting);
    refresh();
  }

  switchLogin(int type, int index) async {
    if (type < 0 ||
        type >= this.accountData.data.length ||
        index < 0 ||
        index >= this.accountData.data[type].length) {
      print('登录账号索引异常，无法切换');
      return;
    }

    if (this.accountData.login[0] == type &&
        this.accountData.login[1] == index) {
      print('已登录该账户，无需切换');
      return;
    }

    if (type == this.accountData.login[0]) {
    } else if (type == 0) {
      this.cloud = KuGouCloud;
    } else if (type == 1) {
      this.cloud = NeteasecloudCloud;
    } else if (type == 2) {
      this.cloud = NavidromeCloud;
    } else {
      print('登录类型异常，无法切换账户');
      return;
    }

    this.accountData.login = [type, index];
    this.playlists = [];
    this.closePlayMusic();
    var status = await this.cloud.login();

    if (status) {
      this.updateAccount();
      this.updateAccountData();
      this.createrRecommend(type: 1);
      print('登录成功');
    } else {
      this.initDisplay();
      print('登录失败');
    }
    updateAccount();
  }

  login() async {
    if (this.accountData.login[0] == 0) {
      this.cloud = KuGouCloud;
    } else if (this.accountData.login[0] == 1) {
      this.cloud = NeteasecloudCloud;
    } else if (this.accountData.login[0] == 2) {
      this.cloud = NavidromeCloud;
    } else {
      print('登录类型异常，无法切换账户');
      return false;
    }
    return await this.cloud.login();
    // this.isShowSettings = false
  }

  startLogin() {
    this.loginType = 0;
    this.KuGouCloud.qrCodeType = 0;
    this.NeteasecloudCloud.qrCodeType = 0;
  }

  /// 放弃进行中的登录尝试，退出登录界面时调用。
  ///
  /// 二维码登录会在 [KuGouCloud] / [NeteasecloudCloud] 里各起一个每 2 秒
  /// 轮询 `/login/qr/check` 的循环，二者都以 `loginType != 0` 判断本次尝试
  /// 是否已被放弃。退出登录界面时不复位状态，这些请求就会一直发下去。
  ///
  /// 只有仍在进行中(0)的尝试才复位；已经成功(1)或失败(2)的不动，
  /// 免得把结果覆盖掉。
  cancelLogin() {
    if (this.loginType != 0) {
      return;
    }
    this.loginType = -1;
  }

  updateAccount() {
    if (this.accountData.login[0] != -1) {
      if (this.accountData.login[0] == 0) {
        this.account = Account(
          cover: this.accountData.data[0][this.accountData.login[1]].cover,
          nickname:
              this.accountData.data[0][this.accountData.login[1]].nickname,
          type: '酷狗音乐',
        );
      } else if (this.accountData.login[0] == 1) {
        this.account = Account(
          cover: this.accountData.data[1][this.accountData.login[1]].cover,
          nickname:
              this.accountData.data[1][this.accountData.login[1]].nickname,
          type: '网易云',
        );
      } else if (this.accountData.login[0] == 2) {
        this.account = Account(
          cover: '',
          nickname: this.accountData.data[2][this.accountData.login[1]].u,
          type: 'Navidrome',
        );
      } else {
        print('登录状态异常，无法加载账户信息');
      }
    }

    notifyListeners();
  }

  deleteAccount(int type, int index) {
    if (this.accountData.login[0] == type &&
        this.accountData.login[1] == index) {
      this.accountData.login = [-1, -1];
      this.playlists = [];
      this.accountData.data[type].removeAt(index);
      this.closePlayMusic();
      this.updateAccountData();
      this.account = Account(cover: '', nickname: '', type: '');
      ;
      this.recommendList = new RecommendList();
      this.updateRecommendListDate();
      print('已删除当前登录账户，已退出登录');
    } else {
      this.accountData.data[type].removeAt(index);
      if (this.accountData.login[0] == type &&
          this.accountData.login[1] > index) {
        this.accountData.login[1] -= 1;
        this.updateAccountData();
        print('已删除账户，已更新登录状态');
      } else {
        this.updateAccountData();
        print('已删除账户');
      }
    }
    refresh();
  }

  createrRecommend({type = 0}) async {
    //初始推荐列表
    if (type == 1) {
      this.recommendList = RecommendList();
    }

    await Future.wait([
      createrRecommendMusics(type: type),
      createrRecommendSingers(type: type),
      accountData.login[0] == 2
          ? createrRecommendAlbums(type: type)
          : createrRecommendPlaylists(type: type),
    ]);

    refresh();
  }

  Future<void> createrRecommendMusics({type = 0}) async {
    //生成推荐音乐列表
    this.recommendList.music = await this.cloud.getRecommendMusics(12);
    // print('生成推荐歌曲列表: ${this.recommendList.music}');

    if (this.setting.playlistId == '' && this.recommendList.music.length > 0) {
      if (this.playMusicList.length == 0) {
        this.playMusicList = List.from(this.recommendList.music);
        this.currentPlayMusicList = List.from(this.recommendList.music);
      } else {
        for (var i in this.recommendList.music) {
          if (!this.playMusicList.any((item) => item.id == i.id)) {
            this.playMusicList.add(i);
          }
          if (!this.currentPlayMusicList.any((item) => item.id == i.id)) {
            this.currentPlayMusicList.add(i);
          }
        }
      }

      this.getPlayList();
    }
  }

  Future<void> createrRecommendSingers({type = 0}) async {
    if (this.accountData.login[0] == -1) {
      return;
    }
    //生成推荐歌手列表
    if (type == 1 ||
        this.recommendListDate[this.accountData.login[0]].singer.length == 0) {
      this.recommendList.singer = await this.cloud.getRecommendSingers(12);
      // print('生成推荐歌手列表: ${this.recommendList.singer}');

      this.updateRecommendListDate();
    } else {
      this.recommendList.singer =
          this.recommendListDate[this.accountData.login[0]].singer;
      // print('读取推荐歌手列表: ${this.recommendList.singer}');
    }
  }

  Future<void> createrRecommendAlbums({type = 0}) async {
    if (this.accountData.login[0] == -1) {
      return;
    }
    //生成推荐专辑列表
    if (type == 1 ||
        this.recommendListDate[this.accountData.login[0]].album.length == 0) {
      this.recommendList.album = await this.cloud.getRecommendAlbum(12);
      // print('生成推荐专辑列表: ${this.recommendList.album}');

      this.updateRecommendListDate();
    } else {
      this.recommendList.album =
          this.recommendListDate[this.accountData.login[0]].album;
      // print('读取推荐专辑列表: ${this.recommendList.album}');
    }
  }

  Future<void> createrRecommendPlaylists({type = 0}) async {
    if (this.accountData.login[0] == -1) {
      return;
    }
    //生成推荐歌单列表
    if (type == 1 ||
        this.recommendListDate[this.accountData.login[0]].playlist.length ==
            0) {
      this.recommendList.playlist = await this.cloud.getRecommendPlaylists(12);
      // print('生成推荐歌单列表: ${this.recommendList.playlist}');
      this.updateRecommendListDate();
    } else {
      this.recommendList.playlist =
          this.recommendListDate[this.accountData.login[0]].playlist;
      // print('读取推荐歌单列表: ${this.recommendList.playlist}');
    }
  }

  playMusic(Music music) {
    var playListType = this.setting.playlistType;
    var playListId = this.setting.playlistId;

    this.updataPlayMusicSettings(music);
    print('当前播放列表类型: ${playListType} 当前播放列表id: ${playListId}');

    if (playListType != this.setting.playlistType ||
        playListId != this.setting.playlistId) {
      this.playMusicList = this.displayMusics;

      this.getPlayList();
    }
    this.playMusicControl.play();
  }

  switchMusic(Music music) {
    this.updataPlayMusicSettings(
      music,
      playlistType: this.setting.playlistType,
    );
    this.playMusicControl.play();
  }

  updataPlayMusicSettings(Music music, {playlistType = -1}) {
    var time = formatTime(music.time);

    this.setting.name = music.name;
    this.setting.singer = music.singer;
    this.setting.singerId = music.singerId;
    this.setting.album = music.album;
    this.setting.albumId = music.albumId;
    this.setting.time = time;
    this.setting.cover = music.cover;
    this.setting.id = music.id;

    if (playlistType != -1) {
      this.setting.playlistType = playlistType;
    } else {
      if (this.displayList is Playlist) {
        this.setting.playlistId = (this.displayList as Playlist).listId;
        this.setting.playlistType = 0;
      } else if (this.displayList is Album) {
        this.setting.playlistId = (this.displayList as Album).albumId;
        this.setting.playlistType = 1;
      } else if (this.displayList is Singer) {
        this.setting.playlistId = (this.displayList as Singer).singerId;
        this.setting.playlistType = 2;
      }
    }

    this.updateSetting();
  }

  getInitialPlaylist() async {
    if (this.setting.playlistId == '') {
      print('当前没有播放列表');
      return;
    }

    if (this.setting.playlistType == 0) {
      this.playMusicList = await this.cloud.getPlaylistMusic(
        this.setting.playlistId,
      );

      if (this.playMusicList.length != 0) {
        this.playlistMusics[this.setting.playlistId] = this.playMusicList;
      }
    } else if (this.setting.playlistType == 1) {
      this.playMusicList = await this.cloud.getAlbumMusic(
        this.setting.playlistId,
      );

      if (this.playMusicList.length != 0) {
        this.albumMusic[this.setting.playlistId] = this.playMusicList;
      }
    } else if (this.setting.playlistType == 2) {
      this.playMusicList = await this.cloud.getSingerMusic(
        this.setting.playlistId,
      );

      if (this.playMusicList.length != 0) {
        this.singerMusic[this.setting.playlistId] = this.playMusicList;
      }
    } else {
      this.playMusicList = List.of(this.recommendList.music);
    }

    this.getPlayList();
  }

  getPlayList() {
    if (this.setting.playType != 1) {
      this.playMusicControl.playMusicList = List.from(this.playMusicList);
    } else {
      var shuffledList = List<Music>.from(this.playMusicList);
      shuffledList.shuffle();
      this.playMusicControl.playMusicList = shuffledList;
    }
    this.currentPlayMusicList = List<Music>.from(this.playMusicList);
  }

  getPlaylistMusic(Playlist playlist) async {
    // 更新歌单音乐
    List<Music> displayMusics = await this.cloud.getPlaylistMusic(
      playlist.listId,
    );

    this.playlistMusics[playlist.listId] = displayMusics;

    if (displayList == playlist) {
      this.displayMusics = displayMusics;
    }

    return displayMusics;
  }

  getDisplayPlaylist(Playlist playlist, {bool type = false}) async {
    // 获取歌单音乐
    if (this.playlistMusics.containsKey(playlist.listId)) {
      var displayMusics = this.playlistMusics[playlist.listId];

      this.displayMusics = displayMusics as List<Music>;

      return displayMusics;
    }

    var displayMusics = await this.cloud.getPlaylistMusic(playlist.listId);

    if (displayMusics.isNotEmpty) {
      this.playlistMusics[playlist.listId] = displayMusics;
    } else {
      displayMusics = <Music>[];
    }

    if (this.displayListType == 'Playlist' &&
        (this.displayList as Playlist).listId == playlist.listId) {
      this.displayMusics = displayMusics;
    }

    return displayMusics;
  }

  getDisplayAlbum(Album album) async {
    // 获取专辑音乐
    if (this.albumMusic.containsKey(album.albumId)) {
      var displayMusics = this.albumMusic[album.albumId];

      this.displayMusics = displayMusics as List<Music>;

      return displayMusics;
    }

    var displayMusics = await this.cloud.getAlbumMusic(album.albumId);

    if (displayMusics.isNotEmpty) {
      this.albumMusic[album.albumId] = displayMusics;
    } else {
      displayMusics = <Music>[];
    }

    if (this.displayListType == 'Album' &&
        (this.displayList as Album).albumId == album.albumId) {
      this.displayMusics = displayMusics;
    }

    return displayMusics;
  }

  getDisplaySinger(Singer singer) async {
    // 获取歌手音乐
    if (this.singerMusic.containsKey(singer.singerId)) {
      List<Music> displayMusics = this.singerMusic[singer.singerId] ?? [];
      List<Album> displayAlbums = this.singerAlbum[singer.singerId] ?? [];

      this.displayMusics = displayMusics;
      this.displayAlbums = displayAlbums;

      return {'musics': displayMusics, 'albums': displayAlbums};
    }

    // 注意：CloudService 里 getSingerMusic / getSingerAlbum 没有声明返回类型，
    // 静态类型是 Future<dynamic>。如果写成
    //   List<List<dynamic>> data = await Future.wait([...]);
    // 编译器会在元素上插入 Future<dynamic> -> Future<List<dynamic>> 的隐式向下转型，
    // 运行时直接抛 "type 'Future<dynamic>' is not a subtype of type 'Future<List<dynamic>>'"。
    // 所以这里显式写成 Future.wait<dynamic>，取到结果后再逐个转型。
    final List<dynamic> data = await Future.wait<dynamic>([
      this.cloud.getSingerMusic(singer.singerId),
      this.cloud.getSingerAlbum(singer.singerId),
    ]);

    if (data.length < 2) {
      print('获取歌手信息失败');

      if (this.displayListType == 'Singer' &&
          this.displayList is Singer &&
          (this.displayList as Singer).singerId == singer.singerId) {
        this.displayMusics = [];
        this.displayAlbums = [];
      }

      return {'musics': [], 'albums': []};
    }

    List<Music> displayMusics = data[0] is List
        ? List<Music>.from(data[0] as List)
        : <Music>[];
    List<Album> displayAlbums = data[1] is List
        ? List<Album>.from(data[1] as List)
        : <Album>[];

    this.singerMusic[singer.singerId] = displayMusics;
    this.singerAlbum[singer.singerId] = displayAlbums;

    if (this.displayListType == 'Singer' &&
        this.displayList is Singer &&
        (this.displayList as Singer).singerId == singer.singerId) {
      this.displayMusics = displayMusics;
      this.displayAlbums = displayAlbums;
    }

    return {'musics': displayMusics, 'albums': displayAlbums};
  }

  addNextMusic(Music music) {
    this.currentPlayMusicList = this.currentPlayMusicList
        .where((item) => item.id != music.id)
        .toList();
    this.playMusicControl.playMusicList = this.playMusicControl.playMusicList
        .where((item) => item.id != music.id)
        .toList();

    int index = this.currentPlayMusicList.indexWhere(
      (item) => item.id == this.setting.id,
    );

    if (index == -1) {
      this.currentPlayMusicList.insert(0, music);
      this.playMusicControl.playMusicList.insert(0, music);
    } else {
      this.currentPlayMusicList.insert(index + 1, music);
      int playIndex = this.playMusicControl.playMusicList.indexWhere(
        (item) => item.id == this.setting.id,
      );
      if (playIndex != -1) {
        this.playMusicControl.playMusicList.insert(playIndex + 1, music);
      } else {
        this.playMusicControl.playMusicList.insert(0, music);
      }
    }
  }

  Future<bool> like(String musicId) async {
    if (this.cloud.collectionList.contains(musicId)) {
      return await this.deleteMusicFromPlaylist(
        this.cloud.collectionListId,
        musicId,
      );
    } else {
      return await this.addMusicToPlaylist(
        this.cloud.collectionListId,
        musicId,
      );
    }
  }

  search(String keyword) async {
    if (keyword != this.searchKeyword) {
      this.searchKeyword = keyword;
      this.searchList = new RecommendList();
      await this.cloud.search(keyword);
      refresh();
    }
  }

  listSearch(String keyword) {
    this.displayListSearchMusic = [];
    if (this.displayMusics.length == 0) {
      return;
    }

    for (var i = 0; i < this.displayMusics.length; i++) {
      final music = this.displayMusics[i];
      if (music.name.contains(keyword) ||
          music.singer.contains(keyword) ||
          music.album.contains(keyword)) {
        this.displayListSearchMusic.add(music);
      }
    }
  }

  Future<bool> createPlaylist(String name) async {
    bool status = await this.cloud.createPlaylist(name);

    if (status) {
      refresh();
    }

    return status;
  }

  Future<bool> deletePlaylist(String listId) async {
    bool status = await this.cloud.deletePlaylist(listId);

    if (status) {
      refresh();
    }

    return status;
  }

  Future<bool> addMusicToPlaylist(String listId, String musicId) async {
    if (await this.cloud.addMusicToPlaylist(listId, musicId) as bool) {
      if (this.setting.playlistId == listId && this.setting.playlistType == 0) {
        var index = this.currentPlayMusicList.indexWhere(
          (item) => item.id == musicId,
        );

        if (index == -1) {
          this.cloud.getMusicsDetails([musicId]).then((List<Music> musics) {
            if (musics.length > 0 &&
                this.setting.playlistId == listId &&
                this.setting.playlistType == 0) {
              this.currentPlayMusicList.insert(0, musics[0]);
              this.playMusicControl.playMusicList.insert(0, musics[0]);
            }
          });
        }
      }

      if (this.playlistMusics.containsKey(listId)) {
        List<Music> musics = this.playlistMusics[listId]!;
        if (!musics.any((music) => music.id == musicId)) {
          this.cloud.getMusicsDetails([musicId]).then((List<Music> details) {
            if (details.length > 0 && this.playlistMusics.containsKey(listId)) {
              this.playlistMusics[listId]!.insert(0, details[0]);
              this.playlistMusicVersion++; // 触发监听
            }
          });
        }
      }

      refresh();

      return true;
    }
    return false;
  }

  deleteMusicFromPlaylist(String listId, String musicId) async {
    if (await this.cloud.deleteMusicFromPlaylist(listId, musicId) as bool) {
      if (this.playlistMusics.containsKey(listId)) {
        this.playlistMusics[listId]?.removeWhere((item) => item.id == musicId);
        this.playlistMusicVersion++; // 触发监听
      }

      refresh();

      return true;
    }
    return false;
  }

  getVerificationCode(String mobile, String url, String type) async {
    if (type == 'KuGou') {
      // this.cloud = KuGou(accountData: this.accountData, management: this);
      KuGouCloud.getVerificationCode(mobile, url);
    } else if (type == 'NetEaseCloud') {
      // this.cloud = Neteasecloud(accountData: accountData, management: this);
      NeteasecloudCloud.getVerificationCode(mobile, url);
    } else {
      return;
    }
    // this.cloud.getVerificationCode(mobile, url);
  }

  getQrCode() async {
    List results = await Future.wait([
      KuGouCloud.getQrCode(''),
      NeteasecloudCloud.getQrCode(''),
    ]);

    this.qrCodes = {'KuGou': results[0], 'NetEaseCloud': results[1]};
    notifyListeners();

    loginByQrCode();
  }

  loginByQrCode() async {
    // loginType 一旦不为 0，说明这次尝试已被放弃（退出了登录界面）或已由
    // 其它方式结束，本地轮询也该停下，否则每开一次登录界面就会残留一个
    // 永远转下去的循环。
    while (this.loginType == 0) {
      await Future.delayed(const Duration(milliseconds: 10));
      if (this.KuGouCloud.qrCodeType == 1 ||
          this.NeteasecloudCloud.qrCodeType == 1) {
        this.loginType = 1;
        updateAccountData();
        updateAccount();
        createrRecommend(type: 1);
        print('二维码登录成功');
        break;
      }
    }
  }

  loginByMobile(
    String mobile,
    String url,
    String VerificationCode,
    String type,
  ) async {
    var status;

    if (type == 'KuGou') {
      // this.cloud = KuGou(accountData: this.accountData, management: this);
      status = await KuGouCloud.loginByMobile(mobile, url, VerificationCode);
    } else if (type == 'NetEaseCloud') {
      // this.cloud = Neteasecloud(accountData: accountData, management: this);
      status = await NeteasecloudCloud.loginByMobile(
        mobile,
        url,
        VerificationCode,
      );
    } else {
      return false;
    }

    if (status) {
      this.loginType = 1;
      updateAccountData();
      updateAccount();
      createrRecommend(type: 1);
      this.cloud = type == 'KuGou' ? KuGouCloud : NeteasecloudCloud;
      print('手机号登录成功');
    } else {
      this.loginType = 2;
      print('手机号登录失败');
    }
  }

  loginByNavidrome(
    String username,
    String url,
    String password,
    String name,
  ) async {
    var status;

    status = await NavidromeCloud.addLogin(username, url, password, name);

    if (status) {
      this.loginType = 1;
      updateAccountData();
      updateAccount();
      createrRecommend(type: 1);
      this.cloud = NavidromeCloud;
      print('Navidrome登录成功');
    } else {
      this.loginType = 2;
      print('Navidrome登录失败');
    }
  }

  closePlayMusic() {
    this.playMusicList = [];
    this.playMusicControl.playMusicList = [];
    this.currentPlayMusicList = [];

    this.displayLyric = '';
    this.displayLyricList = [];
    this.musicProgress = 0;
    this.progressNotifier.value = 0;

    this.setting.name = '';
    this.setting.singer = '';
    this.setting.singerId = '';
    this.setting.album = '';
    this.setting.albumId = '';
    this.setting.time = '00:00';
    this.setting.cover = '';
    this.setting.id = '';
    this.setting.playlistId = '';
    this.setting.playlistType = 0;
    this.setting.play = false;

    this.playMusicControl.stop();

    this.updateSetting();
    this.searchKeyword = '';
    this.searchList = new RecommendList();
    refresh();
  }

  judgeLoginStatus() {
    if (this.accountData.login[0] != -1 && this.accountData.login[1] != -1) {
      this.loginType = 1;
    } else {
      this.loginType = -1;
    }
  }

  updatePlayType() {
    if (this.setting.playType == 0) {
      this.setting.playType = 1;
    } else if (this.setting.playType == 1) {
      this.setting.playType = 2;
    } else if (this.setting.playType == 2) {
      this.setting.playType = 0;
    }
    this.updateSetting();
    refresh();
    this.getPlayList();
    // this.playMusicControl.updateLoopMode();
  }

  updateAccountData() async {
    // 更新账户数据
    refresh();
    await this.fileManage.writeAccountData(this.accountData);
    print('账户数据更新成功');
  }

  updateRecommendListDate() async {
    // 更新推荐列表数据
    refresh();
    if (this.accountData.login[0] == -1) {
      print('未登录，无法更新推荐列表数据');
      return;
    }
    this.recommendListDate[this.accountData.login[0]] = this.recommendList;
    print('${this.recommendListDate}');
    await this.fileManage.writeRecommendListDate(this.recommendListDate);
    print('推荐列表数据更新成功');
  }

  updateSetting() async {
    // 更新设置
    refresh();
    await this.fileManage.writeSetting(this.setting);
    print('设置更新成功');
  }

  Management._internal() {
    this.setting = Setting(
      name: '',
      singer: '',
      singerId: '',
      album: '',
      albumId: '',
      time: '00:00',
      cover: '',
      like: false,
      id: '',
      playType: 0,
      volume: 100,
      volumeType: true,
      play: false,
      playlistId: '',
      playlistType: 0,
      qualityTier: 0,
      downloadQualityTier: 0,
      downloadPath: '',
    );

    init();
  }
}

String formatTime(int ms) {
  // 毫秒转秒
  final totalSeconds = ms ~/ 1000;

  // 计算分和秒
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  // 补零格式化
  final minStr = minutes.toString().padLeft(2, '0');
  final secStr = seconds.toString().padLeft(2, '0');

  return '$minStr:$secStr';
}
