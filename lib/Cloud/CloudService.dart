abstract class CloudService {
  login() async {}

  updateAccountData() async {}

  updateAccountLogin(String mainUrl, int index) async {}

  getVerificationCode(String mobile, String mainUrl) async {}

  getQrCode(String mainUrl) async {}

  loginByMobile(String mobile, String mainUrl, String code) async {}

  loginByQrCode(String mainUrl) async {}

  // refreshToken() async {}
  //
  // getVipCookie() async {}
  //
  // getVipInfo(String userId) async {}

  getData() async {}

  getCollectionList() async {}

  getPlaylist() async {}

  getPlaylistMusic(String listId) async {}

  getSingerMusic(String singerId) async {}

  // getSingerAllMusic(String singerId) async {}

  getAlbumMusic(String albumId) async {}

  getSingerAlbum(String singerId) async {}

  getRecommendMusics(int num) async {}

  getRecommendSingers(int num) async {}

  getRecommendPlaylists(int num) async {}

  getRecommendAlbum(int num) async {}

  search(String keyword) async {}

  // searchMusic(String keyword) async {}
  //
  // searchSinger(String keyword) async {}
  //
  // searchAlbum(String keyword) async {}

  getMusicUrl(String musicId, {String bitrate = 'exhigh'}) async {}

  // getMatchtMusicUrl(String musicId, {String level = 'exhigh'}) async {}

  getMusicsDetails(List<String> musicIds) async {}

  getSingerDetails(String singerId) async {}

  getAlbumDetails(String albumId) async {}

  getPlaylistDetails(String listId) async {}

  getLyric(String musicId) async {}

  getLikeStatus(String musicId) async {}

  chooseMusicQuality(String musicId, {int quality = 0}) async {}

  createPlaylist(String name) async {}

  deletePlaylist(String listId) async {}

  addMusicToPlaylist(String listId, String musicId) async {}

  deleteMusicFromPlaylist(String listId, String musicId) async {}
}