import 'dart:convert';
import 'dart:io';
import 'package:file_type_dart/file_type_dart.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';

class MusicManagement {
  late Management management;

  final exeDir = File(Platform.resolvedExecutable).parent.path;

  late Database musicLibrary;

  /// 下载根目录（用户设置或默认）
  late String downloadDir;

  /// 歌词目录
  late String lyricDir;

  /// 临时目录：放在下载目录下，保证与目标同盘
  late String tempDir;

  late Map<String, String> lyricPath = {};
  late List<Music> localMusics = [];

  MusicManagement(Management management) {
    this.management = management;
  }

  /// 默认下载目录：用户没有在设置里指定时使用，位于可执行文件同级。
  String get defaultDownloadDir => p.join(this.exeDir, 'Music');

  /// 切换下载目录：重建歌词 / 临时目录并重新扫描本地音乐。
  ///
  /// [path] 传空串表示恢复默认目录。目录建不出来（路径非法或没有写权限）时
  /// 返回 false，并且不改动任何已有状态。
  Future<bool> applyDownloadDir(String path) async {
    final String target = path.isNotEmpty ? path : defaultDownloadDir;

    try {
      await Directory(target).create(recursive: true);
    } catch (e) {
      print('下载目录不可用：$target，$e');
      return false;
    }

    this.downloadDir = target;

    this.lyricDir = p.join(this.downloadDir, 'Lyric');
    await checkCreateFolder(lyricDir);

    this.tempDir = p.join(this.downloadDir, '.tmp');
    await Directory(tempDir).create(recursive: true);

    // scanFolder 是增量累加（localMusics.add），换目录前必须先清空，
    // 否则旧目录扫出来的歌会残留在本地列表里。
    this.localMusics = [];
    this.lyricPath = {};
    await this.scanFolder();

    return true;
  }

  init() async {
    // 初始化音乐管理
    // 解析并创建下载目录
    this.downloadDir = this.management.setting.downloadPath.isNotEmpty
        ? this.management.setting.downloadPath
        : defaultDownloadDir;
    await checkCreateFolder(downloadDir);

    // 解析并创建歌词目录
    this.lyricDir = p.join(this.downloadDir, 'Lyric');
    await checkCreateFolder(lyricDir);

    // 临时目录（用 .tmp 隐藏，避免污染用户视野）
    this.tempDir = p.join(this.downloadDir, '.tmp');
    await Directory(tempDir).create(recursive: true);

    await this.checkCreateSQLite('musicLibrary.db');

    this.scanFolder();
  }

  /// 启动时清空临时目录（上次异常退出留下的残骸）
  Future<void> cleanTempDir() async {
    final dir = Directory(tempDir);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  scanFolder() async {
    // 实现扫描文件夹的逻辑
    final directory = Directory(this.downloadDir);

    if (!await directory.exists()) {
      return;
    }

    final lyricDirectory = Directory(this.lyricDir);

    final List<File> lrcFiles = [];
    await for (final entity in lyricDirectory.list(recursive: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.lrc') {
          lrcFiles.add(entity);
        }
      }
    }

    // 处理扫描到的歌词文件
    for (var file in lrcFiles) {
      var lrcName = normalizeSeparator(p.basenameWithoutExtension(file.path));
      this.lyricPath[lrcName] = file.path;
    }

    final List<File> musicfiles = [];
    await for (final entity in directory.list(recursive: false)) {
      if (entity is File) {
        // 处理每个文件
        final ext = p.extension(entity.path).toLowerCase();
        if ([
          ".mp3",
          ".flac",
          ".wav",
          ".aac",
          ".m4a",
          ".ogg",
          ".wma",
          ".ape",
        ].contains(ext)) {
          musicfiles.add(entity);
        }
      }
    }

    final Map<String, String> fileList = {};
    // 处理扫描到的音频文件
    for (var file in musicfiles) {
      final fullPath = file.path;
      fileList[normalizeSeparator(fullPath)] = fullPath;
    }

    var rows = await musicLibrary.query('MUSIC');
    final Map<String, String> sqlFileList = {};
    for (var row in rows) {
      final filePath = row['filePath'] as String?;
      if (filePath != null) {
        sqlFileList[normalizeSeparator(filePath)] = filePath;
      }
    }

    // 计算需要删除和需要插入的文件
    final List<String> deleteFileList = [];
    final List<String> insertFileList = [];

    // 数据库有，文件系统没有 -> 删除
    for (var key in sqlFileList.keys) {
      if (!fileList.containsKey(key)) {
        deleteFileList.add(sqlFileList[key]!);
      }
    }

    // 文件系统有，数据库没有 -> 插入
    for (var key in fileList.keys) {
      if (!sqlFileList.containsKey(key)) {
        insertFileList.add(fileList[key]!);
      }
    }

    // 执行删除
    for (var filePath in deleteFileList) {
      await musicLibrary.delete(
        'MUSIC',
        where: 'filePath = ?',
        whereArgs: [filePath],
      );
    }

    // 执行插入
    for (var filePath in insertFileList) {
      final fileName = p.basename(filePath);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final parts = nameWithoutExt.split('-');

      // 解析歌手和歌名：第一段为歌手，剩余部分合并为歌名
      String singer = parts.isNotEmpty ? parts[0].trim() : '';
      String name = parts.length > 1 ? parts.sublist(1).join('-').trim() : '';

      // 调用 addMusicData 插入数据库
      await this.addMusicData(name, singer, filePath);
    }

    Map<String, Music> localMusicsMap = {};
    rows = await musicLibrary.query('MUSIC');
    for (var row in rows) {
      var id = p.basenameWithoutExtension(row['filePath'] as String);
      if (localMusicsMap.containsKey(id)) {
        // 如果已经存在，跳过
        var newAlbum = row['album']?.toString();
        var newSinger = row['singer']?.toString();
        Music music = localMusicsMap[id]!; // 这里是 Music 对象

        localMusicsMap[id] = Music(
          id: id,
          name: music.name,
          singer: music.singer != '' ? music.singer : (newSinger ?? ''),
          singerId: '',
          album: music.album != '' ? music.album : (newAlbum ?? ''),
          albumId: '',
          time: music.time,
          cover: music.cover,
        );

        continue;
      } else {
        final music = Music(
          id: id,
          name: row['name'] as String,
          singer: row['singer'] as String,
          singerId: '',
          album: row['album'] as String? ?? '',
          albumId: '',
          time: row['time'] as int? ?? 0,
          cover: row['cover'] as String? ?? '',
        );

        localMusicsMap[id] = music;
      }
    }
    for (var item in localMusicsMap.values) {
      this.localMusics.add(item);
    }

    if (this.management.playbackState.playlistId == 'Download') {
      this.management.playMusicList = this.localMusics;
      this.management.getPlayList();
    }
    // print(jsonEncode(this.localMusics));
  }

