import 'package:flutter_translate/flutter_translate.dart';
import 'package:bluetooth_test/i18n/en.dart';
import 'package:bluetooth_test/i18n/zhcn.dart';

String tt(String key) {
  Map tmap = {};
  switch (translate('loc')) {
    case 'en':
      tmap = en;
      break;
    case 'zh-CN':
      tmap = zhcn;
      break;
    default:
  }
  List tarr = [];
  tarr.addAll(key.split("."));
  String returnstr = "";
  for (var i = 0; i < tarr.length; i++) {
    if (tmap.containsKey(tarr[i])) {
      if (tarr.length - 1 == i) {
        returnstr = tmap[tarr[i]];
      } else {
        tmap = tmap[tarr[i]];
      }
    } else {
      return key;
    }
  }
  return returnstr;
}
