import 'package:chocolate_music/Type.dart';

class Management{
  static final Management _instance = Management._internal();

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