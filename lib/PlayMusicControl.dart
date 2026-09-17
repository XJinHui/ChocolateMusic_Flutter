import 'dart:async';
import 'dart:convert';
import 'package:media_kit/media_kit.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';

class PlayMusicControl {
  late Management management;

  late String url = ''; // 当前正在播放的音乐url / 准备播放的音乐url
  late String currentUrl = ''; // 当前正在播放的音乐url，避免重复打开同一首音乐

  late Map<String, List<String>> musicList = {};
  late Map<String, List<LyricsMap>> lyricList = {};
  late Map<String, String> lyricListString = {};
  late List<LyricsMap> displayLyricList = [];
  late String lyric = '';

  late Player player = Player();

  late int musicProgress = 0; //歌曲播放进度（毫秒）

  late List<Music> playMusicList = [];

  // 当前高亮的歌词行索引，-1 表示尚无歌词。
  // 缓存它是为了不让每次进度回调都从头线性扫描歌词。
  int _lyricLineIndex = -1;

  // 保存所有订阅，dispose 时统一取消
  final List<StreamSubscription> _subs = [];

  PlayMusicControl(Management management) {
    this.management = management;
    this.updateVolume(this.management.setting.volume.toInt());
    _initPlayerListeners();
  }

  _initPlayerListeners() {
    // 播放 / 暂停
    _subs.add(
      player.stream.playing.listen((isPlaying) {
        this.management.setting.play = isPlaying; // 若 Management 没这个字段就删掉
        this.management.refresh();
        print('播放状态: ${isPlaying}');
      }),
    );

    // 实时进度（核心）
    _subs.add(
      this.player.stream.position.listen((position) {
        final ms = position.inMilliseconds;
        this.musicProgress = ms;
        this.management.musicProgress = ms;
        // 只通知播放进度条，不再 refresh()：
        // 否则每几百毫秒就把歌单列表等整棵子树重建一次。
        this.management.progressNotifier.value = ms;
        updateCurrentLyric(ms);
        // _updateLyric(ms);
      }),
    );

    // 总时长
    _subs.add(
      player.stream.duration.listen((duration) {
        final ms = duration.inMilliseconds;
        this.management.musicDuration = ms;
      }),
    );

    // 播放完成 → 自动下一首
    _subs.add(
      player.stream.completed.listen((completed) {
        if (completed) {
          if (this.management.setting.playType == 2) {
            this.player.seek(Duration.zero).then((_) => this.player.play());
          } else {
            this.nextMusic();
          }
        }
      }),
    );

    // 错误
    _subs.add(
      player.stream.error.listen((error) {
        print('player error: $error');
        this.nextMusic();
      }),
    );
  }

  play({type = 'play'}) async {
    this.musicProgress = 0;
    this.management.musicProgress = 0;
    this.management.progressNotifier.value = 0;
    this.management.musicDuration = 0;

    var id = this.management.setting.id;
    await this.getMusicUrl(this.management.setting.id);

    if (id != this.management.setting.id) {
      // 播放设置更新过程中，歌曲发生了变化，放弃当前播放请求
      return;
    }

    if (this.url == '') {
      this.nextMusic();
      return;
    }

    getMusicLyric(this.management.setting.id);

    if (this.currentUrl == this.url) {
      // 同一首，重播即可
      await this.player.seek(Duration.zero);
      await this.player.play();
      return;
    }
    this.currentUrl = this.url;
    this.player.open(Media(this.url), play: type == 'play');
  }

  nextMusic() {
    if (this.playMusicList.length == 0 &&
        this.management.setting.playlistId == '') {
      if (this.management.recommendList.music.length == 0) {
        this.play();
        return;
      }

      for (var i = 0; i < this.management.recommendList.music.length; i++) {
        if (this.management.recommendList.music[i].id ==
            this.management.setting.id) {
          var lastIndex = (i + 1) % this.management.recommendList.music.length;
          this.management.updataPlayMusicSettings(
            this.management.recommendList.music[lastIndex],
            playlistType: this.management.setting.playlistType,
          );
          break;
        }

        if (i == this.management.recommendList.music.length - 1) {
          this.management.updataPlayMusicSettings(
            this.management.recommendList.music[0],
            playlistType: this.management.setting.playlistType,
          );
        }
      }
    } else {
      for (var i = 0; i < this.playMusicList.length; i++) {
        if (this.playMusicList[i].id == this.management.setting.id) {
          var nextIndex = (i + 1) % this.playMusicList.length;
          this.management.updataPlayMusicSettings(
            this.playMusicList[nextIndex],
            playlistType: this.management.setting.playlistType,
          );
          break;
        }
        if (i == this.playMusicList.length - 1) {
          this.management.updataPlayMusicSettings(
            this.playMusicList[0],
            playlistType: this.management.setting.playlistType,
          );
        }
      }
    }

    this.play();
  }

