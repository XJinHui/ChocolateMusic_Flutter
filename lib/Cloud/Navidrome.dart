import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'dart:math';

import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';

class Navidrome implements CloudService {
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

    Navidrome.dio.options.baseUrl = this.mainUrl;

    await this.getData();
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
      url: mainUrl,
    );

    if (!await this.checkLogin(params)) {
      print('登录失败');
      return false;
    }

    var list = this.accountData.data[2];
    list.add(params);
    var num = list.length - 1; // 添加后的索引（即原来的长度）
    this.accountData.data[2][num] = params;

    this.accountData.login = [2, num];

    this.mainUrl = mainUrl;
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
      var response = await dio.get(url, queryParameters: params.toJson());
      print(response.data);
      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
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

  getCollectionList() async {
    try {
      var response = await Navidrome.dio.get(
        '/getStarred2.view',
        queryParameters: this.params.toJson(),
      );

      // print('我喜欢歌单详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('我喜欢歌单详情失败: ${jsonEncode(response.data)}');
        return;
      }

      var data = response.data['subsonic-response']['starred2']['song'];

      if (data != null) {
        for (var i in data) {
          if (i['coverArt'] != null) {
            this.collectionList.add(i['id']);
          }
        }
      }

      print('收藏歌曲数量: ${this.collectionList.length}');
    } catch (error) {
      print('getCollectionList 异常: $error');
    }
  }

  Future<List<Playlist>> getPlaylist() async {
    try {
      var response = await Navidrome.dio.get(
        '/getPlaylists.view',
        queryParameters: this.params.toJson(),
      );

      // print('获取歌单列表响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取歌单列表失败: ${jsonEncode(response.data)}');
        return [];
      }
      var data = response.data['subsonic-response']['playlists']['playlist'];

      List<String> playlistIds = ['starred'];

      if (data != null) {
        for (var i in data) {
          playlistIds.add(i['id']);
        }
      }

      List<Future<Playlist?>> futures = playlistIds
          .map((id) => getPlaylistDetails(id))
          .toList();
      List<Playlist?> results = await Future.wait(futures);

      List<Playlist> playlists = [];
      for (var playlist in results) {
        if (playlist != null) {
          playlists.add(playlist);
        }
      }

      this.playlist = playlists;

      this.management.playlists = this.playlist;
      print('获取歌单列表成功: ${this.playlist.length} 个歌单');
      return playlists;
    } catch (error) {
      print('getPlaylist 异常: $error');
      return [];
    }
  }

  getPlaylistMusic(String listId) async {
    try {
      if (listId == 'starred') {
        var response = await Navidrome.dio.get(
          '/getStarred2.view',
          queryParameters: this.params.toJson(),
        );

        // print('获取我喜欢音乐响应: ${jsonEncode(response.data)}');

        if (response.statusCode != 200 ||
            response.data['subsonic-response']['status'] != 'ok') {
          print('获取我喜欢音乐失败: ${jsonEncode(response.data)}');
          return [];
        }

        var data = response.data['subsonic-response']['starred2']['song'];
        List<Music> musics = [];

        for (var i in data) {
          var cover = '';
          if (i['coverArt'] != null) {
            cover = this.getCover(i['coverArt']);
          }

          musics.add(
            Music(
              id: i['id'],
              name: i['title'],
              singer: i['artist'],
              singerId: i['artistId'],
              album: i['album'],
              albumId: i['albumId'],
              cover: cover,
              time: i['duration'] * 1000,
            ),
          );
        }

        // return this.getSingerMusic(this.collectionListId)
        return musics;
      } else {
        var response = await Navidrome.dio.get(
          '/getPlaylist.view?id=${listId}',
          queryParameters: this.params.toJson(),
        );

        // print('获取歌单音乐响应: ${jsonEncode(response.data)}');

        if (response.statusCode != 200 ||
            response.data['subsonic-response']['status'] != 'ok') {
          print('获取歌单音乐失败: ${jsonEncode(response.data)}');
          return [];
        }

        var data = response.data['subsonic-response']['playlist']?['entry'];

        if (data == null) {
          print('歌单内歌曲数量为 0');
          return [];
        }

        List<Music> musics = [];

        for (var i in data) {
          var cover = '';
          if (i['coverArt'] != null) {
            cover = this.getCover(i['coverArt']);
          }

          musics.add(
            Music(
              id: i['id'],
              name: i['title'],
              singer: i['artist'],
              singerId: i['artistId'],
              album: i['album'],
              albumId: i['albumId'],
              cover: cover,
              time: i['duration'] * 1000,
            ),
          );
        }

        // return this.getAlbumMusic(listId)
        return musics;
      }
    } catch (error) {
      print('getPlaylistMusic 异常: $error');
      return [];
    }
  }

  getSingerMusic(String singerId) async {
    try {
      List<Album> albums = await this.getSingerAlbum(singerId);

      var results = await Future.wait(
        albums.map((item) => this.getAlbumMusic(item.albumId)),
      );

      List<Music> musics = [];

      for (var i in results) {
        musics.addAll(i);
      }

      // print('最终歌手音乐列表: ${jsonEncode(musics)}');

      return musics;
    } catch (error) {
      print('getSingerMusic 异常: $error');
      return [];
    }
  }

  Future<List<Music>> getAlbumMusic(String albumId) async {
    try {
      var response = await Navidrome.dio.get(
        '/getAlbum.view?id=${albumId}',
        queryParameters: this.params.toJson(),
      );

      // print('获取专辑音乐响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取专辑音乐失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['album']['song'];
      List<Music> musics = [];

      for (var i in data) {
        var cover = '';
        if (i['coverArt'] != null) {
          cover = this.getCover(i['coverArt']);
        }

        musics.add(
          Music(
            id: i['id'],
            name: i['title'],
            singer: i['artist'],
            singerId: i['artistId'],
            album: i['album'],
            albumId: i['albumId'],
            cover: cover,
            time: i['duration'] * 1000,
          ),
        );
      }

      return musics;
    } catch (error) {
      print('getAlbumMusic 异常: $error');
      return [];
    }
  }

  getSingerAlbum(String singerId) async {
    try {
      var response = await Navidrome.dio.get(
        '/getArtist.view?id=${singerId}',
        queryParameters: this.params.toJson(),
      );

      // print('获取歌手专辑响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取歌手专辑失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['artist']['album'];
      List<Album> albums = [];

      for (var i in data) {
        var cover = '';
        if (i['coverArt'] != null) {
          cover = this.getCover(i['coverArt']);
        }

        albums.add(
          Album(
            albumId: i['id'],
            album: i['name'],
            singer: i['artist'],
            cover: cover,
            audioCount: 0,
          ),
        );
      }

      return albums;
    } catch (error) {
      print('getSingerAlbum 异常: $error');
      return [];
    }
  }

  getRecommendMusics(int num) async {
    try {
      var response = await Navidrome.dio.get(
        '/getRandomSongs.view?size=${num}',
        queryParameters: this.params.toJson(),
      );

      // print('获取推荐音乐响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取推荐音乐失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['randomSongs']['song'];

      List<Music> musics = [];

      for (var i in data) {
        var cover = '';
        if (i['coverArt'] != null) {
          cover = this.getCover(i['coverArt']);
        }
        musics.add(
          Music(
            id: i['id'],
            name: i['title'],
            singer: i['artist'],
            singerId: i['artistId'] ?? '',
            album: i['album'],
            albumId: i['albumId'],
            cover: cover,
            time: i['duration'] * 1000,
          ),
        );
      }

      // print(jsonEncode(musics));
      return musics;
    } catch (error) {
      print('getRecommendMusics 异常: $error');
      return [];
    }
  }

  getRecommendSingers(int num) async {
    try {
      var response = await Navidrome.dio.get(
        '/getArtists.view',
        queryParameters: this.params.toJson(),
      );

      // print('获取推荐歌手响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取推荐歌手失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['artists']['index'];

      List<Singer> singerAll = [];
      List<Singer> singer = [];

      for (var i in data) {
        for (var j in i['artist']) {
          var cover = '';
          if (j['coverArt'] != null) {
            cover = this.getCover(j['coverArt']);
          }

          singerAll.add(
            Singer(
              singerId: j['id'],
              singer: j['name'],
              cover: cover,
              albumCount: j['albumCount'],
              audioCount: 0,
            ),
          );
        }
      }

      final randomSingers = [...singerAll]..shuffle();

      num = num > randomSingers.length ? randomSingers.length : num;
      var randomIds = randomSingers.sublist(0, num);
      singer.addAll(randomIds);

      // singer.addAll(randomSingers.take(num));

      // print('最终推荐歌手列表: ${jsonEncode(singer)}');
      return singer;
    } catch (error) {
      print('getRecommendSingers 异常: $error');
      return [];
    }
  }

  getRecommendAlbum(int num) async {
    try {
      var response = await Navidrome.dio.get(
        '/getAlbumList2.view?type=random&size=${num}',
        queryParameters: this.params.toJson(),
      );

      // print('获取推荐专辑响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取推荐专辑失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['albumList2']['album'];

      List<Album> albums = [];

      for (var i in data) {
        var cover = '';
        if (i['coverArt'] != null) {
          cover = this.getCover(i['coverArt']);
        }

        albums.add(
          Album(
            albumId: i['id'],
            album: i['name'],
            singer: i['artist'],
            cover: cover,
            audioCount: 0,
          ),
        );
      }

      // print('最终推荐专辑列表: ${jsonEncode(albums)}');
      return albums;
    } catch (error) {
      print('getRecommendAlbum 异常: $error');
      return [];
    }
  }

  getRecommendPlaylists(int num) async {}

  search(String keyword) async {
    try {
      var response = await Navidrome.dio.get(
        '/search3.view',
        queryParameters: {'query': keyword, ...this.params.toJson()},
      );

      // print('搜索响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取搜索结果失败: ${jsonEncode(response.data)}');
        return [];
      }

      List<Music> musics = [];
      // List<String> musicIds = [];
      List<Singer> singers = [];
      List<Album> albums = [];

      var data = response.data['subsonic-response']['searchResult3'];
      // print('搜索结果数据: ${jsonEncode(data)}');

      if (data['song'] != null) {
        for (var i in data['song']) {
          var cover = '';
          if (i['coverArt'] != null) {
            cover = this.getCover(i['coverArt']);
          }

          musics.add(
            Music(
              id: i['id'],
              name: i['title'],
              singer: i['artist'],
              singerId: i['artistId'],
              album: i['album'],
              albumId: i['albumId'],
              cover: cover,
              time: i['duration'] * 1000,
            ),
          );

          // musicIds.push(i['id']);
        }
      }

      if (data['artist'] != null) {
        for (var i in data['artist']) {
          var cover = '';
          if (i['coverArt'] != null) {
            cover = this.getCover(i['coverArt']);
          }

          singers.add(
            Singer(
              singerId: i['id'],
              singer: i['name'],
              cover: cover,
              albumCount: i['albumCount'],
              audioCount: 0,
            ),
          );
        }
      }

      if (data['album'] != null) {
        for (var i in data['album']) {
          var cover = '';
          if (i['coverArt'] != null) {
            cover = this.getCover(i['coverArt']);
          }

          albums.add(
            Album(
              albumId: i['id'],
              album: i['name'],
              singer: i['artist'],
              cover: cover,
              audioCount: 0,
            ),
          );
        }
      }

      // if (!this.playlistManagement){
      // console.error('playlistManagement 未初始化')
      // return
      // }

      this.management.searchList.singer = singers;
      this.management.searchList.album = albums;

      // musics = await this.getMusicsDetails(musicIds)
      this.management.searchList.music = musics;
    } catch (error) {
      print('search 异常: $error');
      return;
    }
  }

  getMusicUrl(String musicId, {String bitrate = '128'}) async {
    try {
      final uri = Uri.parse('${this.mainUrl}/stream.view').replace(
        queryParameters: {
          ...this.params.toJson().map(
            (key, value) => MapEntry(key, value.toString()),
          ),
          'id': musicId.toString(),
          'maxBitRate': bitrate.toString(),
        },
      );

      final url = uri.toString();

      print('最终获取歌曲播放链接url: $url');
      return url;
    } catch (error) {
      print('getMusicUrl 异常: $error');
      print(
        '获取歌曲播放链接失败url: ${this.mainUrl}/stream.view?id=${musicId}&maxBitRate=${bitrate}',
      );
      print('获取歌曲播放链接失败id: $musicId');
      return '';
    }
  }

  getMusicDetails(String musicId) async {
    try {
      var response = await Navidrome.dio.get(
        '/getSong.view?id=${musicId}',
        queryParameters: this.params.toJson(),
      );

      // print('获取歌曲详情响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取歌曲详情失败: ${jsonEncode(response.data)}');
        return [];
      }

      var data = response.data['subsonic-response']['song'];

      var music = Music(
        id: data['id'],
        name: data['title'],
        singer: data['artist'],
        singerId: data['artistId'],
        album: data['album'],
        albumId: data['albumId'],
        cover: data['coverArt'] != null ? this.getCover(data['coverArt']) : '',
        time: data['duration'],
      );

      return music;
    } catch (error) {
      print('getMusicDetails 异常: $error');
      return false;
    }
  }

  Future<List<Music>> getMusicsDetails(List<String> musicIds) async {
    List<Music> musics = [];
    var results = await Future.wait(
      musicIds.map((id) => this.getMusicDetails(id)),
    );

    for (var i in results) {
      if (i != null) {
        musics.add(i);
      }
    }

    return musics;
  }

  getSingerDetails(String singerId) async {}

  getAlbumDetails(String albumId) async {}

  Future<Playlist?> getPlaylistDetails(String listId) async {
    // let url: string
    // let playlist: Playlist
    Playlist? playlist;
    try {
      if (listId == 'starred') {
        var response = await Navidrome.dio.get(
          '/getStarred2.view',
          queryParameters: this.params.toJson(),
        );

        // print('我喜欢歌单详情响应: ${jsonEncode(response.data)}');

        if (response.statusCode != 200 ||
            response.data['subsonic-response']['status'] != 'ok') {
          print('我喜欢歌单详情失败: ${jsonEncode(response.data)}');
          return null;
        }

        final dynamic rawSongs =
            response.data['subsonic-response']['starred2']['song'];
        final List<dynamic> songs = rawSongs is List
            ? List<dynamic>.from(rawSongs)
            : rawSongs is Map
            ? <dynamic>[rawSongs]
            : const <dynamic>[];

        if (songs.isNotEmpty) {
          final dynamic firstSong = songs.first;
          final String coverArt = firstSong is Map
              ? firstSong['coverArt']?.toString() ?? ''
              : '';
          final dynamic coverValue = coverArt.isEmpty
              ? ''
              : this.getCover(coverArt);
          playlist = Playlist(
            name: '我喜欢',
            listId: 'starred',
            audioCount: songs.length,
            cover: coverValue is String ? coverValue : '',
          );
        } else {
          playlist = Playlist(
            name: '我喜欢',
            listId: 'starred',
            audioCount: 0,
            cover: '',
          );
        }
      } else {
        var response = await Navidrome.dio.get(
          '/getPlaylist.view?id=${listId}',
          queryParameters: this.params.toJson(),
        );

        // print('获取歌单详情响应: ${jsonEncode(response.data)}');

        if (response.statusCode != 200 ||
            response.data['subsonic-response']['status'] != 'ok') {
          print('获取歌单详情失败: ${jsonEncode(response.data)}');
          return null;
        }

        var data = response.data['subsonic-response']['playlist'];

        if (data is! Map) {
          return null;
        }

        var cover = '';

        final dynamic entries = data['entry'];
        final dynamic firstEntry = entries is List && entries.isNotEmpty
            ? entries.first
            : entries is Map
            ? entries
            : null;
        if (firstEntry is Map) {
          final dynamic coverArt = firstEntry['coverArt'];
          if (coverArt != null && coverArt.toString().isNotEmpty) {
            final dynamic coverValue = this.getCover(coverArt.toString());
            if (coverValue is String) {
              cover = coverValue;
            }
          }
        }

        playlist = Playlist(
          name: data['name']?.toString() ?? '',
          listId: data['id']?.toString() ?? listId,
          cover: cover,
          audioCount: data['songCount'] is num
              ? (data['songCount'] as num).toInt()
              : 0,
        );
      }

      return playlist;
    } catch (error) {
      print('getPlaylistDetails 异常: ${error}');
      return null;
    }
  }

  getLyric(String musicId) async {
    try {
      var response = await Navidrome.dio.get(
        '/getLyricsBySongId.view?id=${musicId}',
        queryParameters: this.params.toJson(),
      );

      print('获取歌词响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('获取歌词失败: ${jsonEncode(response.data)}');
        return false;
      }

      var data = response
          .data['subsonic-response']['lyricsList']['structuredLyrics'][0]['line'];
      var lyric = '';

      for (var i in data) {
        var minutes = i['start'] ~/ 60000;
        var seconds = (i['start'] % 60000) ~/ 1000;
        var centiseconds = (i['start'] % 1000) ~/ 10;
        lyric +=
            '[${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}]${i['value']}\n';
      }

      return lyric;
    } catch (error) {
      print('getLyric 异常: ${error}');
      return '';
    }
  }

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {
    var qualityGrade = ['128', '320', ''];
    var url = this.getMusicUrl(musicId, bitrate: qualityGrade[quality]);
    return url;
  }

  createPlaylist(String name) async {
    try {
      var response = await Navidrome.dio.get(
        '/createPlaylist.view',
        queryParameters: {'name': name, ...this.params.toJson()},
      );

      // print('创建歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('创建歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      var listid = response.data['subsonic-response']['playlist']['id'];
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
    if (listId == 'starred') {
      print('无法删除我喜欢歌单');
      return false;
    }
    try {
      var response = await Navidrome.dio.get(
        '/deletePlaylist.view?id=${listId}',
        queryParameters: this.params.toJson(),
      );

      // print('删除歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
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
      List<Music> musics = await this.getPlaylistMusic(listId);
      if (musics.any((item) => item.id == musicId)) {
        print('音乐已在歌单中，无需重复添加，音乐id: $musicId, 歌单id: $listId');
        return true;
      }

      var url;
      if (listId == 'starred') {
        url = '/star.view?id=${musicId}';
      } else {
        url =
            '/updatePlaylist.view?playlistId=${listId}&songIdToAdd=${musicId}';
      }

      var response = await Navidrome.dio.get(
        url,
        queryParameters: {
          'u': this.params.u,
          't': this.params.t,
          'p': this.params.p,
          's': this.params.s,
          'v': "1.16.1",
          'c': "ChocolateMusic",
          'f': "json",
        },
      );

      // print('删除歌单响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('添加到歌单失败: ${jsonEncode(response.data)}');
        return false;
      }

      print('添加到歌单成功，音乐id: ${musicId}');

      if (listId == 'starred') {
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
      var url;
      if (listId == 'starred') {
        url = '/unstar.view?id=${musicId}';
      } else {
        url =
            '/updatePlaylist.view?playlistId=${listId}&songIndexToRemove=${musicId}';
      }

      var response = await Navidrome.dio.get(
        url,
        queryParameters: {
          'u': this.params.u,
          't': this.params.t,
          'p': this.params.p,
          's': this.params.s,
          'v': "1.16.1",
          'c': "ChocolateMusic",
          'f': "json",
        },
      );

      // print('从歌单删除音乐响应: ${jsonEncode(response.data)}');

      if (response.statusCode != 200 ||
          response.data['subsonic-response']['status'] != 'ok') {
        print('从歌单删除音乐失败: ${jsonEncode(response.data)}');
        return false;
      }

      print('从歌单删除音乐成功，音乐id: ${musicId}');

      // if (listId == 'starred') {
      //   var index = this.collectionList.indexOf(musicId);
      //   if (index != -1) {
      //     this.collectionList.removeAt(index);
      //     print('音乐成功从我喜欢歌单中删除，音乐id: ${musicId}');
      //   } else {
      //     print('音乐不在我喜欢歌单中，无需删除，音乐id: ${musicId}');
      //   }
      // }

      if (listId == 'starred') {
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

  String getCover(String coverId, {String size = '500'}) {
    final baseUrl =
        '${this.mainUrl.replaceFirst(RegExp(r'/$'), '')}/getCoverArt.view';
    final queryParameters = <String, String>{
      ...this.params.toJson().map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      'id': coverId,
      'size': size,
    };

    return Uri.parse(
      baseUrl,
    ).replace(queryParameters: queryParameters).toString();
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
