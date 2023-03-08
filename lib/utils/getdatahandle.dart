List dataHandle(
  String event,
  String text,
  String deviceID,
  double progress,
  double max,
  int fileMaxBits,
  int progressFile,
  int maxFile,
) {
  if (event.contains('ReadRecord')) {
    text = "";
    deviceID = "";
  } else if (event.startsWith('Deivce:')) {
    List temp = event.split(":");
    text = temp[0];
    temp = temp[1].split("\n");
    deviceID = temp[0];
    text += ",$deviceID";
  } else if (event.contains('/')) {
    List<String> temp = event.split("/");
    try {
      progressFile = int.parse(temp[0]);
      maxFile = int.parse(temp[1]);
      double piecesNum = 4096 / fileMaxBits;
      progress = (progressFile - 1) * piecesNum;
      max = maxFile * piecesNum;
    } catch (e) {
      return [
        "error",
        text,
        deviceID,
        progress,
        max,
        fileMaxBits,
        progressFile,
        maxFile
      ];
    }
    print('>>预测进度 $progress/$max');
  } else if (event.contains('SN Time')) {
    List<String> temp = event.split(" ");
    double nowP = progress / 512;
    double piecesNum = 4096 / fileMaxBits;
    String e = event.replaceAll(" ", ",");
    max = maxFile * piecesNum;
    text += '\n$e';
    print('fileMaxBits:$fileMaxBits');
    print('maxFile:$maxFile');
    print('max:$max');
    print('>>计算实际 $progress/$max ||| $nowP');
  } else if (event.contains('FileEnd')) {
    return [
      "FileEnd",
      text += event,
      deviceID,
      max,
      max,
      fileMaxBits,
      progressFile,
      maxFile
    ];
  } else {
    List<String> temp = event.split("\n");
    for (var element in temp) {
      if (element.length < 2) {
        continue;
      }
      List<String> tempList = element.split(" ");
      String dateTime = "";
      int dateIndex = 0;
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
          if (e.length < 25) {
            int len = text.length;
            if (len > 2) {
              String tempStr = text.substring(len - 2, len);
              if (tempStr == "\n") {
                print(">>$text");
                text = text.substring(0, len - 2);
              }
            }
          }
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
      tempList[dateIndex] = dateTime;
      String tempStr = tempList.join(",");
      final int tlen = tempStr.length;
      if (tlen > 2) {
        final String t = tempStr.substring(tlen - 2, tlen);
        if (t != "\n") {
          tempStr += '\n';
        }
      }
      progress++;
      if (progress > max) {
        max += 50;
      }
      // print('>>计算实际 $progress/$max');
      text += tempStr;
    }
  }

  text = text.replaceAll("\n,", ",");
  text = text.replaceAll("\n:", ":");
  text = text.replaceAll("\n ", "");
  // text += "\n";
  return [
    "Done",
    text,
    deviceID,
    progress,
    max,
    fileMaxBits,
    progressFile,
    maxFile
  ];
}
