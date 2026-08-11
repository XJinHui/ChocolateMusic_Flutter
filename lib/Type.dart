class Music {
  // 歌曲ID
  final String id;

  // 歌曲名
  final String name;

  // 歌手名
  final String singer;

  // 歌手ID
  final String singerId;

  // 专辑名
  final String album;

  // 专辑ID
  final String albumId;

  // 歌曲时长
  final int time;

  // final bool like;
  // 封面图片路径
  final String cover;

  Music({
    required this.id,
    required this.name,
    required this.singer,
    required this.singerId,
    required this.album,
    required this.albumId,
    required this.time,
    // required this.like,
    required this.cover,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'singer': singer,
      'singerId': singerId,
      'album': album,
      'albumId': albumId,
      'time': time,
      'cover': cover,
    };
  }

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] as String,
      name: json['name'] as String,
      singer: json['singer'] as String,
      singerId: json['singerId'] as String,
      album: json['album'] as String,
      albumId: json['albumId'] as String,
      time: json['time'] as int,
      cover: json['cover'] as String,
    );
  }
}

class Playlist {
  // 歌单名
  final String name;

  // 歌单ID
  final String listId;

  // 封面图片路径
  final String cover;

  // 歌曲数
  final int audioCount;

  Playlist({
    required this.name,
    required this.listId,
    required this.cover,
    required this.audioCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'listId': listId,
      'cover': cover,
      'audioCount': audioCount,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'] as String,
      listId: json['listId'] as String,
      cover: json['cover'] as String,
      audioCount: json['audioCount'] as int,
    );
  }
}

class Singer {
  // 歌手名
  final String singer;

  // 歌手ID
  final String singerId;

  // 封面图片路径
  final String cover;

  // 歌曲数
  final int audioCount;

  // 专辑数
  final int albumCount;

  Singer({
    required this.singer,
    required this.singerId,
    required this.cover,
    required this.audioCount,
    required this.albumCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'singer': singer,
      'singerId': singerId,
      'cover': cover,
      'audioCount': audioCount,
      'albumCount': albumCount,
    };
  }

  factory Singer.fromJson(Map<String, dynamic> json) {
    return Singer(
      singer: json['singer'] as String,
      singerId: json['singerId'] as String,
      cover: json['cover'] as String,
      audioCount: json['audioCount'] as int,
      albumCount: json['albumCount'] as int,
    );
  }
}

class Album {
  // 专辑名
  final String album;

  // 专辑ID
  final String albumId;

  // 专辑歌手
  final String singer;

  // 封面图片路径
  final String cover;

  // 歌曲数
  final int audioCount;

  Album({
    required this.album,
    required this.albumId,
    required this.singer,
    required this.cover,
    required this.audioCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'album': album,
      'albumId': albumId,
      'singer': singer,
      'cover': cover,
      'audioCount': audioCount,
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      album: json['album'] as String,
      albumId: json['albumId'] as String,
      singer: json['singer'] as String,
      cover: json['cover'] as String,
      audioCount: json['audioCount'] as int,
    );
  }
}

class Setting {
  // 歌曲名
  String name;

  // 歌手名
  String singer;

  // 歌手ID
  String singerId;

  // 专辑名
  String album;

  // 专辑ID
  String albumId;

  // 时长（格式如 "00:00"）
  String time;

  // 封面图片路径
  String cover;

  // 是否点赞/收藏
  bool like;

  // 歌曲ID
  String id;

  // 播放类型（0 可作为默认值，数字类型）(0 -> 顺序播放，1 -> 随机播放，2 -> 单曲循环)
  int playType;

  // 音量大小（100 为默认值，数字类型）
  double volume;

  // 音量类型（布尔值，可理解为「是否静音/音量模式」等）
  bool volumeType;

  // 是否正在播放
  bool play;

  // 所属播放列表ID（-1 为默认值，字符串类型）
  String playlistId;

  // 播放列表类型（0 -> 歌单， 1 -> 专辑， 2 -> 歌手）
  int playlistType;

  // 音质等级 (0 -> 标准， 1 -> 高品质， 2 -> 无损)
  int qualityTier;

  // 下载音质等级 (0 -> 标准， 1 -> 高品质， 2 -> 无损)
  int downloadQualityTier;

  Setting({
    required this.name,
    required this.singer,
    required this.singerId,
    required this.album,
    required this.albumId,
    required this.time,
    required this.cover,
    required this.like,
    required this.id,
    required this.playType,
    required this.volume,
    required this.volumeType,
    required this.play,
    required this.playlistId,
    required this.playlistType,
    required this.qualityTier,
    required this.downloadQualityTier,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'singer': singer,
      'singerId': singerId,
      'album': album,
      'albumId': albumId,
      'time': time,
      'cover': cover,
      'like': like,
      'id': id,
      'playType': playType,
      'volume': volume,
      'volumeType': volumeType,
      'play': play,
      'playlistId': playlistId,
      'playlistType': playlistType,
      'qualityTier': qualityTier,
      'downloadQualityTier': downloadQualityTier,
    };
  }

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      name: json['name'],
      singer: json['singer'],
      singerId: json['singerId'],
      album: json['album'],
      albumId: json['albumId'],
      time: json['time'],
      cover: json['cover'],
      like: json['like'],
      id: json['id'],
      playType: json['playType'],
      volume: json['volume'],
      volumeType: json['volumeType'],
      play: json['play'],
      playlistId: json['playlistId'],
      playlistType: json['playlistType'],
      qualityTier: json['qualityTier'],
      downloadQualityTier: json['downloadQualityTier'],
    );
  }
}

