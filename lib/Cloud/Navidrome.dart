import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'dart:math';

class Navidrome implements CloudService{
// class Navidrome{
  late AccountData accountData;
  late Management management;

  late List<Playlist> playlist = [];
  late List<String> collectionList = [];
  late String collectionListId = 'starred';
  late String mainUrl = '';
  late NavidromeData params;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Navidrome({required this.accountData, required this.management});

  login() async {
    this.params = this.accountData.data[2][this.accountData.login[1]];
    this.mainUrl = this.params.url;

    if (!await this.checkLogin(this.params)) {
      print('登录失败');

      return false;
    }

    this.getData();
    return true;
  }

  updateAccountData() async {}
  getVerificationCode(String mobile, String mainUrl) async {}
  getQrCode(String mainUrl) async {}
  loginByMobile(String mobile, String mainUrl, String code) async {}
  loginByQrCode(String mainUrl) async {}

  addLogin(
    String username,
    String mainUrl,
    String password,
    String name,
  ) async {
    var salt = generateSalt();
    var passwordMd5 = await computeMd5WithSalt(password, salt);

    // 如果 mainUrl 不包含 '/rest'，则添加
    if (!mainUrl.contains('/rest')) {
      mainUrl = '${mainUrl.replaceFirst(RegExp(r'/$'), '')}/rest';
    }

    var params = NavidromeData(
      u: username,
      t: passwordMd5,
      p: password,
      s: salt,
      // v: "1.16.1",
      // c: "ChocolateMusic",
      // f: "json",
      name: name,
      url: mainUrl
    );

    if (!await this.checkLogin(params)) {
      print('登录失败');
      return false;
    }

    var list = this.accountData.data[2];
    list.add(params);
    var num = list.length - 1;            // 添加后的索引（即原来的长度）
    this.accountData.data[2][num] = params;

    this.accountData.login = [2, num];

    // this.mainUrl = mainUrl;
    Navidrome.dio.options.baseUrl = this.mainUrl;
    this.params = params;

    await this.getData();

    print('登录成功 ${this.params}');

    return true;
  }

  checkLogin(NavidromeData params) async {
    var url = '${params.url}/ping.view';

    // console.log('登录url', url)
    // console.log('登录参数', JSON.stringify(params))
    print('登录url: $url');
    print('登录参数: ${jsonEncode(params)}');

    try {
      var response = await dio.get(
          url,
        queryParameters: params.toJson()
      );
      print(response.data);
      if (response.statusCode != 200 || response.data['subsonic-response']['status'] != 'ok') {
        print('登录验证失败');
        return false;
      }

      return true;
    } catch (error) {
      print('登录验证失败 $error');
      return false;
    }
  }

  updateAccountLogin(String mainUrl, int index) async {}

  getData() async {
    await this.getPlaylist();
    this.getCollectionList();
  }

  getCollectionList() async {}

  getPlaylist() async {}

  getPlaylistMusic(String listId) async {}

  getSingerMusic(String singerId) async {}

  getAlbumMusic(String albumId) async {}

  getSingerAlbum(String singerId) async {}

  getRecommendMusics(int num) async {}

  getRecommendSingers(int num) async {}

  getRecommendAlbum(int num) async {}

  getRecommendPlaylists(int num) async {}

  search(String keyword) async {}

  getMusicUrl(String musicId, {String bitrate = '128'}) async {}

  getMusicDetails(String musicId) async {}

  getMusicsDetails(List<String> musicIds) async {}

  getSingerDetails(String singerId) async {}

  getAlbumDetails(String albumId) async {}

  getPlaylistDetails(String listId) async {}

  getLyric(String musicId) async {}

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {
    var qualityGrade = ['128', '320', ''];
    var url = this.getMusicUrl(musicId, bitrate: qualityGrade[quality]);
    return url;
  }

  createPlaylist(String name) async {}

  deletePlaylist(String listId) async {}

  addMusicToPlaylist(String listId, String musicId) async {}

  deleteMusicFromPlaylist(String listId, String musicId) async {}

  getCover(String coverUrl, {String size = '500'}) {}

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

/// 生成六位随机数字盐值（100000 - 999999）
String generateSalt() {
  const min = 100000;
  const max = 999999;

  final random = Random();
  final saltNum = min + random.nextInt(max - min + 1);

  return saltNum.toString();
}

/// 使用 MD5 加盐计算密码哈希
///
/// password: 原始密码
/// salt: 盐值
///
/// 返回：十六进制 MD5 哈希字符串
String computeMd5WithSalt(String password, String salt) {
  // 1. 拼接字符串
  final combined = password + salt;

  // 2. UTF-8 编码
  final bytes = utf8.encode(combined);

  // 3. MD5
  final digest = md5.convert(bytes);

  // 4. 转换为十六进制字符串
  return digest.toString();
}