  lastMusic() {
    if (this.playMusicList.length == 0 &&
        this.management.setting.playlistId == '') {
      if (this.management.recommendList.music.length == 0) {
        this.play();
        return;
      }

      for (var i = 0; i < this.management.recommendList.music.length; i++) {
        if (this.management.recommendList.music[i].id ==
            this.management.setting.id) {
          var lastIndex =
              (i - 1 + this.management.recommendList.music.length) %
              this.management.recommendList.music.length;
          this.management.updataPlayMusicSettings(
            this.management.recommendList.music[lastIndex],
            playlistType: this.management.setting.playlistType,
          );
          break;
        }

        if (i == this.management.recommendList.music.length - 1) {
          this.management.updataPlayMusicSettings(
            this.management.recommendList.music[0],
            playlistType: this.management.setting.playlistType,
          );
        }
      }
    } else {
      for (var i = 0; i < this.playMusicList.length; i++) {
        if (this.playMusicList[i].id == this.management.setting.id) {
          var lastIndex =
              (i - 1 + this.playMusicList.length) % this.playMusicList.length;
          this.management.updataPlayMusicSettings(
            this.playMusicList[lastIndex],
            playlistType: this.management.setting.playlistType,
          );
          break;
        }

        if (i == this.playMusicList.length - 1) {
          this.management.updataPlayMusicSettings(
            this.playMusicList[0],
            playlistType: this.management.setting.playlistType,
          );
        }
      }
    }

    this.play();
  }

  changeProgress(int time) {
    this.player.seek(Duration(milliseconds: time));
  }

  pausePlayMusic() {
    this.player.playOrPause(); // 切换播放/暂停
  }

  stop() {
    this.player.stop();
  }

  updateVolume(int volume) {
    if (this.management.setting.volumeType) {
      this.player.setVolume(volume.toDouble());
    } else {
      this.player.setVolume(0);
    }
    print('音量更新: ${volume}');
  }

  getMusicUrl(String musicId) async {
    this.url = '';

    var qualityTier = this.management.setting.qualityTier;

    // var musicData = await this.management.musicManagement.searchMusicData(
    //     this.playlistManagement.setting.name,
    //     this.playlistManagement.setting.singer,
    //     this.playlistManagement.setting.qualityTier
    // );
    // if (musicData != null) {
    //   let filePath = musicData.filePath
    //
    //   const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
    //   const fd = file.fd; // 获取文件描述符
    //
    //   this.url = `fd://${fd}`
    //   console.log('本地音乐url:', this.url)
    //   return
    // }

    if (this.musicList.containsKey(musicId) &&
        this.musicList[musicId]![qualityTier] != '') {
      this.url = this.musicList[musicId]![qualityTier];
      return;
    }

    var url = await this.management.cloud.chooseMusicQuality(
      musicId,
      quality: this.management.setting.qualityTier,
    );
    print('获取到的音乐url: ${url}');
    if (url != '') {
      if (musicId == this.management.setting.id) {
        this.url = url;
      }

      if (this.musicList.containsKey(musicId)) {
        this.musicList[musicId]![qualityTier] = url;
      } else {
        var newList = ['', '', ''];
        newList[qualityTier] = url;
        this.musicList[musicId] = newList;
      }
    }
  }

