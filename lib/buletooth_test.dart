import 'package:bluetooth_test/utils/data.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'device_handle_view2.dart';
import 'i18n/mytranslate.dart';

class BuletoothTestPage extends StatefulWidget {
  const BuletoothTestPage({
    super.key,
  });

  @override
  State<BuletoothTestPage> createState() => _BuletoothTestPageState();
}

class _BuletoothTestPageState extends State<BuletoothTestPage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<ScanResult> _scanBlue = [];
  bool isOnBlue = true;

  //是否过滤空蓝牙名字
  bool _isFilterEmptyName = true;

  @override
  void initState() {
    var subscription = flutterBlue.scanResults.listen((results) {
      print(">>>>>${results.length}<<<<<");
      if (_isFilterEmptyName) {
        setState(() {
          _scanBlue = results
              .where((element) => element.device.name.isNotEmpty)
              .toList();
        });
      } else {
        setState(() {
          _scanBlue = results;
        });
      }
    });
    getPermission().then((value) {
      if (!value) {
        return;
      }
      flutterBlue.isOn.then((value) {
        setState(() {
          isOnBlue = value;
        });
      });
      if (isOnBlue) {
        flutterBlue
            .startScan(timeout: const Duration(seconds: 5))
            .catchError((e) {
          if (e.toString().contains('getBluetoothLeScanner() is null.')) {
            flutterBlue.turnOn().then(
                  (value) => setState(() {
                    isOnBlue = value;
                  }),
                );
          }
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    flutterBlue.stopScan();
    for (var d in _scanBlue) {
      d.device.disconnect();
    }
    super.dispose();
  }

  Future<bool> getPermission() async {
    List<Permission> permissions = [
      Permission.locationWhenInUse,
      Permission.storage,
    ];
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if ((isAndroid && androidInfo.version.sdkInt <= 30) || !isAndroid) {
      permissions.add(Permission.bluetooth);
    } else {
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    print(statuses);
    bool isP = false;
    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      if ((isAndroid && androidInfo.version.sdkInt <= 30) || !isAndroid) {
        BotToast.showText(
            text: 'bluetooth: ${statuses[Permission.bluetooth]!.isGranted}');
        if (statuses[Permission.bluetooth]!.isGranted) {
          isP = true;
        }
      } else if (statuses[Permission.bluetoothScan]!.isGranted) {
        isP = true;
      }
      isP = true;
    }
    return isP;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isOnBlue ? null : Text(tt('text.blueOff')),
        backgroundColor: isOnBlue ? Colors.blue : Colors.red,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: _isFilterEmptyName,
                onChanged: (v) => setState(() {
                  _isFilterEmptyName = v!;
                }),
              ),
              InkWell(
                onTap: () => setState(() {
                  _isFilterEmptyName = !_isFilterEmptyName;
                }),
                child: const Text('是否过滤空蓝牙名'),
              )
            ],
          )
        ],
      ),
      body: _scanBlue.isNotEmpty
          ? ListView.builder(
              padding: const EdgeInsets.only(
                left: 13,
                right: 13,
              ),
              itemCount: _scanBlue.length * 2 - 1,
              itemBuilder: (context, i) {
                if (i.isOdd) {
                  return const Divider();
                }
                final index = i ~/ 2;
                ScanResult result = _scanBlue[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DeviceHandle2Page(r: result),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(result.rssi.toString()),
                      SizedBox(
                        width: 50.w,
                        height: 38,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.device.name != ""
                                  ? result.device.name
                                  : tt('text.unknownDevice'),
                            ),
                            Text(
                              result.device.id.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 5.w)
                    ],
                  ),
                );
              },
            )
          : Container(),
      floatingActionButton: StreamBuilder<bool>(
        stream: flutterBlue.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              onPressed: () => flutterBlue.stopScan(),
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
              child: const Icon(Icons.search),
              onPressed: () => flutterBlue
                  .startScan(
                timeout: const Duration(seconds: 5),
              )
                  .catchError((e) {
                if (e.toString().contains('getBluetoothLeScanner() is null.')) {
                  flutterBlue.turnOn().then(
                        (value) => setState(() {
                          isOnBlue = value;
                        }),
                      );
                }
              }),
            );
          }
        },
      ),
    );
  }
}
