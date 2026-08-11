import 'package:dio/dio.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'package:chocolate_music/Management.dart';
import 'dart:math';

class Neteasecloud implements CloudService {
  late AccountData accountData;
  late Management management;

  late String cookies = '';
  late String vipCookies = '';
  late NetEaseCloudData userData;

  late List<Playlist> playlist = [];
  late List<String> collectionList = [];
  late String collectionListId = '';
  late String mainUrl = '';

  late String key = '';

  late int qrCodeType = -1; // 二维码登陆状态，-1为未登录，0正在登陆，1为登录成功，2为登录失败

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://120.77.173.68:3000",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Neteasecloud({required this.accountData, required this.management});

  login() async {
    this.cookies = this.accountData.data[1][this.accountData.login[1]].cookies;
    this.mainUrl = this.accountData.data[1][this.accountData.login[1]].url;
    this.userData = this.accountData.data[1][this.accountData.login[1]];

    // if (type == 0) {
    // let url = `${this.mainUrl}/login/status`
    try {
      var response = await Neteasecloud.dio.get(
        '/login/status',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
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

    if (this.accountData.data[1][this.accountData.login[1]].loginType == 1) {
      this.refreshToken();
    }
  }

  updateAccountData() async {
    this.cookies = this.accountData.data[1][this.accountData.login[1]].cookies;
    this.mainUrl = this.accountData.data[1][this.accountData.login[1]].url;
    this.userData = this.accountData.data[1][this.accountData.login[1]];
  }

  updateAccountLogin(String mainUrl, int index) async {}

  getVerificationCode(String mobile, String mainUrl) async {
    print('获取验证码: mobile=$mobile, mainUrl=$mainUrl');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await Neteasecloud.dio.get(
      '/captcha/sent?phone=${mobile}&timestamp=${timestamp}',
    );
    if (response.statusCode != 200 || response.data["code"] != 200) {
      print('获取验证码失败');
    }
  }

  getQrCode(String mainUrl) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;
      var response = await Neteasecloud.dio.get(
        '/login/qr/key?timestamp=${timestamp}',
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('获取二维码key失败: ${response.data}');
        return '';
      }

      this.key = response.data['data']['unikey'];

      response = await Neteasecloud.dio.get(
        '/login/qr/create?key=${this.key}&timestamp=${timestamp}&qrimg=true',
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('获取二维码失败: ${response.data}');
        return '';
      }

      var qrcodeImg = response.data['data']['qrimg'];

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
      var response = await Neteasecloud.dio.get(
        '/login/cellphone?phone=${mobile}&captcha=${code}',
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('登录失败');
        return false;
      }

      var rawCookies = response.data['cookie'];
      if (rawCookies == '') {
        print('登录成功但未获取到cookie');
        return false;
      }

      var cookies = this.extractCookieString(rawCookies);
      // print('登录成功，获取到cookie: $cookies');
      print('登录成功: ${response.data}');
      this.userData = NetEaseCloudData(
        cookies: cookies,
        loginType: 1,
        token: response.data['token'] ?? '',
        userid: response.data['account']['id'].toString(),
        cover: this.getCover(response.data['profile']['avatarUrl']),
        nickname: response.data['profile']['nickname'],
        url: mainUrl,
      );

      var list = this.accountData.data[1];
      list.add(this.userData);
      var num = list.length - 1; // 添加后的索引（即原来的长度）
      this.accountData.data[1][num] = this.userData;

      print('${this.accountData}');
      this.accountData.login = [1, num];

      this.cookies = cookies;
      // this.mainUrl = mainUrl;

      // await this.login(1)
      await this.getData();

      return true;
    } catch (error) {
      print('loginByMobile 异常: ${error}');
      return false;
    }
  }