  getMusicLyric(String musicId) async {
    this.lyric = '';
    this.displayLyricList = [];
    this.management.displayLyricList = [];
    // 换歌后行索引必须失效，否则会把上一首的行号套在新歌词上
    this._lyricLineIndex = -1;
    this.management.lyricLineNotifier.value = -1;
    this.management.displayLyric =
        '${this.management.setting.name} - ${this.management.setting.singer}';

    if (this.lyricList.containsKey(musicId)) {
      this.management.displayLyricList = this.lyricList[musicId]!;
      this.displayLyricList = this.lyricList[musicId]!;
      var lyric = this.lyricListString[musicId]!;

      if (this.detectionLyricsType(lyric)) {
        this.management.lyricType = true;
        this.lyric = this.enhancedLyricToLyric(lyric);
      } else {
        this.management.lyricType = false;
        this.lyric = lyric;
      }
      this.management.refresh();
      return;
    }

    var lyric = await this.management.cloud.getLyric(musicId);
    if (!(lyric is bool) && lyric != '') {
      List<LyricsMap> lyricList = [];
      var lyricType = this.detectionLyricsType(lyric);

      if (lyricType) {
        lyricList = this.parseEnhancedLyric(lyric);
      } else {
        lyricList = this.parseLyric(lyric);
      }

      if (musicId == this.management.setting.id) {
        if (lyricType) {
          this.lyric = this.enhancedLyricToLyric(lyric);
        } else {
          this.lyric = lyric;
        }

        this.management.lyricType = lyricType;
        this.displayLyricList = lyricList;
        this.management.displayLyricList = lyricList;
      }

      this.lyricList[musicId] = lyricList;
      this.lyricListString[musicId] = lyric;
      // print(lyric);
      this.management.refresh();
      // print('歌词类型，false为普通歌词，true为逐字歌词: $lyricType');
    }
  }

  detectionLyricsType(String lyric) {
    // 检测歌词类型，false 为普通歌词，true 为逐字歌词
    final charRegex = RegExp(r'<\d{2}:\d{2}\.\d{2,3}>');
    return charRegex.hasMatch(lyric);
  }

  enhancedLyricToLyric(String enhancedLyric) {
    final regex = RegExp(r'<\d{1,3}:\d{2}\.\d{2,3}>');
    return enhancedLyric.replaceAll(regex, '');
  }

  parseLyric(String lyric) {
    // 解析普通歌词
    if (lyric.trim().isEmpty) return [];

    final Map<int, List<String>> lyricsMap = {};
    final List<LyricsMap> lyricsMapList = [];

    final timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (final line in lyric.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 提取所有时间标签
      final timeMatches = timeRegex.allMatches(trimmed).toList();
      if (timeMatches.isEmpty) continue; // 跳过 [ti:] 等元数据

      // 去掉所有时间标签，得到纯文本
      var text = trimmed;
      for (final m in timeMatches) {
        text = text.replaceFirst(m.group(0)!, '');
      }
      text = text.trim();
      if (text.isEmpty) continue;

      for (final m in timeMatches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final millis = int.parse(m.group(3)!.padRight(3, '0'));
        final totalTimeMs = minutes * 60 * 1000 + seconds * 1000 + millis;

        lyricsMap.putIfAbsent(totalTimeMs, () => <String>[]).add(text);
      }
    }

    lyricsMap.forEach((time, texts) {
      lyricsMapList.add(LyricsMap(time: time, lyric: texts));
    });
    lyricsMapList.sort((a, b) => a.time - b.time);
    return lyricsMapList;
  }

