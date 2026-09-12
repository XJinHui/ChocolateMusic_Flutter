import 'dart:convert';

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

      if (response.statusCode != 200 || response.data['data']["code"] != 200) {
        print('登录状态检查失败: ${jsonEncode(response.data)}');
        // this.playlistManagement.logining = 2

        return false;
      }

      print('登录状态检查响应: ${jsonEncode(response.data)}');
      await this.getData();
    } catch (error) {
      print('login 异常: ${error}');
      return false;
    }

    if (this.accountData.data[1][this.accountData.login[1]].loginType == 1) {
      this.refreshToken();
    }

    return true;
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
        print('获取二维码key失败: ${jsonEncode(response.data)}');
        return '';
      }

      this.key = response.data['data']['unikey'];

      response = await Neteasecloud.dio.get(
        '/login/qr/create?key=${this.key}&timestamp=${timestamp}&qrimg=true',
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('获取二维码失败: ${jsonEncode(response.data)}');
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
      print('登录成功: ${jsonEncode(response.data)}');
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

      // print('${this.accountData}');
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

      // print(response.data);

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
    print('获取到用户信息: ${jsonEncode(response.data)}');

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

    // print('${this.accountData}');
    this.accountData.login = [1, num];

    this.cookies = cookies;
    // this.mainUrl = mainUrl;

    // await this.login(1)
    await this.getData();

    this.qrCodeType = 1;

    return true;
  }

  refreshToken() async {
    try {
      var response = await Neteasecloud.dio.get(
        '/login/refresh',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('cookie刷新失败 ${jsonEncode(response.data)}');
        return false;
      }

      // console.log('cookie刷新响应:', JSON.stringify(response.data))
      print('cookie刷新响应: ${jsonEncode(response.data)}');

      var rawCookies = response.data['cookie'];
      if (rawCookies == '') {
        print('未获取到cookie');
        return false;
      }
      var cookies = this.extractCookieString(rawCookies);
      print('cookie刷新成功，获取到cookie: ${cookies}');
      this.cookies = cookies;

      this.accountData.data[1][this.accountData.login[1]].cookies = cookies;
      this.management.updateAccountData();

      return true;
    } catch (error) {
      print('refreshToken 异常: ${error}');
      return false;
    }
  }

  Future<void> getVipCookie() async {
    final List<NetEaseCloudData> accounts = this.accountData.data[1]
        .whereType<NetEaseCloudData>()
        .toList();
    final List<bool> results = await Future.wait<bool>(
      accounts.map((account) => this.getVipInfo(account.userid)),
    );

    for (int i = 0; i < results.length; i++) {
      if (results[i]) {
        this.vipCookies = accounts[i].cookies;
        print('获取到VIP用户cookie: ${this.vipCookies}');
        return;
      }
    }
  }

  Future<bool> getVipInfo(String userId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/vip/info?uid=${userId}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data["code"] != 200) {
        print('获取VIP信息失败: ${jsonEncode(response.data)}');
        return false;
      }

      if (response.data['data']['redVipAnnualCount'] == -1) {
        print('用户不是VIP');
        return false;
      }

      return true;
    } catch (error) {
      print('getVipInfo 异常: ${error}');
      return false;
    }
  }

  getData() async {
    if (this.vipCookies == '' && this.accountData.data[1].length > 1) {
      await Future.wait([this.getVipCookie(), this.getPlaylist()]);
    } else {
      await this.getPlaylist();
      this.getVipCookie();
    }

    this.getCollectionList();
  }

  getCollectionList() async {
    for (var i in this.playlist) {
      if (i.name == '我喜欢') {
        this.collectionListId = i.listId;
        break;
      }
    }

    var timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      var response = await Neteasecloud.dio.get(
        '/playlist/track/all?id=${this.collectionListId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取收藏歌单列表失败: ${jsonEncode(response.data)}');
        return;
      }

      var data = response.data['songs'];

      for (var item in data) {
        var id = item['id'].toString(); // 从 Map 中获取 id
        if (id != null && !this.collectionList.contains(id)) {
          this.collectionList.add(id);
        }
      }

      print('收藏歌曲数量: ${this.collectionList.length}');
    } catch (error) {
      print('getCollectionList 异常: ${error}');
    }
  }

  Future<List<Playlist>> getPlaylist() async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    // let url: string = `${this.mainUrl}/user/playlist?uid=${this.userData?.userid}&limit=300&timestamp=${timestamp}`
    try {
      var response = await Neteasecloud.dio.get(
        '/user/playlist?uid=${this.userData.userid}&limit=300&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌单列表失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Playlist> playlists = [];

      var data = response.data['playlist'];
      // print('歌单数量: ${data.length}');
      // print('歌单列表: ${data}');

      var name;
      for (var i in data) {
        if (i['name'] == this.userData.nickname + '喜欢的音乐') {
          name = '我喜欢';
        } else {
          name = i['name'];
        }

        playlists.add(
          Playlist(
            name: name,
            listId: i['id'].toString(),
            audioCount: i['trackCount'],
            cover: this.getCover(i['coverImgUrl']),
          ),
        );
      }

      this.playlist = playlists;
      this.management.playlists = this.playlist;

      return playlists;
    } catch (error) {
      print('getPlaylist 异常: ${error}');
      return [];
    }
  }

  getPlaylistMusic(String listId) async {
    var timestamp = 0;

    for (var i in this.playlist) {
      if (i.listId == listId) {
        timestamp = DateTime.now().millisecondsSinceEpoch;
        break;
      }
    }

    var url =
        '${this.mainUrl}/playlist/track/all?id=${listId}&timestamp=${timestamp}';

    try {
      var response = await Neteasecloud.dio.get(
        '/playlist/track/all?id=${listId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌单列表失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['songs'];

      List<String> ids = data
          .map<String>((item) => item['id'].toString())
          .toList();

      if (ids.length == 0) {
        print('歌单内没有歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids) as List<Music>;

      print('最终歌曲数量: ${musics.length}');
      // print('最终歌曲: ${musics}');

      return musics;
    } catch (error) {
      print('getPlaylistMusic 异常: ${error}');
      return [];
    }
  }

  getSingerMusic(String singerId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/artist/songs?id=${singerId}&limit=200',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌手列表失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['songs'];

      List<String> ids = data
          .map<String>((item) => item['id'].toString())
          .toList();

      if (ids.length == 0) {
        print('歌单内没有歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids);

      print('最终歌曲数量: ${musics.length}');
      // print('最终歌曲: ${musics}');

      return musics;
    } catch (error) {
      print('getSingerMusic 异常: ${error}');
      return [];
    }
  }

  getSingerAllMusic(String singerId) async {
    var num = 200;
    var offset = 0;
    List<String> musicIds = [];
    // var url = '${this.mainUrl}/artist/songs?id=${singerId}&limit=${num}&offset=${offset}';

    while (true) {
      try {
        var response = await Neteasecloud.dio.get(
          '/artist/songs?id=${singerId}&limit=${num}&offset=${offset}',
          options: Options(headers: {'Cookie': this.cookies}),
        );

        offset += 200;

        if (response.statusCode != 200 || response.data['code'] != 200) {
          print('获取歌手歌单列表失败: ${jsonEncode(response.data)}');
        }

        if (response.data['songs'].length == 0) {
          break;
        }

        var data = response.data['songs'];

        var ids = data.map<String>((item) => item['id'].toString()).toList();

        musicIds = musicIds + ids;
        // print('当前已获取歌曲ID: ${musicIds}');
      } catch (error) {
        print('getSingerAllMusic 异常: ${error}');
      }
    }

    List<Music> musics = await this.getMusicsDetails(musicIds);

    // print('最终歌曲数量: ${musics.length}');
    // print('最终歌曲: ${musics}');

    return musics;
  }

  getAlbumMusic(String albumId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/album?id=${albumId}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取专辑列表失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['songs'];

      List<String> ids = data
          .map<String>((item) => item['id'].toString())
          .toList();

      if (ids.length == 0) {
        print('歌单内没有歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids);

      // print('最终歌曲数量: ${musics.length}');
      // print('最终歌曲: ${musics}');

      return musics;
    } catch (error) {
      print('getAlbumMusic 异常: ${error}');
      return [];
    }
  }

  getSingerAlbum(String singerId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/artist/album?id=${singerId}&limit=300',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌手专辑失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Album> albums = [];

      var data = response.data['hotAlbums'];
      print('歌手专辑数量: ${data.length}');
      // print('歌手专辑列表: ${data}');

      var singer = response.data['artist']['name'];

      for (var i in data) {
        albums.add(
          Album(
            album: i['name'],
            albumId: i['id'].toString(),
            singer: singer,
            cover: this.getCover(i['picUrl']),
            audioCount: i['size'],
          ),
        );
      }

      print('最终歌手专辑数量: ${albums.length}');
      // print('最终歌手专辑: ${albums}');
      return albums;
    } catch (error) {
      print('getSingerAlbum 异常: ${error}');
      return [];
    }
  }

  getRecommendMusics(int num) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/recommend/songs',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取推荐音乐响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取推荐歌曲失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['data']['dailySongs'];
      print('推荐歌曲数量: ${data.length}');

      // var shuffled = this.shuffleArray(data.map((item) => item['id']).toList());
      var shuffled = data.map<String>((item) => item['id'].toString()).toList()
        ..shuffle();

      num = num > shuffled.length ? shuffled.length : num;
      var targetIds = shuffled.sublist(0, num);
      print('目标歌曲ID: ${targetIds}');
      musics = await this.getMusicsDetails(targetIds);

      print('最终推荐歌曲数量: ${musics.length}');
      // print('最终推荐歌曲: ${musics}');

      return musics;
    } catch (error) {
      print('getRecommendMusics 异常: ${error}');
      return [];
    }
  }

  getRecommendSingers(int num) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/top/artists?limit=100',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取推荐歌手响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取推荐歌手失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Singer> singers = [];

      var data = response.data['artists'];
      print('推荐歌手数量: ${data.length}');

      // var shuffled = this.shuffleArray(data.map((item) => item['id']).toList());
      var shuffled = data.map((item) => item['id'].toString()).toList()
        ..shuffle();

      num = num > shuffled.length ? shuffled.length : num;
      var targetIds = shuffled.sublist(0, num);

      for (var i in data) {
        if (targetIds.contains(i['id'].toString())) {
          singers.add(
            Singer(
              singer: i['name'],
              singerId: i['id'].toString(),
              cover: this.getCover(i['picUrl']),
              audioCount: i['musicSize'],
              albumCount: i['albumSize'],
            ),
          );
        }
      }

      print('最终推荐歌手数量: ${singers.length}');
      // print('最终推荐歌手: ${singers}');

      return singers;
    } catch (error) {
      print('getRecommendSingers 异常: ${error}');
      return [];
    }
  }

  getRecommendPlaylists(int num) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/recommend/resource',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取推荐歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取推荐歌单失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Playlist> playlists = [];

      var data = response.data['recommend'];
      print('推荐歌单数量: ${data.length}');

      // var shuffled = this.shuffleArray(data.map((item) => item['id']).toList());
      var shuffled = data.map((item) => item['id']).toList()..shuffle();

      num = num > shuffled.length ? shuffled.length : num;
      var targetIds = shuffled.sublist(0, num);

      for (var i in data) {
        if (targetIds.contains(i['id'])) {
          playlists.add(
            Playlist(
              name: i['name'],
              listId: i['id'].toString(),
              audioCount: i['trackCount'],
              cover: this.getCover(i['picUrl']),
            ),
          );
        }
      }

      print('最终推荐歌单数量: ${playlists.length}');
      // print('最终推荐歌单: ${playlists}');

      return playlists;
    } catch (error) {
      print('getRecommendPlaylists 异常: ${error}');
      return [];
    }
  }

  getRecommendAlbum(int num) async {}

  search(String keyword) async {
    final results = await Future.wait([
      searchMusic(keyword),
      searchSinger(keyword),
      searchAlbum(keyword),
    ]);

    this.management.searchList.music = results[0] as List<Music>;
    this.management.searchList.singer = results[1] as List<Singer>;
    this.management.searchList.album = results[2] as List<Album>;
  }

  Future<List<Music>> searchMusic(String keyword) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/search?type=1&limit=50',
        options: Options(headers: {'Cookie': this.cookies}),
        queryParameters: {'keywords': keyword},
      );

      // print('搜索歌曲响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('搜索歌曲失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['result']['songs'];

      var ids = data.map<String>((item) => item['id'].toString()).toList();

      if (ids.isEmpty) {
        print('没有搜索到歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids);

      print('最终搜索歌曲数量: ${musics.length}');
      // print('最终搜索歌曲: ${musics}');

      return musics;
    } catch (error) {
      print('searchMusic 异常: ${error}');
      return [];
    }
  }

  Future<List<Singer>> searchSinger(String keyword) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/search?type=100&limit=5',
        options: Options(headers: {'Cookie': this.cookies}),
        queryParameters: {'keywords': keyword},
      );

      // print('搜索歌手响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('搜索歌手失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Singer> singers = [];

      var data = response.data['result']['artists'];
      print('搜索歌手数量: ${data.length}');
      // print('搜索歌手列表: ${jsonEncode(data)}');

      for (var i in data) {
        singers.add(
          Singer(
            singer: i['name'],
            singerId: i['id'].toString(),
            cover: this.getCover(i['picUrl']),
            audioCount: i['musicSize'],
            albumCount: i['albumSize'],
          ),
        );
      }

      print('最终搜索歌手数量: ${singers.length}');
      // print('最终搜索歌手: ${jsonEncode(singers)}');
      return singers;
    } catch (error) {
      print('searchSinger 异常: ${error}');
      return [];
    }
  }

  Future<List<Album>> searchAlbum(String keyword) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/search?type=10&limit=10',
        options: Options(headers: {'Cookie': this.cookies}),
        queryParameters: {'keywords': keyword},
      );

      // print('搜索专辑响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('搜索专辑失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Album> albums = [];

      var data = response.data['result']['albums'];
      print('搜索专辑数量: ${data.length}');
      // print('搜索专辑列表: ${jsonEncode(data)}');

      for (var i in data) {
        var singer = '';
        for (var j in i['artists']) {
          if (singer.isNotEmpty) {
            singer += '、';
          }
          singer += j['name'];
        }

        albums.add(
          Album(
            album: i['name'],
            albumId: i['id'].toString(),
            singer: singer,
            cover: this.getCover(i['picUrl']),
            audioCount: i['size'],
          ),
        );
      }

      print('最终搜索专辑数量: ${albums.length}');
      // print('最终搜索专辑: ${jsonEncode(albums)}');
      return albums;
    } catch (error) {
      print('searchAlbum 异常: ${error}');
      return [];
    }
  }

  getMusicUrl(String musicId, {String bitrate = 'exhigh'}) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/song/url/v1?id=${musicId}&level=${bitrate}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取歌曲播放链接响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌曲播放链接失败: ${jsonEncode(response.data)}');
        return '';
      }

      var musicUrl = response.data['data'][0]['url'];

      // console.log('歌曲播放链接响应:', JSON.stringify(musicUrl))
      print('歌曲播放链接响应: ${musicUrl}');

      if (musicUrl == null || musicUrl.isEmpty) {
        print('未获取到歌曲播放链接,正在尝试解灰匹配的歌曲播放链接');
        musicUrl = await this.getMatchtMusicUrl(musicId, level: bitrate);
        if (musicUrl == null || musicUrl.isEmpty) {
          return '';
        }
      }

      return musicUrl;
    } catch (error) {
      print('getMusicUrl 异常: ${error}');
      return '';
    }
  }

  getMatchtMusicUrl(String musicId, {String level = 'exhigh'}) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/song/url/v1?id=${musicId}&level=${level}&unblock=true',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取歌曲播放链接响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌曲播放链接失败: ${jsonEncode(response.data)}');
        return '';
      }

      var musicUrl = response.data['data'][0]['url'];

      print('歌曲播放链接响应: ${musicUrl}');

      if (musicUrl == null || musicUrl.isEmpty) {
        print('未获取到歌曲播放链接,且未匹配成功的歌曲播放链接');
        return '';
      }

      return musicUrl;
    } catch (error) {
      print('getMatchtMusicUrl 异常: ${error}');
      return '';
    }
  }

  Future<List<Music>> getMusicsDetails(List<String> musicIds) async {
    var id = '';
    for (var i in musicIds) {
      if (id.isNotEmpty) {
        id += ',';
      }
      id += i;
    }

    try {
      var response = await Neteasecloud.dio.get(
        '/song/detail?ids=${id}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取音乐详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取音乐详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['songs'];
      // print('音乐详情响应: ${data}');

      List<Music> musics = [];
      for (var i in data) {
        var singer = '';
        for (var j in i['ar']) {
          if (singer.isNotEmpty) {
            singer += '、';
          }
          singer += j['name'];
        }
        var music = Music(
          id: i['id'].toString(),
          name: i['name'],
          singer: singer,
          singerId: i['ar'][0]['id'].toString(),
          album: i['al']['name'],
          albumId: i['al']['id'].toString(),
          time: i['dt'],
          cover: this.getCover(i['al']['picUrl']),
          // like: this.getLikeStatus(i['id'])
        );
        // print(music);
        musics.add(music);
      }

      // print('最终音乐详情: ${musics}');

      return musics;
    } catch (error) {
      print('getMusicsDetails 异常: ${error}');
      return [];
    }
  }

  getSingerDetails(String singerId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/artist/detail?id=${singerId}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取歌手详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌手详情失败: ${jsonEncode(response.data)}');
        return false;
      }

      var data = response.data['data']['artist'];
      // print('歌手详情响应: ${jsonEncode(data)}');

      Singer singer = Singer(
        singer: data['name'],
        singerId: data['id'].toString(),
        cover: this.getCover(data['cover']),
        audioCount: data['musicSize'],
        albumCount: data['albumSize'],
      );

      // print('最终歌手详情: ${jsonEncode(singer)}');

      return singer;
    } catch (error) {
      print('getSingerDetails 异常: ${error}');
      return false;
    }
  }

  getAlbumDetails(String albumId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/album?id=${albumId}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取专辑详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取专辑详情失败: ${jsonEncode(response.data)}');
        return false;
      }

      var data = response.data['album'];
      // print('专辑详情响应: ${jsonEncode(data)}');

      var singer = '';
      for (var i in data['artists']) {
        if (singer.isNotEmpty) {
          singer += '、';
        }
        singer += i['name'];
      }

      Album album = Album(
        album: data['name'],
        albumId: data['id'].toString(),
        singer: singer,
        cover: this.getCover(data['picUrl']),
        audioCount: data['size'],
      );

      // print('最终专辑详情: ${jsonEncode(album)}');

      return album;
    } catch (error) {
      print('getAlbumDetails 异常: ${error}');
      return false;
    }
  }

  getPlaylistDetails(String listId) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;
      var response = await Neteasecloud.dio.get(
        '/playlist/detail?id=${listId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取歌单详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌单详情失败: ${jsonEncode(response.data)}');
        return false;
      }

      var data = response.data['playlist'];

      Playlist playlist = Playlist(
        name: data['name'],
        listId: data['id'].toString(),
        audioCount: data['trackCount'],
        cover: this.getCover(data['coverImgUrl']),
      );

      // print('歌单详情响应: ${jsonEncode(data)}');

      return playlist;
    } catch (error) {
      print('getPlaylistDetails 异常: ${error}');
      return false;
    }
  }

  getLyric(String musicId) async {
    try {
      var response = await Neteasecloud.dio.get(
        '/lyric?id=${musicId}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('获取歌词详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('获取歌词详情失败: ${jsonEncode(response.data)}');
        return false;
      }

      var lyric = response.data['lrc']['lyric'];
      var tlyric = response.data['tlyric']['lyric'];

      if (tlyric != null && tlyric.isNotEmpty) {
        lyric += tlyric;
      }

      // print('歌词响应: ${jsonEncode(lyric)}');

      return lyric;
    } catch (error) {
      print('getLyric 异常: ${error}');
      return false;
    }
  }

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

  createPlaylist(String name) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await Neteasecloud.dio.get(
        '/playlist/create?timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
        queryParameters: {'name': name},
      );

      // print('创建歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('创建歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      var listid = response.data['id'];
      Playlist playlist = Playlist(
        name: name,
        listId: listid,
        audioCount: 0,
        cover: '',
      );

      this.playlist.add(playlist);

      print('创建歌单成功，歌单id: ${listid}');

      return true;
    } catch (error) {
      print('createPlaylist 异常: ${error}');
      return false;
    }
  }

  deletePlaylist(String listId) async {
    if (listId == this.collectionListId) {
      print('无法删除收藏歌单');
      return false;
    }

    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await Neteasecloud.dio.get(
        '/playlist/delete?id=${listId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('删除歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['code'] != 200) {
        print('删除歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      // for (var i = 0; i < this.playlist.length; i++) {
      //   if (this.playlist[i].listId == listId) {
      //     this.playlist.removeAt(i);
      //     break;
      //   }
      // }

      playlist.removeWhere((item) => item.listId == listId);

      print('删除歌单成功，歌单id: ${listId}');

      return true;
    } catch (error) {
      print('deletePlaylist 异常: ${error}');
      return false;
    }
  }

  addMusicToPlaylist(String listId, String musicId) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await Neteasecloud.dio.get(
        '/playlist/tracks?op=add&pid=${listId}&tracks=${musicId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('添加歌曲到歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200) {
        print('添加歌曲到歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      if (response.data.containsKey('code') && response.data['code'] != null) {
        if (response.data['code'] != 200) {
          print('添加歌曲到歌单失败: ${jsonEncode(response.data)}');
          return false;
        }
      } else {
        if (response.data['status'] != 200 ||
            response.data['body']['code'] != 200) {
          print('添加歌曲到歌单失败: ${jsonEncode(response.data)}');
          return false;
        }
      }

      print('添加歌曲到歌单成功，歌单id: ${listId}, 歌曲id: ${musicId}');

      if (listId == this.collectionListId) {
        if (this.collectionList.contains(musicId)) {
          print('音乐已在我喜欢歌单中，无需重复添加，音乐id: ${musicId}');
        } else {
          this.collectionList.add(musicId);
          print('音乐成功添加到我喜欢歌单，音乐id: ${musicId}');
        }
      }

      var index = this.playlist.indexWhere((item) => item.listId == listId);
      if (index != -1) {
        this.playlist[index].audioCount += 1;
        print(
          '歌单音乐数量加1，歌单id: ${listId}, 当前数量: ${this.playlist[index].audioCount}',
        );
      } else {
        print('未找到对应歌单，无法更新音乐数量，歌单id: ${listId}');
      }

      return true;
    } catch (error) {
      print('addMusicToPlaylist 异常: ${error}');
      return false;
    }
  }

  deleteMusicFromPlaylist(String listId, String musicId) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await Neteasecloud.dio.get(
        '/playlist/tracks?op=del&pid=${listId}&tracks=${musicId}&timestamp=${timestamp}',
        options: Options(headers: {'Cookie': this.cookies}),
      );

      // print('从歌单删除歌曲响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data['body']['code'] != 200) {
        print('从歌单删除歌曲失败: ${jsonEncode(response.data)}');
        return false;
      }

      print('从歌单删除歌曲成功，歌单id: ${listId}, 歌曲id: ${musicId}');

      // if (listId == this.collectionListId) {
      //   var index = this.collectionList.indexOf(musicId);
      //   if (index != -1) {
      //     this.collectionList.removeAt(index);
      //     print('音乐成功从我喜欢歌单删除，音乐id: ${musicId}');
      //   } else {
      //     print('音乐不在我喜欢歌单中，无需删除，音乐id: ${musicId}');
      //   }
      // }

      if (listId == this.collectionListId) {
        if (this.collectionList.remove(musicId)) {
          print('音乐成功从我喜欢歌单删除，音乐id: ${musicId}');
        } else {
          print('音乐不在我喜欢歌单中，无需删除，音乐id: ${musicId}');
        }
      }

      var index = this.playlist.indexWhere((item) => item.listId == listId);
      if (index != -1) {
        this.playlist[index].audioCount = max(
          0,
          this.playlist[index].audioCount - 1,
        );
        print(
          '歌单音乐数量减1，歌单id: ${listId}, 当前数量: ${this.playlist[index].audioCount}',
        );
      } else {
        print('未找到对应歌单，无法更新音乐数量，歌单id: ${listId}');
      }

      return true;
    } catch (error) {
      print('deleteMusicFromPlaylist 异常: ${error}');
      return false;
    }
  }

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
    // print(coverUrl);
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
