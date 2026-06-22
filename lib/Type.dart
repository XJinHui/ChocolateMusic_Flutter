class Music{
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
}

class Playlist{
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
}

class Singer{
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
}

class Album{
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
}