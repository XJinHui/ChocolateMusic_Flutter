import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:chocolate_music/Type.dart';

class FileManage {
  final exeDir = File(Platform.resolvedExecutable).parent.path;

  init() async {
    await ensureFolder('data');
  }

  ensureFolder(String file) async {
    // data 文件夹
    final dataDir = Directory(p.join(this.exeDir, file));

    // 不存在则创建
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
      print('${file} 文件夹已创建：${dataDir.path}');
    } else {
      print('${file} 文件夹已存在：${dataDir.path}');
    }
  }

  readSetting() async {
    final file = File('${this.exeDir}/data/setting.json');

    // 读取文件内容
    final content = await file.readAsString();
    return Setting.fromJson(jsonDecode(content));
  }

  writeSetting(Setting setting) async {
    final file = File('${this.exeDir}/data/setting.json');
    await file.writeAsString(jsonEncode(setting.toJson()));
  }

  readAccountData() async {
    final file = File('${this.exeDir}/data/accountData.json');

    // 读取文件内容
    final content = await file.readAsString();
    return AccountData.fromJson(jsonDecode(content));
  }

  writeAccountData(AccountData accountData) async {
    final file = File('${this.exeDir}/data/accountData.json');
    await file.writeAsString(jsonEncode(accountData.toJson()));
  }

  Future<List<RecommendList>> readRecommendListDate() async {
    final file = File('${this.exeDir}/data/recommendListDate.json');

    // 读取文件内容
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
    return jsonList
        .map(
          (item) =>
              RecommendList.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> writeRecommendListDate(
    List<RecommendList> recommendListDate,
  ) async {
    final file = File('${this.exeDir}/data/recommendListDate.json');
    await file.writeAsString(
      jsonEncode(recommendListDate.map((item) => item.toJson()).toList()),
    );
  }

  checkFile(String filePath) async {
    final file = File('${this.exeDir}/${filePath}');
    if (await file.exists()) {
      print("${filePath} 存在");
      return true;
    }
    print("${filePath} 不存在");
    return false;
  }
}
