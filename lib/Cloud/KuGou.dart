import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'dart:math';

class KuGou implements CloudService{
  late AccountData accountData;
  late Management management;

  late String token;
  late KugouData userData;

  late List<Playlist> playlist = [];
  late Map<String, String> playlist_to_id = {};
  late List<String> collectionList = [];
  late String collectionListId = '';
  late String mainUrl = '';
  late Map<String, String> params = {'token': '', 'userid': '', 'dfid': ''};

  late String key = '';

  late int qrCodeType = -1; // 二维码登陆状态，-1为未登录，0正在登陆，1为登录成功，2为登录失败

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://120.77.173.68:4000",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  KuGou({required this.accountData, required this.management});

  getDfid() async {
    // var url = '${this.mainUrl}/register/dev';

    try {
      // var AxiosResponse response = await axios.get(url)
      // var response = await dio.get(url);
      final response = await KuGou.dio.get("/register/dev");

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print("获取dfid失败");
        return "";
      }

      final dfid = response.data["data"]["dfid"] as String;

      print("获取dfid成功: $dfid");
      return dfid;
    } on DioException catch (e) {
      print("getDfid 异常: ${e.message}");
      return "";
    } catch (e) {
      print("getDfid 未知异常: $e");
      return "";
    }
  }

  login() async {
    this.mainUrl = this.accountData.data[0][this.accountData.login[1]].url;
    this.userData = this.accountData.data[0][this.accountData.login[1]];
    this.params = {
      'token': this.userData.token,
      'userid': this.userData.userid,
      'dfid': this.userData.dfid != ''
          ? this.userData.dfid
          : await this.getDfid(),
    };

    int currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (this.userData.t_expire_time < currentSeconds) {
      // token 已过期
      // this.playlistManagement.logining = 2

      return;
    }

    try {
      // let url = this.mainUrl
      // let response: AxiosResponse = await axios.get(url)
      //
      // Kugou.dio.options.baseUrl = this.mainUrl;
      final response = await KuGou.dio.get('');
      if (response.statusCode != 200) {
        print('登录状态检查失败: ${response.data}');
        // this.playlistManagement.logining = 2

        return;
      }

      print('登录状态检查响应: ${response.data}');
      await this.getData();
      // this.playlistManagement.logining = 1
      // this.playlistManagement.isShowSettings = false
    } catch (error) {
      print('login 异常: ${error}');
      // this.playlistManagement.logining = 2

      return;
    }

    this.refreshToken();
  }

  updateAccountData() async {
    this.mainUrl = this.accountData.data[0][this.accountData.login[1]].url;
    this.userData = this.accountData.data[0][this.accountData.login[1]];
    this.params = {
      'token': this.userData.token,
      'userid': this.userData.userid,
      'dfid': this.userData.dfid != ''
          ? this.userData.dfid
          : await this.getDfid(),
    };
    // Kugou.dio.options.baseUrl = this.mainUrl;
  }

  updateAccountLogin(String mainUrl, int index) async {
    // let userData = this.accountData.data[0][this.accountData.login[1]]
    // let params: Params = {
    //   token: userData.token,
    //   userid: userData.userid,
    //   dfid: userData.dfid ? userData.dfid : await this.getDfid()
    // }
    //
    // try {
    //   let url = `${mainUrl}/user/detail`
    // let response: AxiosResponse = await axios.get(url, {
    // params: params
    // })
    //
    // if (response.status !== 200 || response.data.status !== 1) {
    // console.log('登录状态检查失败:', response.data)
    //
    // return false
    // }
    //
    // console.log('登录状态检查响应:', JSON.stringify(response.data))
    // this.accountData.data[0][index].url = mainUrl
    // return true
    // } catch (error) {
    // console.error('updateAccountLogin 异常:', error)
    //
    // return false
    // }
  }

  getVerificationCode(String mobile, String mainUrl) async {
    print('获取验证码: mobile=$mobile, mainUrl=$mainUrl');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await KuGou.dio.get(
      '/captcha/sent?mobile=${mobile}&timestamp=${timestamp}',
    );
    if (response.statusCode != 200 || response.data["status"] != 1) {
      print('获取验证码失败');
    }
  }

  getQrCode(String mainUrl) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await KuGou.dio.get(
        '/login/qr/key?timestamp=${timestamp}',
      );

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取二维码失败: ${response.data}');
        return '';
      }

      this.key = response.data['data']['qrcode'];

      var qrcodeImg = response.data['data']['qrcode_img'];

      // print(qrcodeImg);

      loginByQrCode('');

      return qrcodeImg;
    } catch (error) {
      print('getQrCode 异常: ${error}');
      return '';
    }
  }

  loginByMobile(String mobile, String mainUrl, String code) async {
    print('正在登录...');

    try {
      final response = await KuGou.dio.get(
        '/login/cellphone?mobile=${mobile}&code=${code}',
      );

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('登录失败');
        return false;
      }

      print('登录响应: ${response.data}');
      
      if (response.data['data'].containsKey('info_list') &&
          response.data['data']['info_list'] != null) {
        print(jsonEncode(response.data));
        print('暂无支持多账号登录');
        return false;
      }

      var data = response.data['data'];
      print('登录成功: ${data}');
      // this.mainUrl = mainUrl
      var dfid = await this.getDfid();
      this.userData = KugouData(
        token: data['token'] ?? '',
        userid: data['userid'].toString() ?? '',
        t_expire_time: data['t_expire_time'].toInt(),   // 注意：如果 data 里也是 int
        cover: response.data['data']['pic'],       // 根据你原先的写法
        nickname: data['nickname'] ?? '',
        dfid: dfid,
        url: this.mainUrl,
      );
      print('用户数据: ${this.userData}');

      var list = this.accountData.data[0];
      list.add(this.userData);
      var num = list.length - 1;            // 添加后的索引（即原来的长度）
      this.accountData.data[0][num] = this.userData;

      print('${this.accountData}');
      this.accountData.login = [0, num];

      this.token = this.userData.token;
      this.mainUrl = mainUrl;
      this.params = {
        'token': this.userData.token,
        'userid': this.userData.userid,
        'dfid': dfid
      };

      // await this.login(1)
      await this.getData();

      return true;
    } catch (error) {
    // console.error('loginByMobile 异常:', error)
      print('loginByMobile 异常: ${error}');
      return false;
    }
  }

  loginByQrCode(String mainUrl) async {
    var timestamp;
    var n = 0;
    var response;

    while (n != 4) {
      if (this.management.loginType != 0) {
        return false;
      }

      timestamp = DateTime.now().millisecondsSinceEpoch;
      response = await KuGou.dio.get(
        '/login/qr/check?key=${this.key}&timestamp=${timestamp}',
      );

      print(response.data);

      n = response.data['data']['status'];

      if (n==0){
        this.qrCodeType = 2;
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  
    // this.mainUrl = mainUrl
    var data = response.data['data'];
    print('登录成功: ${data}');
    var dfid = await this.getDfid();
    this.userData = KugouData(
      token: data['token'] ?? '',
      userid: data['userid'].toString() ?? '',
      t_expire_time: 0,
      cover: response.data['data']['pic'],
      nickname: data['nickname'] ?? '',
      dfid: dfid,
      url: this.mainUrl
    );

    this.params = {
      'token': this.userData.token,
      'userid': this.userData.userid,
      'dfid': dfid
    };

    await this.refreshToken();
    // this.mainUrl = mainUrl
    print('登录成功${this.userData}');

    var list = this.accountData.data[0];
    list.add(this.userData);
    var num = list.length - 1;            // 添加后的索引（即原来的长度）
    this.accountData.data[0][num] = this.userData;

    print('${this.accountData}');
    this.accountData.login = [0, num];

    this.token = this.userData.token;
    // this.mainUrl = mainUrl

    // await this.login(1)
    await this.getData();

    this.qrCodeType = 1;

    return true;
  }

  refreshToken() async {}

  Future<void> getVip() async {}

  getVip8() async {}

  getData() async {
    await Future.wait([
      getPlaylist(),
      getVip(),
    ]);
    this.getCollectionList();
  }

  getCollectionList() async {}

  Future<void> getPlaylist() async {}

  getPlaylistMusic(String listId) async {}

  getSingerMusic(String singerId) async {}

  getAlbumMusic(String albumId) async {}

  getSingerAlbum(String singerId) async {}

  getRecommendMusics(int num) async {}

  getRecommendSingers(int num) async {}

  getRecommendPlaylists(int num) async {}

  getRecommendAlbum(int num) async {}

  search(String keyword) async {}

  getMusicUrl(String musicId, {String bitrate = '128'}) async {}

  getAlbumAudioId(List<String> albumAudioIds) async {}

  getMusicsDetails(List<String> musicIds) async {}

  getSingerDetails(String singerId) async {}

  getAlbumDetails(String albumId) async {}

  getPlaylistDetails(String listId) async {}

  getLyric(String musicId) async {}

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {
    var qualityGrade = ['128', '320', 'flac'];
    var url = await this.getMusicUrl(musicId, bitrate: qualityGrade[quality]);
    return url;
  }

  createPlaylist(String name) async {}

  deletePlaylist(String listId) async {}

  addMusicToPlaylist(String listId, String musicId) async {}

  deleteMusicFromPlaylist(String listId, String musicId) async {}

  getMusiInPlaylistFileid(String listId, String musicId) async {}

  processLyric(String lrcContent) {}

  getCover(String coverUrl, {String size = '500'}) {
    String url = coverUrl;
    url = url.replaceFirst('{size}', size);
    url = url.replaceFirst('/240/', '/$size/');
    return url;
  }

  shuffleArray(List<String> ids) {
    final result = ids.toList();
    final random = Random();

    for (int i = result.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result;
  }
}
