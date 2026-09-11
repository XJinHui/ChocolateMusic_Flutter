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
  late Map<String, List<String>> lyricListString = {};
  late List<LyricsMap> displayLyricList = [];
  late String lyric = '';

  late Player player = Player();

  late int musicProgress = 0; //歌曲播放进度（毫秒）

  late List<Music> playMusicList = [];

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
    if (this.playMusicList.length == 0 && this.management.setting.playlistId == '') {
      if (this.management.recommendList.music.length == 0) {
        this.play();
        return;
      }

      for (var i = 0; i < this.management.recommendList.music.length; i++) {
        if (this.management.recommendList.music[i].id == this.management.setting.id) {
          var lastIndex = (i + 1) % this.management.recommendList.music.length;
          this.management.updataPlayMusicSettings(
              this.management.recommendList.music[lastIndex],
              playlistType: this.management.setting.playlistType
          );
          break;
        }

        if (i == this.management.recommendList.music.length - 1) {
          this.management.updataPlayMusicSettings(
              this.management.recommendList.music[0],
              playlistType: this.management.setting.playlistType
          );
        }
      }
    }
    else {
      for (var i = 0; i < this.playMusicList.length; i++) {
        if (this.playMusicList[i].id == this.management.setting.id) {
          var nextIndex = (i + 1) % this.playMusicList.length;
          this.management.updataPlayMusicSettings(
              this.playMusicList[nextIndex],
              playlistType: this.management.setting.playlistType
          );
          break;
        }
        if (i == this.playMusicList.length - 1){
          this.management.updataPlayMusicSettings(
              this.playMusicList[0],
              playlistType: this.management.setting.playlistType
          );
        }
      }
    }

    this.play();
  }

  lastMusic() {
    if (this.playMusicList.length == 0 && this.management.setting.playlistId == '') {
      if (this.management.recommendList.music.length == 0) {
        this.play();
        return;
      }

      for (var i = 0; i < this.management.recommendList.music.length; i++) {
        if (this.management.recommendList.music[i].id == this.management.setting.id) {
          var lastIndex = (i - 1 + this.management.recommendList.music.length) %
              this.management.recommendList.music.length;
          this.management.updataPlayMusicSettings(
              this.management.recommendList.music[lastIndex],
              playlistType: this.management.setting.playlistType
          );
          break;
        }

        if (i == this.management.recommendList.music.length - 1) {
          this.management.updataPlayMusicSettings(
              this.management.recommendList.music[0],
              playlistType: this.management.setting.playlistType
          );
        }
      }
    }
    else {
      for (var i = 0; i < this.playMusicList.length; i++) {
        if (this.playMusicList[i].id == this.management.setting.id) {
          var lastIndex = (i - 1 + this.playMusicList.length) % this.playMusicList.length;
          this.management.updataPlayMusicSettings(
              this.playMusicList[lastIndex],
              playlistType: this.management.setting.playlistType
          );
          break;
        }

        if (i == this.playMusicList.length - 1) {
          this.management.updataPlayMusicSettings(
              this.playMusicList[0],
              playlistType: this.management.setting.playlistType
          );
        }
      }
    }

    this.play();
  }

  changeProgress(int time) {
    this.player.seek(Duration(seconds: time));
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

  getMusicLyric(String musicId) {}
}
