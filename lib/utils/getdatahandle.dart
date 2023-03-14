import 'dart:async';

import 'package:bluetooth_test/utils/data.dart';

double fileLine = 100;
List dataHandle(
  String event,
  double progress,
  double max,
  int progressFile,
  int oldSN,
  int errCount,
) {
  if (event.contains('ReadRecord')) {
    print('=== ReadRecord ===');
    DateTime dt = DateTime.now();
    getDataTime = dt.toString().substring(0, 19);
  } else if (event.startsWith('Deivce:')) {
    print('=== DeivceID ===');
    return ["DeivceID", "", progress, max, progressFile, oldSN, errCount];
  } else if (event.contains('/')) {
    List<String> temp = event.split("\n");
    for (var e in temp) {
      if (e.contains('/')) {
        temp = e.split("/");
      }
    }
    try {
      int p = int.parse(temp[0]) - 1;
      progress = p * fileLine;
      progressFile = p;
      max = double.parse(temp[1]) * fileLine;
      if (max < progress) {
        max = progress * 500;
      }
    } catch (e) {
      print('progress Error:$e');
      return ["error", "", progress, max, progressFile, oldSN, errCount];
    }
    return ["page", "\n", progress, max, progressFile, oldSN, errCount];
  } else if (event.contains('SN Time')) {
  } else if (event.contains('FileEnd')) {
    return ["FileEnd", "", max, max, progressFile, oldSN, errCount];
  }

  String text = "";
  List<String> temp = event.split("\n");
  for (var element in temp) {
    // if (element.length < 2) {
    //   continue;
    // }
    List<String> tempList = element.split(" ");
    int sn = 0;
    try {
      sn = int.parse(tempList[0]);
    } catch (e) {}
    if (oldSN > 0 && oldSN < sn && (oldSN + 1) != sn) {
      errCount++;
    }
    oldSN = sn;
    String dateTime = "";
    int dateIndex = -1;
    bool prevIsDate = false;
    for (var i = 0; i < tempList.length; i++) {
      String e = tempList[i];
      List<String> tempDate = e.split("-");
      if (tempDate.length == 3) {
        dateTime = '20$e';
        dateIndex = i;
        prevIsDate = true;
        continue;
      }
      tempDate = e.split(":");
      if (tempDate.length == 3) {
        dateTime += ' $e';
        tempList.removeAt(i);
        break;
      }
      if (prevIsDate) {
        dateTime += ' $e';
        tempList.removeAt(i);
        break;
      }
    }
    if (dateIndex != -1) {
      tempList[dateIndex] = dateTime;
    }
    String tempStr = tempList.join(",");

    final int tlen = tempStr.length;
    if (tlen > 2) {
      final String t = tempStr.substring(tlen - 2, tlen);
      if (t != "\n") {
        tempStr += '\n';
      }
    }

    //进度条推进
    if (progress < (progressFile + 1) * fileLine) {
      progress++;
    } else {
      fileLine++;
    }
    text += tempStr;
  }

  //处理多余的换行
  text = text.replaceAll("\n,", ",");
  text = text.replaceAll("\n:", ":");
  text = text.replaceAll("\n ", "");
  return ["Done", text, progress, max, progressFile, oldSN, errCount];
}