  List<LyricsMap> parseEnhancedLyric(String lyric) {
    // 解析逐字歌词
    if (lyric.trim().isEmpty) return [];

    // key: 行级时间戳（毫秒），value: 同一时间的多行歌词，每行为该句的逐字列表
    final Map<int, List<List<WordTimestamp>>> lyricsMap = {};
    final List<LyricsMap> lyricsMapList = [];

    // 匹配行级时间戳：[开始时间]
    final lineTimeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    // 匹配逐字时间戳和字符：<开始时间>字符
    final wordTagRegex = RegExp(r'<(\d{2}):(\d{2})\.(\d{2,3})>([^<]+)');

    for (final line in lyric.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 提取所有行级时间标签
      final timeMatches = lineTimeRegex.allMatches(trimmed).toList();
      if (timeMatches.isEmpty) continue; // 跳过 [ti:] 等元数据

      // 去掉所有时间标签，得到含逐字标签的句子
      var sentence = trimmed;
      for (final m in timeMatches) {
        sentence = sentence.replaceFirst(m.group(0)!, '');
      }

      for (final m in timeMatches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final millis = int.parse(m.group(3)!.padRight(3, '0'));
        final lineTimeMs =
            minutes * 60 * 1000 + seconds * 1000 + millis; // 行级时间戳，单位毫秒

        // 处理当前句子内的所有逐字标签
        final List<WordTimestamp> wordTimestamps = [];
        for (final charMatch in wordTagRegex.allMatches(sentence)) {
          final wordMinutes = int.parse(charMatch.group(1)!);
          final wordSeconds = int.parse(charMatch.group(2)!);
          final wordMillis = int.parse(charMatch.group(3)!.padRight(3, '0'));
          final wordTimeMs =
              wordMinutes * 60 * 1000 +
              wordSeconds * 1000 +
              wordMillis; // 逐字时间戳，单位毫秒

          final char = charMatch.group(4)!;
          if (char.isEmpty) continue; // 过滤空字符

          wordTimestamps.add(
            WordTimestamp(time: wordTimeMs, lyric: char, long: 300),
          );
        }

        // 整行没有任何逐字标签（空行、纯伴奏行）时直接跳过，
        // 否则会留下一个 lyric 为空、wordTimestamps 为空列表的条目，
        // 消费端取 wordTimestamps[0][0] 就会越界。
        if (wordTimestamps.isEmpty) continue;

        lyricsMap.putIfAbsent(lineTimeMs, () => []).add(wordTimestamps);
      }
    }

    lyricsMap.forEach((time, lines) {
      final List<String> lyricList = [];
      final List<List<WordTimestamp>> wordTimestampsList = [];
      for (final wordTimestamps in lines) {
        // 句子文本由逐字拼接而成
        lyricList.add(wordTimestamps.map((w) => w.lyric).join());
        wordTimestampsList.add(wordTimestamps);
      }
      lyricsMapList.add(
        LyricsMap(
          time: time,
          lyric: lyricList,
          wordTimestamps: wordTimestampsList,
        ),
      );
    });
    lyricsMapList.sort((a, b) => a.time - b.time);

    // 计算每个逐字的持续时间：非行尾取与下一个逐字的开始时间差，行尾取与下一行的开始时间差（上限 300ms）
    for (int i = 0; i < lyricsMapList.length; i++) {
      int nextTime = -1;
      if (i != lyricsMapList.length - 1) {
        nextTime = lyricsMapList[i + 1].time;
      }

      final tws = lyricsMapList[i].wordTimestamps;
      if (tws == null) continue;

      for (int j = 0; j < tws.length; j++) {
        for (int k = 0; k < tws[j].length; k++) {
          final word = tws[j][k];
          if (k == tws[j].length - 1) {
            if (nextTime != -1) {
              final long = nextTime - word.time;
              word.long = long < 300 ? long : 300;
            } else {
              word.long = 300;
            }
          } else {
            word.long = tws[j][k + 1].time - word.time;
          }
        }
      }
    }

    return lyricsMapList;
  }

  /// 根据播放进度定位当前歌词行（以及逐字进度）。
  ///
  /// 进度回调每几百毫秒就会触发一次，因此这里做了三件事：
  /// 1. 用二分查找定位行，避免每次从头线性扫描；
  /// 2. 只在「行 / 逐字时间」真正变化时才写字段并通知歌词组件，
  ///    通知走 [Management.lyricLineNotifier]，不走 refresh()，否则整页会跟着重建；
  /// 3. 对 wordTimestamps 缺失或为空做降级，不再抛越界异常。
  updateCurrentLyric(int time) {
    try {
      final list = this.displayLyricList;
      if (list.isEmpty) {
        return;
      }

      // 二分查找最后一个 time <= 当前进度的行；比首行还早时先预览首行
      int left = 0;
      int right = list.length - 1;
      int index = -1;
      while (left <= right) {
        final mid = (left + right) >> 1;
        if (list[mid].time <= time) {
          index = mid;
          left = mid + 1;
        } else {
          right = mid - 1;
        }
      }
      if (index < 0) {
        index = 0;
      }

      final line = list[index];

      // 逐字歌词才需要算逐字进度；普通歌词沿用行时间戳，
      // 保证 lyricTime（行级）与 lyricWordTime（逐字级）的语义清晰
      int wordTime = line.time;
      if (this.management.lyricType) {
        final words =
            (line.wordTimestamps != null && line.wordTimestamps!.isNotEmpty)
            ? line.wordTimestamps![0]
            : const <WordTimestamp>[];
        wordTime = 0;
        for (final word in words) {
          if (word.time <= time) {
            wordTime = word.time;
          } else {
            break;
          }
        }
      }

      // 行与逐字进度都没变化时直接返回，避免无意义的重建
      if (index == _lyricLineIndex &&
          this.management.lyricTime == line.time &&
          this.management.lyricWordTime == wordTime) {
        return;
      }

      _lyricLineIndex = index;
      this.management.displayLyric = line.lyric.join('\n');
      this.management.lyricTime = line.time;
      this.management.lyricWordTime = wordTime;
      this.management.lyricLineNotifier.value = index;
    } catch (error) {
      _lyricLineIndex = -1;
      print('歌词显示更新错误: ${error}');
    }
  }
}
