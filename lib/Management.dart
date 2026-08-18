import 'package:chocolate_music/FileManage.dart';
import 'package:chocolate_music/Cloud/KuGou.dart';
import 'package:chocolate_music/Cloud/Navidrome.dart';
import 'package:chocolate_music/Cloud/NetEaseCloud.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'package:chocolate_music/Type.dart';
import 'package:flutter/foundation.dart';

class Management extends ChangeNotifier {
  static final Management _instance = Management._internal();

  late FileManage fileManage = FileManage(); //文件管理类，负责读取和写入设置、账户数据、推荐列表数据等

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

  late List<Music> displayMusics = []; // 显示的音乐列表
  late List<Album> displayAlbums = []; // 显示的专辑列表

  late List<Music> displayListSearchMusic = []; // 显示的搜索音乐列表

  late Map<String, List<Music>> playlistMusics = {}; // 歌单id-歌曲列表
  late Map<String, List<Music>> albumMusic = {}; // 专辑id-歌曲列表
  late Map<String, List<Music>> singerMusic = {}; // 歌手id-歌曲列表
  late Map<String, List<Album>> singerAlbum = {}; // 歌手id-专辑列表

  late String displayLyric = ''; //当前显示的歌词
  // late List<LyricsMap> displayLyricList = [];    //当前显示的歌词列表

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

  factory Management() => _instance;

  init() async {
    await fileManage.init();

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

    this.setting.play = false;

    if (this.accountData.login[0] != -1){
      var status = await this.login();
      if (status) {
        this.updateAccount();
        this.recommendList = this.recommendListDate[this.accountData.login[0]];
        this.recommendList.music = [];
        await this.createrRecommend();

        if (this.setting.id != '') {
          // this.playMusicControl.play('pause');
          // this.getInitialPlaylist();
        }
      } else {
        this.initDisplay();
      }
    } else {
      print('未登录，无法加载账户信息');
      this.initDisplay();
    }

    updateAccount();
  }

  initDisplay(){
    this.accountData.login = [-1, -1];
    this.account = Account(cover: '', nickname: '', type: ''); ;
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
    );
    this.fileManage.writeSetting(setting);
  }

  switchLogin(int type, int index) async {
    print('$type  $index');
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
    if (this.accountData.login[0] == 0){
      this.cloud = KuGouCloud;
    }
    else if (this.accountData.login[0] == 1){
      this.cloud = NavidromeCloud;
    }
    else if (this.accountData.login[0] == 2){
      this.cloud = NavidromeCloud;
    }
    else {
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

  deleteAccount(int type, int index){
    if (this.accountData.login[0] == type && this.accountData.login[1] == index){
      this.accountData.login = [-1, -1];
      this.playlists = [];
      this.accountData.data[type].removeAt(index);
      this.closePlayMusic();
      this.updateAccountData();
      this.account = Account(cover: '', nickname: '', type: '');;
      this.recommendList = new RecommendList();
      this.updateRecommendListDate();
      print('已删除当前登录账户，已退出登录');
    } else {
      this.accountData.data[type].removeAt(index);
      if (this.accountData.login[0] == type && this.accountData.login[1] > index){
        this.accountData.login[1] -= 1;
        this.updateAccountData();
        print('已删除账户，已更新登录状态');
      } else {
        this.updateAccountData();
        print('已删除账户');
      }
    }
  }

  createrRecommend({type = 0}) async {
    //初始推荐列表
    if (type == 1) {
      this.recommendList = RecommendList();
    }

    // await Promise.all([
    // this.createrRecommendMusics(type),
    // this.createrRecommendSingers(type),
    // (this.accountData.login[0] === 2 ? this.createrRecommendAlbums(type) : this.createrRecommendPlaylists(type))
    // ])
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
    while (true) {
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

  closePlayMusic(){
    this.playMusicList = [];
    // this.playMusicControl.playMusicList = [];
    this.currentPlayMusicList = [];

    this.displayLyric = '';
    // this.displayLyricList = [];
    // this.musicProgress = 0;

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

    // this.playMusicControl.stop();

    this.updateSetting();
    this.searchKeyword = '';
    this.searchList = new RecommendList();
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
    // this.getPlayList()
    // this.playMusicControl.updateLoopMode()
  }

  updateAccountData() async {
    // 更新账户数据
    await this.fileManage.writeAccountData(this.accountData);
    print('账户数据更新成功');
  }

  updateRecommendListDate() async {
    // 更新推荐列表数据
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
    );

    init();
  }
}
