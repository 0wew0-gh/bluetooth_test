import 'dart:io';

import 'package:bluetooth_test/buletooth_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:bot_toast/bot_toast.dart';

import 'utils/data.dart';

void main() async {
  // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  //   statusBarColor: Colors.transparent,
  //   statusBarBrightness: Brightness.dark,
  //   statusBarIconBrightness: Brightness.dark,
  //   systemNavigationBarColor: Colors.transparent,
  //   systemNavigationBarDividerColor: Colors.transparent,
  //   systemNavigationBarIconBrightness: Brightness.dark,
  // ));
  var delegate = await LocalizationDelegate.create(
    fallbackLocale: 'zh_CN',
    supportedLocales: [
      'zh_CN',
      'en',
    ],
  );
  runApp(LocalizedApp(delegate, const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    isAndroid = Platform.isAndroid;
    return ResponsiveSizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'Flutter Demo',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          builder: BotToastInit(),
          navigatorObservers: [BotToastNavigatorObserver()],
          home: const BuletoothTestPage(),
        );
      },
    );
  }
}