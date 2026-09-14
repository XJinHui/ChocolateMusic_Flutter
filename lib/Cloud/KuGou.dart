import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'dart:math';

class KuGou implements CloudService {
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
      receiveTimeout: const Duration(seconds: 30),
    ),
  )..options.validateStatus = (status) => true;

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
      return false;
    }

    try {
      // let url = this.mainUrl
      // let response: AxiosResponse = await axios.get(url)
      //
      // Kugou.dio.options.baseUrl = this.mainUrl;
      final response = await KuGou.dio.get('');
      if (response.statusCode != 200) {
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

    this.refreshToken();
    return true;
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

  updateAccountLogin(String mainUrl, int index) async {}

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
        print('获取二维码失败: ${jsonEncode(response.data)}');
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

      print('登录响应: ${jsonEncode(response.data)}');

      if (response.data['data'].containsKey('info_list') &&
          response.data['data']['info_list'] != null) {
        print('登录响应包含 info_list: ${jsonEncode(response.data)}');
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
        t_expire_time: data['t_expire_time'].toInt(),
        // 注意：如果 data 里也是 int
        cover: response.data['data']['pic'],
        // 根据你原先的写法
        nickname: data['nickname'] ?? '',
        dfid: dfid,
        url: this.mainUrl,
      );
      print('用户数据: ${this.userData}');

      var list = this.accountData.data[0];
      list.add(this.userData);
      var num = list.length - 1; // 添加后的索引（即原来的长度）
      this.accountData.data[0][num] = this.userData;

      print('${this.accountData}');
      this.accountData.login = [0, num];

      this.token = this.userData.token;
      this.mainUrl = mainUrl;
      this.params = {
        'token': this.userData.token,
        'userid': this.userData.userid,
        'dfid': dfid,
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

      if (n == 0) {
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
      url: this.mainUrl,
    );

    this.params = {
      'token': this.userData.token,
      'userid': this.userData.userid,
      'dfid': dfid,
    };

    await this.refreshToken();
    // this.mainUrl = mainUrl
    print('登录成功${this.userData}');

    var list = this.accountData.data[0];
    list.add(this.userData);
    var num = list.length - 1; // 添加后的索引（即原来的长度）
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

  refreshToken() async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      var response = await KuGou.dio.get(
        '/login/token?timestamp=${timestamp}',
        queryParameters: this.params,
      );

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('token刷新失败');
        return false;
      }

      var data = response.data['data'];

      this.userData = KugouData(
        token: data['token'] ?? '',
        userid: data['userid'].toString() ?? '',
        t_expire_time: data['t_expire_time'].toInt(),
        cover: response.data['data']['pic'],
        nickname: data['nickname'] ?? '',
        dfid: this.params['dfid'].toString(),
        url: this.mainUrl,
      );

      this.params['token'] = this.userData.token;
      this.accountData.data[0][this.accountData.login[1]] = this.userData;
      this.management.updateAccountData();
    } catch (error) {
      print('refreshToken 异常: $error');
    }
  }

  Future<void> getVip() async {
    var response;
    try {
      this.getVip8();
      // 获取 UTC 时间 + 8 小时，然后格式化为日期
      DateTime beijingDate = DateTime.now().toUtc().add(Duration(hours: 8));
      String date_str =
          '${beijingDate.year}-${beijingDate.month.toString().padLeft(2, '0')}-${beijingDate.day.toString().padLeft(2, '0')}';
      print('北京时间: $date_str');
      response = await KuGou.dio.get(
        '/youth/day/vip?receive_day=${date_str}',
        queryParameters: this.params,
        options: Options(
          headers: {
            'Cookie':
                'token=${this.params['token']}; userid=${this.params['userid']}; dfid=${this.params['dfid']}',
          },
        ),
      );
      print('getVip 响应: ${jsonEncode(response.data)}');
    } catch (error) {
      print('getVip 异常: $error');
    }

    try {
      response = await KuGou.dio.get(
        '/youth/day/vip/upgrade',
        queryParameters: this.params,
        options: Options(
          headers: {
            'Cookie':
                'token=${this.params['token']}; userid=${this.params['userid']}; dfid=${this.params['dfid']}',
          },
        ),
      );
      print('getVip upgrade 响应: ${jsonEncode(response.data)}');
    } catch (error) {
      print('getVip upgrade 异常: $error');
    }
  }

  getVip8() async {
    var timestamp;

    try {
      for (var i = 0; i < 8; i++) {
        timestamp = DateTime.now().millisecondsSinceEpoch;
        try {
          var response = await KuGou.dio.get(
            '/youth/vip?timestamp=${timestamp}',
            queryParameters: this.params,
            options: Options(
              headers: {
                'Cookie':
                    'token=${this.params['token']}; userid=${this.params['userid']}; dfid=${this.params['dfid']}',
              },
            ),
          );

          print('getVip8 day ${i} 响应: ${jsonEncode(response.data)}');

          if (response.data.containsKey('error_msg') &&
              response.data['error_msg'] == '今天次数已用光') {
            return;
          }
        } catch (error) {
          // console.error(`getVip8 day ${i} 异常:`, error)
          print('getVip8 day ${i} 异常: $error');
        }

        await Future.delayed(const Duration(milliseconds: 15000));
      }
    } catch (error) {
      print('getVip8 异常: $error');
    }
  }

  getData() async {
    await Future.wait([getPlaylist(), getVip()]);
    this.getCollectionList();
  }

  getCollectionList() async {
    for (var i in this.playlist) {
      if (i.name == '我喜欢') {
        this.collectionListId = i.listId;
        break;
      }
    }

    List<String> music_id = [];
    List<Music> musics = [];
    var n = 0;
    // var url;
    var timestamp;
    var response;
    var isEnd = false;

    while (true) {
      try {
        timestamp = DateTime.now().millisecondsSinceEpoch;

        response = await KuGou.dio.get(
          '/playlist/track/all?id=${this.collectionListId}&pagesize=300&page=${n + 1}&timestamp=${timestamp}',
          queryParameters: this.params,
        );

        if (response.statusCode != 200 || response.data["status"] != 1) {
          print('获取歌单歌曲失败: $response.data');
          return [];
        }
        if (response.data['data']['songs'].length == 0) {
          break;
        }

        var data = response.data['data']['songs'];

        for (var item in data) {
          var hash = item['hash'];
          if (hash != null && !music_id.contains(hash)) {
            collectionList.add(hash);
          }
        }

        n++;
      } catch (error) {
        print('getCollectionList 异常: $error');
        break;
      }
    }

    print('收藏歌曲数量: ${this.collectionList.length}');
  }

  Future<List<Playlist>> getPlaylist() async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    // let url: string = `${this.mainUrl}/user/playlist?timestamp=${timestamp}`
    try {
      var response = await KuGou.dio.get(
        '/user/playlist?timestamp=${timestamp}',
        queryParameters: this.params,
      );

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌单列表失败: $response.data');
        return [];
      }

      List<Playlist> playlists = [];

      var data = response.data['data']['info'];

      // print('歌单列表: ${data}');

      for (var item in data) {
        playlists.add(
          Playlist(
            name: item['name'],
            listId: item['global_collection_id'],
            audioCount: item['m_count'],
            cover: getCover(item['pic']), // getCover 是当前类的方法
          ),
        );

        playlist_to_id[item['global_collection_id']] = item['listid']
            .toString();
      }

      if (playlists[1].name == '我喜欢') {
        var a = playlists[0];
        playlists[0] = playlists[1];
        playlists[1] = a;
      }

      this.playlist = playlists;

      this.management.playlists = this.playlist;
      this.management.refresh();

      return playlists;
    } catch (error) {
      print('getPlaylist 异常: $error');
      return [];
    }
  }

  getPlaylistMusic(String listId) async {
    List<String> music_id = [];
    List<Music> musics = [];
    int n = 0;
    String url;
    int timestamp;
    var response;
    bool isEnd = false;

    while (true) {
      try {
        timestamp = DateTime.now().millisecondsSinceEpoch;
        var response = await KuGou.dio.get(
          '/playlist/track/all?id=${listId}&pagesize=300&page=${n + 1}&timestamp=${timestamp}',
          queryParameters: this.params,
        );

        if (response.statusCode != 200 || response.data["status"] != 1) {
          print('获取歌单歌曲失败: $response.data');
        }

        if (response.data['data']['songs'].length == 0) {
          break;
        }

        var data = response.data['data']['songs'];

        for (var i in data) {
          if (!music_id.contains(i['hash']) && i['hash'] != null) {
            music_id.add(i['hash']);
          }
        }

        n++;

        for (var i in this.playlist) {
          if (i.listId == listId) {
            isEnd = true;
            break;
          }
        }
        if (!isEnd) {
          break;
        }
      } catch (error) {
        print('getPlaylistMusic 异常: $error');
        break;
      }
    }
    // print('歌曲id列表: ${jsonEncode(music_id)}');
    // print('歌曲数量: ${music_id.length}');

    musics = await this.getMusicsDetails(music_id);
    // print('歌曲详情列表: ${jsonEncode(musics)}');
    print('歌曲数量: ${musics.length}');

    return musics;
  }

  getSingerMusic(String singerId) async {
    try {
      var response = await KuGou.dio.get(
        '/artist/audios?id=${singerId}&pagesize=200&sort=hot',
        queryParameters: this.params,
      );

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌手歌曲列表失败: $response.data');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['data'] as List<dynamic>;

      List<String> ids = data
          .map<String>((item) => item['hash'].toString())
          .toList();

      if (ids.length == 0) {
        print('歌单内没有歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids);

      print('最终歌曲数量: ${musics.length}');
      // print('最终歌曲: ${jsonEncode(musics)}');

      return musics;
    } catch (error) {
      print('getSingerMusic 异常: ${error}');
      return [];
    }
  }

  getAlbumMusic(String albumId) async {
    try {
      var response = await KuGou.dio.get(
        '/album/songs?id=${albumId}',
        queryParameters: this.params,
      );

      // print('获取专辑歌曲列表响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取专辑歌曲列表失败: $response.data');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['data']['songs'];

      List<String> ids = data
          .map<String>((item) => item['audio_info']['hash'].toString())
          .toList();

      if (ids.length == 0) {
        print('歌单内没有歌曲');
        return [];
      }

      musics = await this.getMusicsDetails(ids);

      print('最终歌曲数量: ${musics.length}');
      // print('最终歌曲: ${jsonEncode(musics)}');

      return musics;
    } catch (error) {
      print('getAlbumMusic 异常: $error');
      return [];
    }
  }

  getSingerAlbum(String singerId) async {
    try {
      var response = await KuGou.dio.get(
        '/artist/albums?id=${singerId}&pagesize=300&sort=hot',
        queryParameters: this.params,
      );

      // print('获取歌手专辑列表响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌手专辑列表失败: $response.data');
        return [];
      }

      List<Album> album = [];
      var data = response.data['data'];

      for (var i in data) {
        album.add(
          Album(
            album: i['album_name'],
            albumId: i['album_id'].toString(),
            singer: i['author_name'],
            cover: this.getCover(i['sizable_cover']),
            audioCount: 0,
          ),
        );
      }

      print('最终专辑数量: ${album.length}');
      // print('最终专辑: ${jsonEncode(album)}');

      return album;
    } catch (error) {
      print('getSingerAlbum 异常: $error');
      return [];
    }
  }

  getRecommendMusics(int num) async {
    try {
      var response = await KuGou.dio.get(
        '/everyday/recommend',
        queryParameters: this.params,
      );

      // print('获取推荐音乐响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取推荐歌曲失败: $response.data');
        return [];
      }

      List<Music> musics = [];
      var data = response.data['data']['song_list'];
      // console.log('推荐歌曲数量:', JSON.stringify(data.length))
      print('推荐歌曲数量: ${data.length}');
      // var shuffled = this.shuffleArray(data.map<String>((item) => item['hash'].toString()).toList());
      //
      // num = num > shuffled.length ? shuffled.length : num;
      //
      // var targetIds = shuffled.sublist(0, num);

      final result =
          data.map<String>((item) => item['hash'].toString()).toList()
            ..shuffle();

      // final targetIds = result.take(num).toList();

      num = num > result.length ? result.length : num;
      var targetIds = result.sublist(0, num);

      // print('目标歌曲ID: ${targetIds}');
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
      var response = await KuGou.dio.get(
        '/artist/lists?hotsize=100',
        queryParameters: this.params,
      );

      // print('获取推荐歌手响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取推荐歌手失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Singer> singers = [];

      var data = response.data['data']['info'];
      print('推荐歌手数量: ${data.length}');

      List<String> ids = [];
      for (var i in data) {
        if (i['title'] == '热门') {
          for (var j in i['singer']) {
            if (!ids.contains(j['singerid']) && j['singerid'] != null) {
              ids.add(j['singerid'].toString());
            }
          }
        }
      }
      // var shuffled = this.shuffleArray(ids);
      var shuffled = [...ids]..shuffle();
      num = num > shuffled.length ? shuffled.length : num;
      var targetIds = shuffled.sublist(0, num);

      // final targetIds = shuffled.take(num).toList();

      for (var i in data) {
        if (i['title'] == '热门') {
          for (var j in i['singer']) {
            if (targetIds.contains(j['singerid'].toString())) {
              singers.add(
                Singer(
                  singer: j['singername'],
                  singerId: j['singerid'].toString(),
                  cover: this.getCover(j['imgurl']),
                  audioCount: j['songcount'],
                  albumCount: j['albumcount'],
                ),
              );
            }
          }
          break;
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
      var response = await KuGou.dio.get(
        '/top/ip',
        queryParameters: this.params,
      );

      // print('获取推荐歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取推荐歌单失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Playlist> playlists = [];

      var data = response.data['data']['list'];
      print('推荐歌单数量: ${data.length}');

      // var shuffled = this.shuffleArray(
      //   data
      //       .where((item) => item['extra']?['global_collection_id'] != null)
      //       .map<String>((item) => item['extra']['global_collection_id'].toString())
      //       .toList(),
      // );
      final shuffled =
          data
              .where((item) => item['extra']?['global_collection_id'] != null)
              .map((item) => item['extra']['global_collection_id'].toString())
              .toList()
            ..shuffle();

      num = num > shuffled.length ? shuffled.length : num;
      var targetIds = shuffled.sublist(0, num);

      // final targetIds = shuffled.take(num).toList();

      for (var i in data) {
        // print('当前处理的歌单: ${i}');
        if (targetIds.contains(i['extra']['global_collection_id'])) {
          playlists.add(
            Playlist(
              name: i['title'],
              listId: i['extra']['global_collection_id'],
              audioCount: i['extra']['play_count'],
              cover: this.getCover(i['image_url']),
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
    try {
      var response = await KuGou.dio.get(
        '/search/complex',
        queryParameters: {'keywords': keyword, ...this.params},
      );

      // print('搜索响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取搜索结果失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      List<String> musicIds = [];
      List<Singer> singers = [];
      List<Album> albums = [];

      var data = response.data['data']['lists'];

      for (var i in data) {
        if (i['type'] == 'song') {
          for (var j in i['lists']) {
            if (j['FileHash'] != null) {
              musicIds.add(j['FileHash']);
            }
          }
        } else if (i['type'] == 'author') {
          for (var j in i['lists']) {
            singers.add(
              Singer(
                singer: j['AuthorName'],
                singerId: j['AuthorId'],
                cover: this.getCover(j['Avatar']),
                audioCount: j['AudioCount'],
                albumCount: j['AlbumCount'],
              ),
            );
          }
        } else if (i['type'] == 'album') {
          for (var j in i['lists']) {
            albums.add(
              Album(
                album: j['albumname'],
                albumId: j['albumid'],
                singer: j['singer'],
                cover: this.getCover(j['img']),
                audioCount: 0,
              ),
            );
          }
        }
      }

      // if (!this.management){
      // print('playlistManagement 未初始化');
      // return [];
      // }

      this.management.searchList.singer = singers;
      this.management.searchList.album = albums;

      musics = await this.getMusicsDetails(musicIds);
      this.management.searchList.music = musics;
    } catch (error) {
      print('search 异常: ${error}');
      return [];
    }
  }

  getMusicUrl(String musicId, {String bitrate = '128'}) async {
    try {
      var response = await KuGou.dio.get(
        '/song/url?hash=${musicId}&quality=${bitrate}',
        queryParameters: this.params,
        options: Options(
          headers: {
            'Cookie':
                'token=${this.params['token']}; userid=${this.params['userid']}; dfid=${this.params['dfid']}',
          },
        ),
      );

      // print('获取歌曲播放链接响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌曲播放链接失败: ${jsonEncode(response.data)}');
        return '';
      }

      var musicUrl = response.data['url'][0];

      return musicUrl;
    } catch (error) {
      print('getMusicUrl 异常: ${error}');
      print(
        '获取歌曲播放链接失败url: ${this.mainUrl}/song/url?hash=${musicId}&quality=${bitrate}',
      );
      print('获取歌曲播放链接失败id: ${musicId}');
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> getAlbumAudioId(
    List<String> albumAudioIds,
  ) async {
    if (albumAudioIds.length == 0) {
      return [];
    }

    var id = '';
    for (var i in albumAudioIds) {
      if (i == null || i == '') {
        continue;
      }

      if (id != '') {
        id += ',';
      }
      id += i;
    }

    try {
      var response = await KuGou.dio.get(
        '/krm/audio?album_audio_id=${id}&fields=album_info,base,authors.base',
        queryParameters: this.params,
      );

      // print('获取歌手专辑id响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌手专辑id失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['data'];
      // print('获取歌手专辑id列表: ${jsonEncode(data)}');

      var albumAudioIds = <Map<String, dynamic>>[];

      for (var i in data) {
        albumAudioIds.add({
          'albumId': i['base']['album_id'].toString(),
          'singerId': i['authors'][0]['base']['author_id'].toString(),
          'albumAudioId': i['base']['album_audio_id'].toString(),
        });
      }

      return albumAudioIds;
    } catch (error) {
      print('getAlbumAudioId 异常: ${error}');
      return [];
    }
  }

  Future<List<Music>> getMusicsDetails(List<String> musicIds) async {
    if (musicIds.length == 0) {
      return [];
    }

    var id = '';
    for (var i in musicIds) {
      if (i == null || i == '') {
        continue;
      }
      if (id != '') {
        id += ',';
      }
      id += i;
    }

    try {
      var response = await KuGou.dio.get(
        '/privilege/lite?hash=${id}',
        queryParameters: this.params,
      );

      // print('获取歌曲详情响应: ${jsonEncode(response.data)}');
      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌曲详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];

      var data = response.data['data'];

      var name = '', singer = '', album = '', cover = '';

      var musicData = [];

      for (var i in data) {
        if (i['albumname'] != null) {
          album = i['albumname'];
        } else {
          album = '';
        }

        if (i['name'].contains(' - ')) {
          var arr = i['name'].split(' - ');
          name = arr[1];
          singer = arr[0];
        } else {
          name = i['name'];
          singer = i['singername'];
        }

        if (i['info'] != null && i['info']['image'] != null) {
          cover = i['info']['image'];
        } else {
          if (i['trans_param'] != null &&
              i['trans_param']['union_cover'] != null) {
            cover = i['trans_param']['union_cover'];
          } else {
            cover = '';
          }
        }

        musicData.add({
          'name': name,
          'id': i['hash'],
          'singer': singer,
          'album': album,
          'time': i['info']['duration'],
          'cover': this.getCover(cover),
          'albumAudioId': i['album_audio_id'].toString(),
        });
      }

      var albumAudioIds = musicData
          .map((item) => item['albumAudioId'])
          .whereType<String>()
          .toList();

      var AlbumAudioIdsList = <List<String>>[];

      var num = (albumAudioIds.length / 50).ceil();
      for (var i = 0; i < num; i++) {
        var start = i * 50;
        var end = (i + 1) * 50;
        var slice = albumAudioIds.sublist(
          start,
          end > albumAudioIds.length ? albumAudioIds.length : end,
        );
        AlbumAudioIdsList.add(slice);
      }

      var results = await Future.wait<List<Map<String, dynamic>>>(
        AlbumAudioIdsList.map((ids) => this.getAlbumAudioId(ids)),
      );

      // var albumAudioIdDat = results.reduce((acc, val) => acc.concat(val), []);
      List<Map<String, dynamic>> albumAudioIdData = results
          .expand<Map<String, dynamic>>((list) => list)
          .toList();

      Map<String, dynamic> albumAudioIdMap = {};

      for (final item in albumAudioIdData) {
        albumAudioIdMap[item['albumAudioId']] = item;
      }

      musics = musicData.map((item) {
        final albumAudioIdInfo = albumAudioIdMap[item['albumAudioId']];

        return Music(
          name: item['name'],
          id: item['id'],
          singer: item['singer'],
          singerId: albumAudioIdInfo?['singerId'] ?? '',
          album: item['album'],
          albumId: albumAudioIdInfo?['albumId'] ?? '',
          time: item['time'],
          cover: item['cover'],
        );
      }).toList();

      // musics = musicData.map((item) {
      //   Map<String, dynamic>? albumAudioIdInfo;
      //
      //   for (final info in albumAudioIdData) {
      //     if (info['albumAudioId'] == item['albumAudioId']) {
      //       albumAudioIdInfo = info;
      //       break;
      //     }
      //   }
      //
      //   return Music(
      //     name: item['name'],
      //     id: item['id'],
      //     singer: item['singer'],
      //     singerId: albumAudioIdInfo?['singerId'] ?? '',
      //     album: item['album'],
      //     albumId: albumAudioIdInfo?['albumId'] ?? '',
      //     time: item['time'],
      //     cover: item['cover'],
      //   );
      // }).toList();

      return musics;
    } catch (error) {
      print('getMusicsDetails 异常: $error');
      // print('获取歌曲详情失败id: $musicIds');
      return [];
    }
  }

  getSingerDetails(String singerId) async {
    try {
      var response = await KuGou.dio.get(
        '/artist/detail?id=${singerId}',
        queryParameters: this.params,
      );

      // print('获取歌手详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌手详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['data'];

      Singer singer = Singer(
        singer: data['author_name'],
        singerId: data['author_id'],
        cover: this.getCover(data['sizable_avatar']),
        audioCount: data['song_count'],
        albumCount: data['album_count'],
      );

      return singer;
    } catch (error) {
      print('getSingerDetails 异常: $error');
      return false;
    }
  }

  getAlbumDetails(String albumId) async {
    try {
      var response = await KuGou.dio.get(
        '/album?album_id=${albumId}',
        queryParameters: this.params,
      );

      // print('获取专辑详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取专辑详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['data'][0];

      Album album = Album(
        album: data['album_name'],
        albumId: data['album_id'],
        singer: data['author_name'],
        cover: this.getCover(data['sizable_cover']),
        audioCount: 0,
      );

      return album;
    } catch (error) {
      print('getAlbumDetails 异常: $error');
      return false;
    }
  }

  getPlaylistDetails(String listId) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      var response = await KuGou.dio.get(
        '/playlist/detail?ids=${listId}&timestamp=${timestamp}',
        queryParameters: this.params,
      );

      // print('获取歌单详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌单详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['data'][0];

      Playlist playlist = Playlist(
        name: data['name'],
        listId: data['global_collection_id'],
        audioCount: data['count'],
        cover: this.getCover(data['pic']),
      );

      return playlist;
    } catch (error) {
      print('getPlaylistDetails 异常: $error');
      return false;
    }
  }

  getLyric(String musicId) async {
    var data;
    try {
      var response = await KuGou.dio.get(
        '/search/lyric?hash=${musicId}',
        queryParameters: this.params,
      );

      // print('获取歌曲歌词信息响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 200) {
        print('获取歌曲歌词信息失败: ${jsonEncode(response.data)}');
        return false;
      }

      data = response.data['candidates'][0];
    } catch (error) {
      print('getLyricData 异常: $error');
      return false;
    }

    try {
      // let url: string = `${this.mainUrl}/lyric?id=${data.id}&accesskey=${data.accesskey}&fmt=krc&decode=true`

      // let response: AxiosResponse = await axios.get(url, {
      // params: this.params
      // })

      // if (response.status !== 200 || response.data.status !== 200) {
      // console.log('获取歌曲歌词失败:', response.data)
      // return false
      // }
      var response = await KuGou.dio.get(
        // '/lyric?id=${data['id']}&accesskey=${data['accesskey']}&fmt=krc&decode=true',
        '/lyric?id=${data['id']}&accesskey=${data['accesskey']}&fmt=lrc&decode=true',
        queryParameters: this.params,
      );

      // print('获取歌曲歌词响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 200) {
        print('获取歌曲歌词失败: ${jsonEncode(response.data)}');
        return false;
      }

      String lyric = response.data['decodeContent'] as String;
      // String krc = response.data['decodeContent'] as String;
      // print('获取歌词: ${lyric}');

      lyric = processLyric(lyric);
      // String lyric = krcToLrc(krc);
      // print('获取歌词: ${lyric}');
      return lyric;
    } catch (error) {
      print('getLyric 异常: $error');
      return false;
    }
  }

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {
    var qualityGrade = ['128', '320', 'flac'];
    var url = await this.getMusicUrl(musicId, bitrate: qualityGrade[quality]);
    return url;
  }

  createPlaylist(String name) async {
    try {
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await KuGou.dio.get(
        '/playlist/add?list_create_userid=${this.params['userid']}&timestamp=${timestamp}',
        queryParameters: {'name': name, ...this.params},
      );

      // print('创建歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('创建歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      var listid = response.data['data']['info']['global_collection_id'];
      Playlist playlist = Playlist(
        name: name,
        listId: listid,
        audioCount: 0,
        cover: '',
      );

      this.playlist.add(playlist);
      this.playlist_to_id[listid] = response.data['data']['info']['listid'];

      print('创建歌单成功，歌单id: ${listid}');

      return true;
    } catch (error) {
      print('createPlaylist 异常: $error');
      return false;
    }
  }

  deletePlaylist(String listId) async {
    if (listId == this.collectionListId) {
      print('无法删除收藏歌单');
      return false;
    }

    var timestamp;
    var response;

    try {
      timestamp = DateTime.now().millisecondsSinceEpoch;

      response = await KuGou.dio.get(
        '/playlist/detail?ids=${listId}&timestamp=${timestamp}',
        queryParameters: this.params,
      );

      // print('获取歌单详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('获取歌单详情失败: ${jsonEncode(response.data)}');
        return false;
      }

      var id = response.data['data'][0]['listid'];
      print('获取歌单详情成功，歌单id: ${id}');

      timestamp = DateTime.now().millisecondsSinceEpoch;

      response = await KuGou.dio.get(
        '/playlist/del?listid=${id}&timestamp=${timestamp}',
        queryParameters: this.params,
      );

      // print('删除歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('删除歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      // for (var i = 0; i < this.playlist.length; i++) {
      //   if (this.playlist[i].listId == listId) {
      //     this.playlist.removeAt(i);
      //     break;
      //   }
      // }

      // int index = playlist.indexWhere((item) => item.listId == listId);
      // if (index != -1) {
      //   playlist.removeAt(index);
      // }
      playlist.removeWhere((item) => item.listId == listId);

      print('删除歌单成功，歌单id: ${listId}');

      return true;
    } catch (error) {
      print('deleteMusicFromPlaylist 异常: $error');
      return false;
    }
  }

  addMusicToPlaylist(String listId, String musicId) async {
    try {
      List<Music> music = await this.getMusicsDetails([musicId]);
      if (music.length == 0) {
        print('获取歌曲详情失败，无法添加到歌单，歌曲id: ${musicId}');
        return false;
      }
      var data = '${music[0].name}|${music[0].id}|${music[0].albumId}';

      var id = this.playlist_to_id[listId] ?? listId;
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await KuGou.dio.get(
        '/playlist/tracks/add?listid=${id}&timestamp=${timestamp}',
        queryParameters: {'data': data, ...this.params},
      );

      // print('添加歌曲到歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('添加歌曲到歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

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
      var fileids = await this.getMusicInPlaylistFileid(listId, musicId);
      if (fileids == '') {
        print('获取歌单内歌曲文件id失败，无法从歌单删除，歌曲id: ${musicId}, 歌单id: ${listId}');
        return false;
      }

      var id = this.playlist_to_id[listId] ?? listId;
      var timestamp = DateTime.now().millisecondsSinceEpoch;

      var response = await KuGou.dio.get(
        '/playlist/tracks/del?listid=${id}&fileids=${fileids}&timestamp=${timestamp}',
        queryParameters: this.params,
      );

      // print('从歌单删除歌曲响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 || response.data["status"] != 1) {
        print('从歌单删除歌曲失败: ${jsonEncode(response.data)}');
        return false;
      }

      // if (listId == this.collectionListId) {
      //   var index = this.collectionList.indexOf(musicId);
      //   if (index != -1) {
      //     this.collectionList.removeAt(index);
      //     print('音乐成功从我喜欢歌单删除，音乐id: ${musicId}')
      //   } else {
      //     print('音乐不在我喜欢歌单中，无需删除，音乐id: ${musicId}')
      //   }
      // }

      if (listId == this.collectionListId) {
        if (this.collectionList.remove(musicId)) {
          print('音乐成功从我喜欢歌单删除，音乐id: $musicId');
        } else {
          print('音乐不在我喜欢歌单中，无需删除，音乐id: $musicId');
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

  getMusicInPlaylistFileid(String listId, String musicId) async {
    try {
      var n = 0;
      // let url: string
      var timestamp;
      var response;

      while (true) {
        try {
          timestamp = DateTime.now().millisecondsSinceEpoch;

          response = await KuGou.dio.get(
            '/playlist/track/all?id=${listId}&pagesize=300&page=${n + 1}&timestamp=${timestamp}',
            queryParameters: this.params,
          );

          // print('获取歌单歌曲响应: ${jsonEncode(response.data)}');

          if (response.statusCode != 200 || response.data["status"] != 1) {
            print('获取歌单歌曲失败: ${jsonEncode(response.data)}');
            return '';
          }

          if (response.data['data']['songs'].length == 0) {
            break;
          }

          var data = response.data['data']['songs'];

          for (var i in data) {
            if (i['hash'] == musicId) {
              print('找到目标歌曲，文件id: ${i['hash']}, 所在歌单位置: ${i['fileid']}');
              return i['fileid'];
            }
          }

          n++;
        } catch (error) {
          print('etPlaylistMusic 异常: ${error}');
          break;
        }
      }

      return '';
    } catch (error) {
      print('getMusicInPlaylistFileid 异常: ${error}');
      return '';
    }
  }

  processLyric(String lrcContent) {
    if (lrcContent.isEmpty) return '';

    return lrcContent
        .split('\n')
        .where((line) {
          final trimmed = line.trim();

          // 只保留包含时间标签 [00:00.000] 的行
          // 自动排除 [id:], [ar:], [ti:], [by:] 等元数据
          return RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]').hasMatch(trimmed);
        })
        .map((line) {
          // 标准化格式：
          // [00:01.23] -> 这里保持原样
          // [00:01.234] -> 这里也保持原样
          return line.replaceAllMapped(
            RegExp(r'\[(\d{2}):(\d{2})\.(\d{3})\]'),
            (match) =>
                '[${match.group(1)}:${match.group(2)}.${match.group(3)}]',
          );
        })
        .join('\n');
  }

  krcToLrc(String krc) {
    String lrc = '';

    // 匹配行级时间戳和句子内容：[开始毫秒,持续时间]句子
    final sentenceRegex = RegExp(r'\[(\d+),\d+\](.*)');
    // 匹配逐字时间戳和字符：<偏移毫秒,持续时间,?>字符
    const charRegexSource = r'<(\d+),\d+,\d+>([^<]+)';

    // 使用 allMatches 遍历所有句子（等价于 JS 中 exec 循环）
    for (final sentenceMatch in sentenceRegex.allMatches(krc)) {
      final time = int.parse(sentenceMatch.group(1)!); // 该句起始时间（毫秒）
      final sentence = sentenceMatch.group(2)!; // 句子内容（含逐字标签）
      var characters = '';

      // 处理当前句子内的所有逐字标签
      final charRegex = RegExp(charRegexSource);
      for (final charMatch in charRegex.allMatches(sentence)) {
        final timeCharacter = int.parse(charMatch.group(1)!); // 相对于句首的偏移毫秒
        final char = charMatch.group(2)!;

        if (char.isEmpty) {
          continue; // 过滤空字符
        }

        final absoluteTime = time + timeCharacter;
        characters += '<${msToLrcTime(absoluteTime)}>$char';
        // characters += char;
      }

      // 拼接行级时间戳与所有逐字内容
      lrc += '[${msToLrcTime(time)}]$characters\n';
    }

    return lrc;
  }

  /// 将毫秒转换为 LRC 时间格式：mm:ss.xx
  msToLrcTime(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final centiseconds = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }

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
