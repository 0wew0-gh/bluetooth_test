import 'package:bluetooth_test/utils/data.dart';

List dataHandle(
  String event,
  int oldSN,
  int errCount,
) {
  String text = "";
  List<String> temp = event.split("\n");
  for (var element in temp) {
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

    text += tempStr;
  }

  //处理多余的换行
  text = text.replaceAll("\n,", ",");
  text = text.replaceAll("\n:", ":");
  text = text.replaceAll("\n ", "");
  return ["Done", text, oldSN, errCount];
}
