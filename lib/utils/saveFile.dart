import 'dart:io';

import 'package:bluetooth_test/i18n/mytranslate.dart';
import 'package:bluetooth_test/utils/data.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<bool> saveFile(String fileName, String data) async {
  print("====$fileName");
  fileName = fileName == "" ? "temp" : fileName;
  fileName.replaceAll("\r", "");
  fileName.replaceAll("\\r", "");
  fileName.replaceAll(" ", "");
  print(fileName);
  String? pathName = "";
  final Uint8List fileData = Uint8List.fromList(data.codeUnits);
  if (isAndroid) {
    //Android
    try {
      List? temp = await getExternalStorageDirectories();
      print(">>>>>temp:$temp<<<<<<");
      if (temp == null || temp.isEmpty) {
        return false;
      }
      Directory appDocDir = Directory(temp[0].path);
      pathName = p.join(appDocDir.path, '$fileName.csv');
      //判读路径是否存在
      bool isExist = await Directory(appDocDir.path).exists();
      print('isExist:$isExist');
      try {
        File f = File(pathName);
        //判断文件是否存在
        isExist = await f.exists();
        print('File isExist: $isExist');
        if (!isExist) {
          //不存在则创建
          f = await f.create();
          print('create F path:$pathName');
        }else{
          f.delete();
          f = await f.create();
          print('create F path:$pathName');
        }
        //写入文件
        await f.writeAsBytes(fileData);
        print('write success');
        pathName = f.path;
        print('save path:$pathName');
        BotToast.showText(
          text: '${tt('text.saveSuccess')} $pathName',
          duration: const Duration(seconds: 10),
        );
        // try {
        //   File f2 = File(pathName);
        //   print(await f2.exists());
        //   f2.readAsString().then((value) {
        //     print('2 read success');
        //     // print(value);
        //   });
        // } catch (e) {
        //   BotToast.showText(
        //     text: 'read Error $e',
        //   );
        //   return false;
        // }
      } catch (e) {
        BotToast.showText(
          text: e.toString(),
          duration: const Duration(seconds: 10),
        );
        print('write Error $e');
        return false;
      }
    } catch (e) {}
  } else {
    //除Android外
    pathName = await getSavePath(suggestedName: '$fileName.csv');
    const String mimeType = 'csv/text';
    final XFile textFile =
        XFile.fromData(fileData, mimeType: mimeType, name: fileName);
    await textFile.saveTo(pathName!);
  }
  if (pathName == null) {
    return false;
  }
  return true;
}
