import 'package:flutter_translate/flutter_translate.dart';
import 'package:bluetooth_test/i18n/en.dart';
import 'package:bluetooth_test/i18n/zhcn.dart';

String tt(String key) {
  Map myi18nMap = {'en': en, 'zh-CN': zhcn};
  List tarr = [translate('loc')];
  tarr.addAll(key.split("."));
  String returnstr = "";
  for (var i = 0; i < tarr.length; i++) {
    if (myi18nMap.containsKey(tarr[i])) {
      if (tarr.length - 1 == i) {
        returnstr = myi18nMap[tarr[i]];
      } else {
        myi18nMap = myi18nMap[tarr[i]];
      }
    } else {
      return key;
    }
  }
  return returnstr;
}
