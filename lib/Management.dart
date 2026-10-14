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

  bool _playlistShow = false; // 播放列表侧边栏显示状态，点击播放栏的播放列表按钮打开，点击侧边栏以外的区域关闭

  bool get playlistShow => _playlistShow;

  set playlistShow(bool value) {
    if (_playlistShow == value) {
      return; // 值没变就不通知，避免整棵树无意义重建
    }
    _playlistShow = value;
    notifyListeners(); // 通知所有监听者（含 Computer.dart 的 ListenableBuilder）
  }

  late Setting setting; // 设置数据，包含音量、播放模式、音质、下载路径等
  late PlaybackState playbackState; // 播放状态数据，包含当前播放歌曲信息、播放状态、播放列表等
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

  /// 歌单内搜索的当前关键词，空字符串表示没有在搜索。
  ///
  /// 搜索态需要独立的标志位：只看 [displayListSearchMusic] 是否为空的话，
  /// 「搜了但没命中」和「没在搜索」两种情况分不开，前者会回退显示整个歌单。
  String _displayListSearchKeyword = '';

  /// 当前是否处于歌单内搜索状态。
  bool get isListSearching => _displayListSearchKeyword.isNotEmpty;

  /// 显示列表（歌单/专辑/歌手）的切换计数，每次 [clearListSearch] 自增。
  ///
  /// 搜索结果 [displayListSearchMusic] 是挂在单例上的全局状态，换列表时
  /// 必须丢弃，搜索框也要据此清掉上一轮输入。用计数而不是比较列表 id，
  /// 是为了让「重复点开同一个歌单」也能正确复位。
  int _displayListVersion = 0;

  int get displayListVersion => _displayListVersion;

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

  /// 登录尝试的世代号，每开一轮登录（[startLogin]）自增。
  ///
  /// 二维码轮询是每 2 秒一次的长跑循环，跨得过一次「关掉登录界面又打开」。
  /// 只看 [loginType] 认不出它属于哪一轮：关界面时它被复位成 -1，可下一轮
  /// 一开又变回 0，上一轮的循环醒来会以为自己还活着，跟本轮的新循环一起轮询
  /// 同一个二维码 key —— 扫一次把账号加两遍。世代号让每个循环认得出自己的轮次。
  int _loginAttempt = 0;

  int get loginAttempt => _loginAttempt;

  /// 通知所有依赖 Management 的页面重新读取共享状态。
  ///
  /// Management 中的模型目前仍是可变对象（例如 playbackState.play、
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

    if (await fileManage.checkFile('data/playback-state.json')) {
      // await this.readPlaybackState();
      this.playbackState = await this.fileManage.readPlaybackState();
    } else {
      await this.fileManage.writePlaybackState(this.playbackState);
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

    this.playbackState.play = false;

    if (this.accountData.login[0] != -1) {
      var status = await this.login();
      if (status) {
        this.updateAccount();
        this.recommendList = this.recommendListDate[this.accountData.login[0]];
        this.recommendList.music = [];
        await this.createrRecommend();

        if (this.playbackState.id != '') {
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
    this.playbackState = PlaybackState(
      name: '',
      singer: '',
      singerId: '',
      album: '',
      albumId: '',
      time: '00:00',
      cover: '',
      like: false,
      id: '',
      play: false,
      playlistId: '',
      playlistType: 0,
    );
    this.fileManage.writePlaybackState(this.playbackState);
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
    // 先推进世代号：上一轮残留的轮询循环看到它变了就会退出，
    // 否则下面把 loginType 复位成 0 会让它们以为自己还活着。
    _loginAttempt++;
    this.loginType = 0;
    this.KuGouCloud.qrCodeType = 0;
    this.NeteasecloudCloud.qrCodeType = 0;
  }

  /// 放弃进行中的登录尝试，退出登录界面时调用。
  ///
  /// 二维码登录会在 [KuGouCloud] / [NeteasecloudCloud] 里各起一个每 2 秒
  /// 轮询 `/login/qr/check` 的循环，它们以 `loginType != 0` 或世代号变了
  /// 判断本次尝试是否已被放弃。退出登录界面时不复位状态，这些请求就会一直发下去。
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

    if (this.playbackState.playlistId == '' &&
        this.recommendList.music.length > 0) {
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
    var playListType = this.playbackState.playlistType;
    var playListId = this.playbackState.playlistId;

    this.updataPlayMusicSettings(music);
    print('当前播放列表类型: ${playListType} 当前播放列表id: ${playListId}');

    if (playListType != this.playbackState.playlistType ||
        playListId != this.playbackState.playlistId) {
      this.playMusicList = this.displayMusics;

      this.getPlayList();
    }
    this.playMusicControl.play();
  }

  switchMusic(Music music) {
    this.updataPlayMusicSettings(
      music,
      playlistType: this.playbackState.playlistType,
    );
    this.playMusicControl.play();
  }

  updataPlayMusicSettings(Music music, {playlistType = -1}) {
    var time = formatTime(music.time);

    this.playbackState.name = music.name;
    this.playbackState.singer = music.singer;
    this.playbackState.singerId = music.singerId;
    this.playbackState.album = music.album;
    this.playbackState.albumId = music.albumId;
    this.playbackState.time = time;
    this.playbackState.cover = music.cover;
    this.playbackState.id = music.id;

    if (playlistType != -1) {
      this.playbackState.playlistType = playlistType;
    } else {
      if (this.displayList is Playlist) {
        this.playbackState.playlistId = (this.displayList as Playlist).listId;
        this.playbackState.playlistType = 0;
      } else if (this.displayList is Album) {
        this.playbackState.playlistId = (this.displayList as Album).albumId;
        this.playbackState.playlistType = 1;
      } else if (this.displayList is Singer) {
        this.playbackState.playlistId = (this.displayList as Singer).singerId;
        this.playbackState.playlistType = 2;
      }
    }

    this.updatePlaybackState();
  }

  getInitialPlaylist() async {
    if (this.playbackState.playlistId == '') {
      print('当前没有播放列表');
      return;
    }

    if (this.playbackState.playlistType == 0) {
      if (this.playbackState.playlistId == 'Download') {
        return;
      } else {
        this.playMusicList = await this.cloud.getPlaylistMusic(
          this.playbackState.playlistId,
        );
      }

      if (this.playMusicList.length != 0) {
        this.playlistMusics[this.playbackState.playlistId] = this.playMusicList;
      }
    } else if (this.playbackState.playlistType == 1) {
      this.playMusicList = await this.cloud.getAlbumMusic(
        this.playbackState.playlistId,
      );

      if (this.playMusicList.length != 0) {
        this.albumMusic[this.playbackState.playlistId] = this.playMusicList;
      }
    } else if (this.playbackState.playlistType == 2) {
      this.playMusicList = await this.cloud.getSingerMusic(
        this.playbackState.playlistId,
      );

      if (this.playMusicList.length != 0) {
        this.singerMusic[this.playbackState.playlistId] = this.playMusicList;
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
    // 换了歌单，上一个歌单的搜索结果作废
    clearListSearch();

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
    // 换了专辑，上一个列表的搜索结果作废
    clearListSearch();

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
    // 换了歌手，上一个列表的搜索结果作废
    clearListSearch();

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
      (item) => item.id == this.playbackState.id,
    );

    if (index == -1) {
      this.currentPlayMusicList.insert(0, music);
      this.playMusicControl.playMusicList.insert(0, music);
    } else {
      this.currentPlayMusicList.insert(index + 1, music);
      int playIndex = this.playMusicControl.playMusicList.indexWhere(
        (item) => item.id == this.playbackState.id,
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

  /// 进入一个新的显示列表（歌单/专辑/歌手）时调用。
  ///
  /// 搜索结果 [displayListSearchMusic] 不随页面切换自动失效：不清掉的话，
  /// 新歌单会继续渲染上一个歌单的搜索结果，而且搜索态一旦打开就再也没有
  /// 关闭路径——它只由 [isListSearching] 背后的关键词决定。
  void clearListSearch() {
    _displayListVersion++;
    _displayListSearchKeyword = '';
    displayListSearchMusic = [];
    notifyListeners();
  }

  listSearch(String keyword) {
    this._displayListSearchKeyword = keyword;
    this.displayListSearchMusic = [];

    // 关键词为空表示退出搜索，列表回到完整歌单。
    // 这里不能继续往下走：contains('') 恒为 true，会把整个歌单当成「全部命中」。
    if (keyword.isEmpty) {
      refresh();
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

    refresh();
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
      if (this.playbackState.playlistId == listId &&
          this.playbackState.playlistType == 0) {
        var index = this.currentPlayMusicList.indexWhere(
          (item) => item.id == musicId,
        );

        if (index == -1) {
          this.cloud.getMusicsDetails([musicId]).then((List<Music> musics) {
            if (musics.length > 0 &&
                this.playbackState.playlistId == listId &&
                this.playbackState.playlistType == 0) {
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

      // 搜索结果列表和 displayMusics 是两个 List 实例（元素是同一批 Music），
      // 不一起移除的话，开着搜索删歌时那一行会留在屏幕上。
      this.displayListSearchMusic.removeWhere((item) => item.id == musicId);

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

  /// 重新取一张二维码，供登录界面的「刷新二维码」按钮调用。
  ///
  /// 必须先 [startLogin]：二维码取回后云服务会另起一轮每 2 秒的扫码轮询，
  /// 而上一轮的循环还挂在旧二维码的 key 上（key 是共享字段，取新码时被覆盖）。
  /// 世代号一变，旧循环醒来就会自行退出；只重新取码的话，新旧两个循环会一起
  /// 轮询同一个 key，扫一次把账号加两遍。
  Future<void> refreshQrCode() async {
    startLogin();
    await getQrCode();
  }

  loginByQrCode() async {
    // 本循环只服务开启它时的这一轮登录。世代号变了（关掉登录界面又打开了一轮）
    // 或 loginType 不再为 0（这轮已被放弃或已出结果），都该停下，否则每开一次
    // 登录界面就会残留一个永远转下去的循环。
    final int attempt = _loginAttempt;
    bool stillThisAttempt() => _loginAttempt == attempt && this.loginType == 0;

    while (stillThisAttempt()) {
      await Future.delayed(const Duration(milliseconds: 10));
      // 延时期间这一轮可能已经结束，醒来要重新认一次，
      // 否则会把新一轮的扫码结果当成本轮的。
      if (!stillThisAttempt()) {
        return;
      }

      if (this.KuGouCloud.qrCodeType == 1 ||
          this.NeteasecloudCloud.qrCodeType == 1) {
        this.loginType = 1;
        updateAccountData();
        updateAccount();
        createrRecommend(type: 1);
        print('二维码登录成功');
        return;
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

    this.playbackState.name = '';
    this.playbackState.singer = '';
    this.playbackState.singerId = '';
    this.playbackState.album = '';
    this.playbackState.albumId = '';
    this.playbackState.time = '00:00';
    this.playbackState.cover = '';
    this.playbackState.id = '';
    this.playbackState.playlistId = '';
    this.playbackState.playlistType = 0;
    this.playbackState.play = false;

    this.playMusicControl.stop();

    this.updatePlaybackState();
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

  /// 应用新的下载目录：先把本地音乐库切到新目录，成功后再写入设置。
  ///
  /// [path] 传空串表示恢复默认目录（可执行文件同级的 Music 文件夹）。
  /// 目录不可用时返回 false，设置和音乐库都保持原样，避免设置里记着一个
  /// 实际用不了的路径。
  Future<bool> applyDownloadPath(String path) async {
    if (!await this.musicManagement.applyDownloadDir(path)) {
      return false;
    }

    this.setting.downloadPath = path;
    await this.updateSetting();
    return true;
  }

  updatePlaybackState() async {
    // 更新播放状态
    refresh();
    await this.fileManage.writePlaybackState(this.playbackState);
    print('播放状态更新成功');
  }

  Management._internal() {
    this.setting = Setting(
      playType: 0,
      volume: 100,
      volumeType: true,
      qualityTier: 0,
      downloadQualityTier: 0,
      downloadPath: '',
    );

    this.playbackState = PlaybackState(
      name: '',
      singer: '',
      singerId: '',
      album: '',
      albumId: '',
      time: '00:00',
      cover: '',
      like: false,
      id: '',
      play: false,
      playlistId: '',
      playlistType: 0,
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
