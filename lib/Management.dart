import 'package:chocolate_music/Type.dart';

class Management{
  static final Management _instance = Management._internal();

  late Object displayList;  // 显示的列表，可以是Playlist、Album、Singer等类型
  late String displayListType;  // 显示的列表类型，可以是Playlist、Album、Singer等类型

  factory Management() => _instance;

  late Setting setting;

  init(){

  }

  Management._internal() {
    this.setting = Setting(
        name: '',
        singer: '',
        singerId: '',
        album: '',
        albumId: '',
        time: '00:00',
        cover: '',
        like: false,
        id: '',
        playType: 0,
        volume: 100,
        volumeType: true,
        play: false,
        playlistId: '',
        playlistType: 0,
        qualityTier: 0,
        downloadQualityTier: 0
    );

    init();
  }
}