  loginByQrCode(String mainUrl) async {
    var timestamp;
    var n = 0;
    var response;

    while (n != 803) {
      if (this.management.loginType != 0) {
        return false;
      }

      timestamp = DateTime.now().millisecondsSinceEpoch;
      response = await Neteasecloud.dio.get(
        '/login/qr/check?key=${this.key}&timestamp=${timestamp}',
      );

      print(response.data);

      n = response.data['code'];

      if (n == 800) {
        this.qrCodeType = 2;
        return false;
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    // let rawCookies : string = response.data?.cookie
    var rawCookies = response.data['cookie'];
    if (rawCookies == '') {
      print('登录成功但未获取到cookie');
      return false;
    }
    var cookies = this.extractCookieString(rawCookies);
    // print('登录成功，获取到cookie: $cookies');

    response = await Neteasecloud.dio.get(
      '/user/account',
      options: Options(headers: {'Cookie': cookies}),
    );
    print('获取到用户信息: ${response.data}');

    this.userData = NetEaseCloudData(
      cookies: cookies,
      loginType: 2,
      token: response.data['token'] ?? '',
      userid: response.data['account']['id'].toString(),
      cover: this.getCover(response.data['profile']['avatarUrl']),
      nickname: response.data['profile']['nickname'],
      url: mainUrl,
    );

    var list = this.accountData.data[1];
    list.add(this.userData);
    var num = list.length - 1; // 添加后的索引（即原来的长度）
    this.accountData.data[1][num] = this.userData;

    print('${this.accountData}');
    this.accountData.login = [1, num];

    this.cookies = cookies;
    // this.mainUrl = mainUrl;

    // await this.login(1)
    await this.getData();

    this.qrCodeType = 1;

    return true;
  }

  refreshToken() async {}

  Future<void> getVipCookie() async {}

  getVipInfo(String userId) async {}

  getData() async {
    if (this.vipCookies == ''){
      await Future.wait([
        this.getVipCookie(),
        this.getPlaylist()
      ]);
    } else {
      await this.getPlaylist();
    }

    this.getCollectionList();
  }

  getCollectionList() async {}

  Future<void> getPlaylist() async {}

  getPlaylistMusic(String listId) async {}

  getSingerMusic(String singerId) async {}

  getSingerAllMusic(String singerId) async {}

  getAlbumMusic(String albumId) async {}

  getSingerAlbum(String singerId) async {}

  getRecommendMusics(int num) async {}

  getRecommendSingers(int num) async {}

  getRecommendPlaylists(int num) async {}

  getRecommendAlbum(int num) async {}

  search(String keyword) async {}

  searchMusic(String keyword) async {}

  searchSinger(String keyword) async {}

  searchAlbum(String keyword) async {}

  getMusicUrl(String musicId, {String bitrate = 'exhigh'}) async {}

  getMatchtMusicUrl(String musicId, {String level = 'exhigh'}) async {}

  getMusicsDetails(List<String> musicIds) async {}

  getSingerDetails(String singerId) async {}

  getAlbumDetails(String albumId) async {}

  getPlaylistDetails(String listId) async {}

  getLyric(String musicId) async {}

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {
    var qualityGrade = ['standard', 'exhigh', 'lossless'];
    if (this.vipCookies != '') {
      var url = await this.getMusicUrl(musicId, bitrate: qualityGrade[quality]);
      return url;
    } else {
      var url = await this.getMatchtMusicUrl(
        musicId,
        level: qualityGrade[quality],
      );
      return url;
    }
  }

  createPlaylist(String name) async {}

  deletePlaylist(String listId) async {}

  addMusicToPlaylist(String listId, String musicId) async {}

  deleteMusicFromPlaylist(String listId, String musicId) async {}

  extractCookieString(String rawCookie) {
    // 按分号分割各个部分
    final parts = rawCookie.split(';');
    final Map<String, String> cookieMap = {};

    for (final part in parts) {
      final trimmed = part.trim();
      // 忽略空字符串
      if (trimmed.isEmpty) continue;

      // 只处理 name=value 格式，且 value 不能以 Max-Age/Expires/Path 开头
      final firstEq = trimmed.indexOf('=');
      if (firstEq == -1) continue;

      final name = trimmed.substring(0, firstEq).trim();
      final value = trimmed.substring(firstEq + 1).trim();

      // 如果 name 是 Max-Age、Expires、Path 等属性，则跳过
      if ([
        'Max-Age',
        'Expires',
        'Path',
        'Domain',
        'Secure',
        'HttpOnly',
        'SameSite',
      ].contains(name)) {
        continue;
      }

      // 保留第一个出现的 cookie（可根据需要修改逻辑）
      if (!cookieMap.containsKey(name)) {
        cookieMap[name] = value;
      }
    }

    // 拼接成合法的 Cookie 字符串
    final List<String> cookieParts = [];
    cookieMap.forEach((name, value) {
      cookieParts.add('${name}=${value}');
    });
    return cookieParts.join('; ');
  }

  getCover(String coverUrl, {String size = '500'}) {
    coverUrl = '${coverUrl}?param=${size}y${size}';
    return coverUrl;
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