  Future<bool> downloadAndSaveMusic(Music music, int quality) async {
    // 下载音乐文件并保存到用户选择的位置
    Dio dio = Dio();
    String? tempPath;

    try {
      final url = await this.management.cloud.chooseMusicQuality(
        music.id,
        quality: quality,
      );

      if (url == '') {
        print('获取下载链接失败');
        return false;
      }

      final stamp = DateTime
          .now()
          .millisecondsSinceEpoch;
      tempPath = p.join(tempDir, 'music_${music.id}_$stamp.tmp');

      final response = await dio.download(
        url,
        tempPath,
        onReceiveProgress: (int received, int total) {
          // print('下载进度: $received / $total');
        },
      );

      final tempFile = File(tempPath);
      print('下载完成，临时文件路径: ${tempFile.path}');

      var detectedExt = await this.detectAudioFormat(tempPath);
      var finalExt = detectedExt ?? 'mp3';

      var fileName = '${music.singer} - ${music.name}.${finalExt}';
      var filePath = p.join(downloadDir, fileName);

      await tempFile.rename(filePath);
      print('保存音乐文件到: ${filePath}');

      var result = await this.addMusicData(
          music.name,
          music.singer,
          filePath,
          album: music.album,
          cover: music.cover,
      );

      this.localMusics.add(
          Music(id: '${music.singer} - ${music.name}',
              name: music.name,
              singer: music.singer,
              singerId: music.singerId,
              album: music.album,
              albumId: music.albumId,
              time: music.time,
              cover: music.cover
          )
      );

      downloadAndSaveLyrics(music);
      // await this.addMusicToDatabase(music.name, music.singer, tempPath);

      return result;
    } catch (error) {
      print('下载或保存音乐文件失败: ${error}');
      return false;
    }
  }

  downloadAndSaveLyrics(Music music) async {
    try {
      if (await this.searchLyric(music.name, music.singer) != '') {
        return;
      }

      final lrc = await this.management.cloud.getLyric(music.id);
      if (lrc == null || lrc.isEmpty) return;

      var fileName = '${music.singer} - ${music.name}.lrc';
      var filePath = p.join(this.lyricDir, fileName);

      final file = File(filePath);
      await file.writeAsString(lrc);

      this.lyricPath['${music.singer} - ${music.name}'] = filePath;
    } catch (error) {
      print('下载或保存歌词文件失败: ${error}');
    }
  }