class KugouData {
  String token;
  String userid;
  int t_expire_time;
  String cover;
  String nickname;
  String dfid;
  String url;

  KugouData({
    required this.token,
    required this.userid,
    required this.t_expire_time,
    required this.cover,
    required this.nickname,
    required this.dfid,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userid': userid,
      't_expire_time': t_expire_time,
      'cover': cover,
      'nickname': nickname,
      'dfid': dfid,
      'url': url,
    };
  }

  factory KugouData.fromJson(Map<String, dynamic> json) {
    return KugouData(
      token: json['token'],
      userid: json['userid'],
      t_expire_time: json['t_expire_time'],
      cover: json['cover'],
      nickname: json['nickname'],
      dfid: json['dfid'],
      url: json['url'],
    );
  }
}

class NavidromeData {
  String u;
  String t;
  String p;
  String s;
  String v = "1.16.1";
  String c = "ChocolateMusic";
  String f = "json";
  String name;
  String url;

  NavidromeData({
    required this.u,
    required this.t,
    required this.p,
    required this.s,
    // required this.v,
    // required this.c,
    // required this.f,
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'u': u,
      't': t,
      'p': p,
      's': s,
      'v': v,
      'c': c,
      'f': f,
      'name': name,
      'url': url,
    };
  }

  factory NavidromeData.fromJson(Map<String, dynamic> json) {
    return NavidromeData(
      u: json['u'],
      t: json['t'],
      p: json['p'],
      s: json['s'],
      // v: json['v'],
      // c: json['c'],
      // f: json['f'],
      name: json['name'],
      url: json['url'],
    );
  }
}

class NetEaseCloudData {
  String cookies;
  int loginType;
  String token;
  String userid;
  String cover;
  String nickname;
  String url;

  NetEaseCloudData({
    required this.cookies,
    required this.loginType,
    required this.token,
    required this.userid,
    required this.cover,
    required this.nickname,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'cookies': cookies,
      'loginType': loginType,
      'token': token,
      'userid': userid,
      'cover': cover,
      'nickname': nickname,
      'url': url,
    };
  }

  factory NetEaseCloudData.fromJson(Map<String, dynamic> json) {
    return NetEaseCloudData(
      cookies: json['cookies'],
      loginType: json['loginType'],
      token: json['token'],
      userid: json['userid'],
      cover: json['cover'],
      nickname: json['nickname'],
      url: json['url'],
    );
  }
}

class Account {
  String cover = '';
  String nickname = '';
  String type = '';

  Account({required this.cover, required this.nickname, required this.type});
}

// class IAccountData {
//   List<int> login;
//   List<List<dynamic>> data;
//
//   IAccountData({
//     required this.login,
//     required this.data,
//   });
// }

class AccountData {
  List<int> login = [-1, -1];
  List<List<dynamic>> data = [[], [], []];

  AccountData({required this.login, required this.data});

  void update(AccountData newData) {
    this.login = newData.login;
    this.data = newData.data;
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'data': [
        data[0].cast<KugouData>().map((item) => item.toJson()).toList(),
        data[1].cast<NetEaseCloudData>().map((item) => item.toJson()).toList(),
        data[2].cast<NavidromeData>().map((item) => item.toJson()).toList(),
      ],
    };
  }

  factory AccountData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> jsonData = json['data'] as List<dynamic>;

    return AccountData(
      login: List<int>.from(json['login'] as List<dynamic>),
      data: [
        (jsonData[0] as List<dynamic>)
            .map(
              (item) =>
                  KugouData.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        (jsonData[1] as List<dynamic>)
            .map(
              (item) => NetEaseCloudData.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        (jsonData[2] as List<dynamic>)
            .map(
              (item) => NavidromeData.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      ],
    );
  }
}

class RecommendList {
  List<Album> album;
  List<Singer> singer;
  List<Music> music;
  List<Playlist> playlist;

  RecommendList({
    List<Album>? album,
    List<Singer>? singer,
    List<Music>? music,
    List<Playlist>? playlist,
  }) : album = album ?? [],
       singer = singer ?? [],
       music = music ?? [],
       playlist = playlist ?? [];

  Map<String, dynamic> toJson() {
    return {
      'album': album.map((item) => item.toJson()).toList(),
      'singer': singer.map((item) => item.toJson()).toList(),
      'music': music.map((item) => item.toJson()).toList(),
      'playlist': playlist.map((item) => item.toJson()).toList(),
    };
  }

  factory RecommendList.fromJson(Map<String, dynamic> json) {
    return RecommendList(
      album: (json['album'] as List<dynamic>)
          .map((item) => Album.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      singer: (json['singer'] as List<dynamic>)
          .map(
            (item) => Singer.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      music: (json['music'] as List<dynamic>)
          .map((item) => Music.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      playlist: (json['playlist'] as List<dynamic>)
          .map(
            (item) => Playlist.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