  addMusicData(String name, String singer, String filePath,
      {String album = '', String cover = ''}) async {
    try {
      var data = await getAudioMetadata(filePath);

      album = album != '' ? album : data['album'] ?? '';
      cover = cover != '' ? cover : data['cover'] ?? '';

      var bitrate = data['bitrate'] ?? 128000;

      var qualityTier = 0; // 音质等级 (0 -> 标准， 1 -> 高品质， 2 -> 无损)

      if (bitrate >= 128000 && bitrate < 320000) {
        qualityTier = 0;
      } else if (bitrate >= 320000 && bitrate < 500000) {
        qualityTier = 1;
      } else {
        qualityTier = 2;
      }

      await this.musicLibrary.insert('MUSIC', {
        'name': name,
        'singer': singer,
        'bitrate': qualityTier,
        'filePath': filePath,
        'mimeType': data['mimeType'] ?? '',
        'album': album,
        'cover': cover,
        'time': data['time'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return true;
    } catch (error) {
      print('处理音乐文件失败: ${error}');
      return false;
    }
  }

  searchMusicData(String name, String singer, int qualityTier) async {
    try {
      final List<Map<String, dynamic>> rows = await this.musicLibrary.query(
        'MUSIC',
        where: 'name = ? AND singer = ?',
        whereArgs: [name, singer],
      );

      if (rows.isEmpty) {
        print('没有查询到匹配的数据');
        return null;
      }

      var data = {};

      // print('查询到的数据: $rows');
      for (var item in rows) {
        if (data.isEmpty) {
          data = item;
        } else {
          if (item['bitrate'] > data['bitrate']) {
            data = item;
          }
        }
      }

      if (data.isEmpty) {
        print('没有查询到匹配的数据');
        return null;
      }

      if (data['bitrate'] < qualityTier) {
        print(
            '查询到的数据音质等级低于要求: ${data['bitrate']} < $qualityTier');
        return null;
      }

      return data;
    } catch (error) {
      print('搜索音乐数据失败: ${error}');
      return null;
    }
  }

  searchLyric(String name, String singer) async {
    try {
      if (this.lyricPath.isEmpty) {
        print('歌词路径映射为空，未扫描歌词文件');
        return '';
      }

      var lrcName = '${singer} - ${name}';
      if (this.lyricPath.containsKey(lrcName)) {
        var filePath = this.lyricPath[lrcName]!;
        final file = File(filePath);
        if (!await file.exists()) {
          print('歌词文件不存在: ${filePath}');
          return '';
        }

        final lrc = await file.readAsString(encoding: utf8);

        return lrc;
      }

      return '';
    } catch (error) {
      print('搜索歌词文件失败: ${error}');
      return '';
    }
  }

  checkCreateSQLite(String sqlitePath) async {
    final dbFile = p.join(this.exeDir, 'data', sqlitePath);

    /// 建表 SQL（与 ArkTS 完全一致）
    const String SQL_CREATE_TABLE = '''
    CREATE TABLE IF NOT EXISTS MUSIC (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      singer TEXT NOT NULL,
      bitrate INTEGER,
      filePath TEXT NOT NULL,
      album TEXT,
      time Int,
      mimeType TEXT,
      cover TEXT
    )
  ''';

    this.musicLibrary = await openDatabase(
      dbFile,
      version: 1,
      onCreate: (Database db, int version) {
        return db.execute(SQL_CREATE_TABLE);
      },
    );
  }

  checkCreateFolder(String folderPath) async {
    var dir;
    if (folderPath != '') {
      dir = Directory(folderPath);
    } else {
      dir = Directory(p.join(this.exeDir, 'Music'));
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('下载文件夹已创建：$folderPath');
    } else {
      print('下载文件夹已存在：$folderPath');
    }
  }

  detectAudioFormat(String filePath) async {
    RandomAccessFile? raf;
    try {
      raf = await File(filePath).open();
      final bytes = await raf.read(64);
      return FileType
          .fromBuffer(bytes)
          ?.ext;
    } catch (_) {
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  getAudioMetadata(String filePath) async {
    try {
      final track = File(filePath);

      final raf = await track.open();
      final header = await raf.read(64); // 大多数格式魔数在前 64 字节内
      await raf.close();
      final result = FileType.fromBuffer(header);
      final mimeType = result?.mime;

      // getImage: false 跳过封面读取，可显著提升速度
      final metadata = await readMetadata(track, getImage: false);

      var data = {
        'bitrate': metadata.bitrate,
        'name': metadata.title,
        'singer': metadata.artist,
        'album': metadata.album,
        'time': metadata.duration?.inMilliseconds ?? 0,
        'mimeType': mimeType,
      };

      return data;
    } catch (error) {
      print(error);
      return {};
    }
  }
}

normalizeSeparator(String path) {
  final lastSlash = path.lastIndexOf('/');
  if (lastSlash == -1) {
    return path.replaceAll(RegExp(r'\s*-\s*'), ' - ');
  }
  return path.substring(0, lastSlash + 1) +
      path.substring(lastSlash + 1).replaceAll(RegExp(r'\s*-\s*'), ' - ');
}
