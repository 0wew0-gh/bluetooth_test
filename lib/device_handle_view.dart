import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_test/utils/data.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'i18n/mytranslate.dart';
import 'utils/getdatahandle.dart';

import 'package:path/path.dart' as p;

class DeviceHandlePage extends StatefulWidget {
  const DeviceHandlePage({
    super.key,
    required this.r,
  });
  final ScanResult r; //设备对象

  @override
  State<DeviceHandlePage> createState() => _DeviceHandlePageState();
}

class _DeviceHandlePageState extends State<DeviceHandlePage> {
  int mtu = 0; //MTU值
  double _setMTUVal = 512; //MTU设置值（根据IOS最大值设置）
  bool _isConnecting = false; //是否正在连接
  bool _isConnected = false; //是否已连接

  // String _text = ''; //接收的数据
  final List<List<int>> _data = []; //接收的数据
  List<int> _olddata = []; //接收的数据
  double _progress = 0; //进度条当前进度
  double _max = 0; //进度条最大进度
  int _progressFile = 0; //当前文件进度
  int _oldSN = 0;
  int _errCount = 0; //错漏数量

  StreamSubscription<bool>? _isConnectedListen; //连接状态监听

  List<BluetoothCharacteristic> _characteristics = []; //所有特征值对象集合
  final List _expansionList = []; //所有特征值是否打开通知集合
  final List<StreamSubscription<List<int>>?> _cListenList = []; //所有特征值监听集合
  final List<bool> _isNotifyList = []; //所有特征值是否打开通知集合

  String _selectCharacteristic = ''; //选择的特征值
  List pickerData = []; //特征值选择器数据

  final TextEditingController _textController = TextEditingController(
    text: '',
  ); //输入框控制器

  String _filePath = '';
  IOSink? _ftxt;
  IOSink? _fcsv;
  bool _isOpenFile = false;

  Timer? _timer;

  @override
  void initState() {
    // setState(() {
    //   _isConnecting = true;
    // });
    // link();

    super.initState();
  }

  @override
  void dispose() {
    widget.r.device.disconnect();
    super.dispose();
  }

  //读取RSSI
  Stream<int> rssiStream() async* {
    _isConnected = true;
    final subscription = widget.r.device.state.listen((state) {
      _isConnected = state == BluetoothDeviceState.connected;
    });
    while (_isConnected) {
      yield await widget.r.device.readRssi();
      await Future.delayed(const Duration(seconds: 1));
    }
    subscription.cancel();
    // Device disconnected, stopping RSSI stream
  }

  //获取特征值对象
  void _buleDiscoverServices() async {
    print('================');
    _expansionList.clear();
    _selectCharacteristic = '-';
    pickerData.clear();
    List<BluetoothService> services = await widget.r.device.discoverServices();
    print(services);
    print('================');
    for (var service in services) {
      var value = service.uuid.toString();
      print('服务值 >>>> $value');
      if (service.uuid.toString().toUpperCase().substring(4, 8) == 'FFFF') {
        _characteristics = service.characteristics;
        _expansionList.clear();
        for (var characteristic in _characteristics) {
          var valuex = characteristic.uuid.toString();
          print('====>>${characteristic.properties}');
          String function = '';
          if (characteristic.properties.read) {
            if (function != '') {
              function += ',';
            }
            function += '读';
          }
          if (characteristic.properties.write) {
            if (function != '') {
              function += ',';
            }
            function += '写';
          }
          if (characteristic.properties.notify) {
            if (function != '') {
              function += ',';
            }
            function += '通知';
          }
          if (characteristic.properties.indicate) {
            if (function != '') {
              function += ',';
            }
            function += '指示';
          }
          String key = '${valuex.toUpperCase().substring(0, 8)} - $function';
          if (_selectCharacteristic == '-' &&
              valuex.toUpperCase().substring(0, 8) == '0000FF04') {
            setState(() {
              _selectCharacteristic = key;
            });
          }
          setState(() {
            pickerData.add(key);
            _expansionList.add([false, characteristic, _expansionList.length]);
            _cListenList.add(null);
            _isNotifyList.add(false);
          });
          print('特征值 ---> $valuex');
        }
      }
    }
    if (_selectCharacteristic == '-') {
      setState(() {
        _selectCharacteristic = 'NaN';
      });
    }
  }

  //mCharacteristic   4.扫描蓝牙设备备注有介绍、6.匹配对应权限特征中给它赋值
//_BleDataCallback 方法在6.匹配对应权限特征中 调用
  Future<void> bleDataCallback(BluetoothCharacteristic c) async {
    for (var i = 0; i < _characteristics.length; i++) {
      BluetoothCharacteristic characteristic = _characteristics[i];
      if (characteristic == c) {
        StreamSubscription<List<int>>? cL = _cListenList[i];
        if (cL != null) {
          cL.cancel();
          cL = null;
        }
        if (_timer != null) {
          _timer!.cancel();
          _timer = null;
        }
        BotToast.showText(
            text: '${tt('text.addListen')}:${characteristic.uuid}');

        double fileLine = 100;
        _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
          characteristic.read().then((value) {
            String val = utf8.decode(value);
            print('read value: $value - $val');

            List<String> temp = val.split("/");
            if (temp[0] == temp[1]) {
              if (mounted) {
                setState(() {
                  _isOpenFile = true;
                  _progress = _max;
                });
              }
              BotToast.showText(
                text: '${tt('text.transferDone')}:$_errCount',
              );
              _timer!.cancel();
              _timer = null;
              Timer(const Duration(seconds: 2), () {
                characteristic.setNotifyValue(false).then((value) async {
                  setState(() {
                    _isNotifyList[i] = false;
                  });
                });
              });
            } else {
              if (temp[0] == "0") {
                return;
              }
              try {
                int p = int.parse(temp[0]);
                if (mounted) {
                  setState(() {
                    _progress = p * fileLine;
                    _progressFile = p;
                    _max = double.parse(temp[1]) * fileLine;
                    if (_max < _progress) {
                      _max = _progress * 500;
                    }
                  });
                }
              } catch (e) {
                print('progress Error:$e');
              }
            }
          });
        });
        cL = characteristic.value.listen((List<int> value) {
          if (value.isEmpty) {
            print('我是蓝牙返回数据 - 空！！$value <<');
            return;
          }
          if (_olddata != value) {
            String dataStr = utf8.decode(value);

            if (dataStr.contains('/')) return;

            List temp = dataHandle(
              dataStr,
              _oldSN,
              _errCount,
            );
            switch (temp[0]) {
              case 'Done':
              case 'page':
                if (_ftxt != null) {
                  _ftxt!.write(temp[1]);
                }
                if (_fcsv != null) {
                  _fcsv!.write(temp[1]);
                }
                //进度条推进
                if (_progress < (_progressFile + 1) * fileLine) {
                  if (mounted) {
                    setState(() {
                      _progress++;
                    });
                  }
                } else {
                  fileLine++;
                }
                break;
              // case 'DeivceID':
              //   print('=== DeivceID ===');
              //   List temp = dataStr.split(':');
              //   String text = temp[0];
              //   temp = temp[1].split('\n');
              //   _deviceID = temp[0];
              //   text += ',$_deviceID';
              //   BotToast.showText(text: text);
              //   if (_ftxt != null) {
              //     _ftxt!.write('$text\n');
              //   }
              //   if (_fcsv != null) {
              //     _fcsv!.write('$text\n');
              //   }
              //   DateTime dt = DateTime.now();
              //   getDataTime = dt.toString().substring(0, 19);
              //   break;
              // case 'FileEnd':
              //   print('${tt('text.transferDone')}:$_errCount');
              //   BotToast.showText(
              //     text: '${tt('text.transferDone')}:$_errCount',
              //   );
              //   setState(() {
              //     _isOpenFile = true;
              //     _progress = _max;
              //   });
              //   Timer(const Duration(seconds: 2), () {
              //     characteristic.setNotifyValue(false).then((value) async {
              //       setState(() {
              //         _isNotifyList[i] = false;
              //       });
              //     });
              //   });
              //   break;
              default:
            }
            if (!_isOpenFile) {
              _oldSN = temp[2];
              _errCount = temp[3];
              // if (mounted) {
              //   setState(() {
              //     // _text = temp[1];
              //     _progress = double.parse(temp[2].toStringAsFixed(0));
              //     _max = double.parse(temp[3].toStringAsFixed(0));
              //   });
              // }
            }
          }
          _olddata = value;
        });
      }
    }
  }

  //连接蓝牙设备
  Future<void> link() async {
    if (!await FlutterBluePlus.instance.isOn) {
      await FlutterBluePlus.instance.turnOn();
      print('>>>>>> FlutterBluePlus.instance.turnOn <<<<<<<');
    }
    setState(() {
      _isConnecting = true;
    });
    widget.r.device.connect(autoConnect: false).then(
      (value) {
        setState(() {
          _isConnecting = false;
        });
        if (_isConnectedListen != null) {
          _isConnectedListen!.cancel();
          _isConnectedListen = null;
        }
        _isConnectedListen =
            widget.r.device.isDiscoveringServices.listen((event) {
          if (!_isConnecting && !event && _selectCharacteristic == '') {
            _selectCharacteristic = '-';
            widget.r.device.requestMtu(_setMTUVal.toInt()).then((value) {
              setState(() {
                mtu = value;
              });

              _buleDiscoverServices();
            });
          }
        });
        return;
      },
    ).catchError((e) {
      print('>>> 连接失败: $e <<<');
      setState(() {
        _isConnecting = false;
      });
      return;
    });
  }

  //选择服务
  showPicker(BuildContext context) async {
    if (pickerData.isEmpty) {
      return;
    }
    Picker picker = Picker(
        adapter: PickerDataAdapter<String>(pickerData: pickerData),
        changeToFirst: false,
        textAlign: TextAlign.left,
        textStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.yellow
              : Colors.blue,
          fontFamily: Platform.isWindows ? 'Roboto' : '',
        ),
        selectedTextStyle: const TextStyle(color: Colors.red),
        columnPadding: const EdgeInsets.all(8.0),
        onConfirm: (Picker picker, List value) {
          print(value.toString());
          print(picker.getSelectedValues());
          String selectVal = picker.getSelectedValues().isNotEmpty
              ? picker.getSelectedValues()[0]
              : '';
          setState(() {
            _selectCharacteristic = selectVal;
          });
        });
    picker.showBottomSheet(context);
  }

  Future<bool> createFile(String fileName) async {
    DateTime dt = DateTime.now();
    getDataTime = dt.toString().substring(0, 19);
    // String fn = '${fileName}_$getDataTime';

    List? temp = await getExternalStorageDirectories();

    if (temp == null || temp.isEmpty) {
      return false;
    }
    String deviceFolder = p.join(temp[0].path, fileName);
    Directory appDocDir = Directory(deviceFolder);
    appDocDir.createSync(recursive: true);
    _filePath = p.join(deviceFolder, getDataTime);

    try {
      File f = File('$_filePath.txt');
      //判断文件是否存在
      bool isExist = await f.exists();
      print('File isExist: $isExist');
      if (!isExist) {
        //不存在则创建
        f = await f.create();
        print('create F path:$_filePath');
      } else {
        f.delete();
        f = await f.create();
        print('create F path:$_filePath');
      }
      print('创建文件');
      if (_ftxt != null) {
        await _ftxt!.close();
        _ftxt = null;
      }
      _ftxt = f.openWrite(mode: FileMode.writeOnlyAppend);
      f = File('$_filePath.csv');
      //判断文件是否存在
      isExist = await f.exists();
      print('File isExist: $isExist');
      if (!isExist) {
        //不存在则创建
        f = await f.create();
        print('create F path:$_filePath');
      } else {
        f.delete();
        f = await f.create();
        print('create F path:$_filePath');
      }
      print('创建文件');
      if (_fcsv != null) {
        await _fcsv!.close();
        _fcsv = null;
      }
      _fcsv = f.openWrite(mode: FileMode.writeOnlyAppend);
    } catch (e) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothDeviceState>(
        stream: widget.r.device.state,
        initialData: BluetoothDeviceState.connecting,
        builder: (c, snapshot) {
          VoidCallback? onPressed;
          String text;
          switch (snapshot.data) {
            case BluetoothDeviceState.connected:
              _isConnected = true;

              onPressed = () async {
                if (_isConnecting) {
                  return;
                }
                if (!await FlutterBluePlus.instance.isOn) {
                  if (context.mounted) Navigator.pop(context, false);
                  return;
                }
                print('>>> 断开连接 <<<');
                bool isTimeOut = false;
                setState(() {
                  _isConnecting = true;
                });
                print('============================');
                print('iscoonecting: $_isConnecting');
                print('============================');
                widget.r.device.disconnect().then((value) {
                  isTimeOut = true;
                  setState(() {
                    _characteristics.clear();
                    _selectCharacteristic = '';
                    pickerData.clear();
                    _isConnected = false;
                    _isConnecting = false;
                    _expansionList.clear();
                  });

                  if (_timer != null) {
                    _timer!.cancel();
                    _timer = null;
                  }
                  print('>>> 断开连接成功 $_isConnected <<<');
                }).catchError((e) {
                  isTimeOut = true;
                  setState(() {
                    _isConnected = false;
                    _isConnecting = false;
                  });
                  print('>>> 断开连接失败: $_isConnected $e <<<');
                });
                Timer(const Duration(seconds: 2), () async {
                  if (!isTimeOut) {
                    BotToast.showText(text: tt('text.disconnTimeOut'));
                    await FlutterBluePlus.instance.turnOff();
                    FlutterBluePlus.instance.turnOn();
                    if (context.mounted) Navigator.pop(context, false);
                  }
                  setState(() {
                    _isConnected =
                        snapshot.data == BluetoothDeviceState.connected;
                    _isConnecting = false;
                  });

                  if (_timer != null) {
                    _timer!.cancel();
                    _timer = null;
                  }
                });
              };
              text = 'DISCONNECT';
              break;
            case BluetoothDeviceState.disconnected:
              _isConnected = false;
              onPressed = () {
                bool isTimeOut = false;
                link().then((value) => isTimeOut = true);
                Timer(const Duration(seconds: 4), () {
                  if (isTimeOut) {
                    BotToast.showText(text: tt('text.connTimeOut'));
                  }
                  setState(() {
                    _isConnected =
                        snapshot.data == BluetoothDeviceState.connected;
                    _isConnecting = false;
                  });
                });
                try {} catch (e) {
                  print('>>>Error: $e<<<');
                }
              };
              text = 'CONNECT';
              _selectCharacteristic = '';
              break;
            default:
              onPressed = null;
              text = snapshot.data.toString().substring(21).toUpperCase();
              break;
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.r.device.name),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _isConnected ? Colors.red : Colors.green,
                  ),
                  onPressed: _isConnecting ? null : onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<BluetoothDeviceState>(
                      stream: widget.r.device.state,
                      initialData: BluetoothDeviceState.connecting,
                      builder: (c, snapshot) => ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            snapshot.data == BluetoothDeviceState.connected
                                ? const Icon(Icons.bluetooth_connected)
                                : const Icon(Icons.bluetooth_disabled),
                            // snapshot.data == BluetoothDeviceState.connected
                            //     ? StreamBuilder<int>(
                            //         stream: rssiStream(),
                            //         builder: (context, snapshot) {
                            //           return Text(
                            //             snapshot.hasData
                            //                 ? '${snapshot.data}dBm'
                            //                 : '',
                            //             style: Theme.of(context)
                            //                 .textTheme
                            //                 .bodySmall,
                            //           );
                            //         })
                            //     : Text(
                            //         '',
                            //         style:
                            //             Theme.of(context).textTheme.bodySmall,
                            //       ),
                          ],
                        ),
                        title: Text(
                            'Device is ${snapshot.data.toString().split('.')[1]}.'),
                        subtitle: Text('${widget.r.device.id}'),
                        trailing: StreamBuilder<bool>(
                          stream: widget.r.device.isDiscoveringServices,
                          initialData: false,
                          builder: (c, snapshot) => IndexedStack(
                            index: snapshot.data! ? 1 : 0,
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _buleDiscoverServices(),
                              ),
                              const IconButton(
                                icon: SizedBox(
                                  width: 18.0,
                                  height: 18.0,
                                  child: CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.grey),
                                  ),
                                ),
                                onPressed: null,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MTU:${mtu == 0 ? '' : mtu}'),
                        SizedBox(
                          width: 100.w - 200,
                          child: Slider(
                            min: 23,
                            max: 512,
                            divisions: 60,
                            value: _setMTUVal,
                            onChanged: (v) => setState(() {
                              _setMTUVal = v.toInt().toDouble();
                            }),
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              snapshot.data == BluetoothDeviceState.connected
                                  ? () => widget.r.device
                                      .requestMtu(_setMTUVal.toInt())
                                      .then((value) => setState(() {
                                            mtu = value;
                                          }))
                                  : null,
                          child: Text(
                            'Set MTU ${_setMTUVal.toInt()}',
                          ),
                        ),
                      ],
                    ),
                    ExpansionPanelList(
                      expansionCallback: (int index, bool isExpanded) {
                        setState(() {
                          _expansionList[index][0] = !isExpanded;
                        });
                      },
                      children: _expansionList.map<ExpansionPanel>((e) {
                        BluetoothCharacteristic item = e[1];
                        var valuex = item.uuid.toString();
                        String function = '';
                        if (item.properties.read) {
                          if (function != '') {
                            function += ',';
                          }
                          function += '读';
                        }
                        if (item.properties.write) {
                          if (function != '') {
                            function += ',';
                          }
                          function += '写';
                        }
                        if (item.properties.notify) {
                          if (function != '') {
                            function += ',';
                          }
                          function += '通知';
                        }
                        if (item.properties.indicate) {
                          if (function != '') {
                            function += ',';
                          }
                          function += '指示';
                        }
                        String key =
                            '${valuex.toUpperCase().substring(0, 8)} - $function';
                        return ExpansionPanel(
                          isExpanded: e[0],
                          headerBuilder:
                              (BuildContext context, bool isExpanded) {
                            return InkWell(
                              onTap: () => setState(() {
                                e[0] = !e[0];
                              }),
                              child: Text(key),
                            );
                          },
                          body: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (item.properties.read)
                                const Icon(Icons.download),
                              if (item.properties.write)
                                const Icon(Icons.upload),
                              if (item.properties.notify)
                                IconButton(
                                  onPressed: () {
                                    bool isNot = !_isNotifyList[e[2]];
                                    BluetoothCharacteristic c = e[1];
                                    c.setNotifyValue(isNot).then((value) async {
                                      bool isSucce = false;
                                      if (isNot) {
                                        if (_ftxt != null) {
                                          await _ftxt!.close();
                                          _ftxt = null;
                                          File f = File('$_filePath.txt');
                                          f.delete(recursive: true);
                                        }
                                        if (_fcsv != null) {
                                          await _fcsv!.close();
                                          _fcsv = null;
                                          File f = File('$_filePath.csv');
                                          f.delete(recursive: true);
                                        }
                                        isSucce = await createFile(
                                            widget.r.device.name);
                                      }
                                      if (!isSucce) {
                                        setState(() {
                                          _isNotifyList[e[2]] = isNot;
                                        });
                                        return;
                                      }
                                      if (value) {
                                        if (isNot) {
                                          setState(() {
                                            _progress = 0;
                                            _max = 10000;
                                          });
                                          _data.clear();
                                          bleDataCallback(e[1]);
                                        } else {
                                          getDataTime = '';
                                          _cListenList[e[2]]?.cancel();
                                          _cListenList[e[2]] = null;
                                          _timer?.cancel();
                                          _timer = null;
                                        }
                                      }
                                      setState(() {
                                        _isNotifyList[e[2]] = isNot;
                                      });
                                    });
                                  },
                                  icon: Icon(
                                    Icons.notifications_active,
                                    color: _isNotifyList[e[2]]
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                ),
                              if (item.properties.indicate)
                                const Icon(Icons.wb_incandescent_outlined),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    Builder(builder: (context) {
                      return InkWell(
                        onTap: () => showPicker(context),
                        child: Container(
                          width: 100.w - 150,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(width: 2.0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 100.w - 180,
                                child: Text(_selectCharacteristic),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      );
                    }),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 100.w - 100,
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() {
                                  _textController.text = '';
                                }),
                                icon: const Icon(Icons.cancel),
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: snapshot.data ==
                                  BluetoothDeviceState.connected
                              ? () async {
                                  // setState(() {
                                  //   _text = '';
                                  // });
                                  // _progress = 0; //进度条当前进度
                                  // _max = 200; //进度条最大进度
                                  // _fileMaxBits = 0; //一条数据预测占用位数
                                  // _progressFile = 0; //当前文件进度
                                  // _maxFile = 1; //文件最大进度
                                  BluetoothCharacteristic c =
                                      _characteristics.firstWhere((element) =>
                                          element.uuid
                                              .toString()
                                              .toUpperCase()
                                              .substring(0, 8) ==
                                          _selectCharacteristic.substring(
                                              0, 8));
                                  await c.write(_textController.text.codeUnits);
                                  await c.read().then((value) {
                                    print('read value: $value');
                                    BotToast.showText(
                                      text: utf8.decode(value),
                                      duration: const Duration(seconds: 10),
                                    );
                                  }).catchError((e) {
                                    print('Error::$e');
                                  });
                                }
                              : null,
                          child: const Text('send'),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$_progress/$_max'),
                        ElevatedButton(
                          onPressed: _isOpenFile
                              ? () {
                                  if (_ftxt == null) {
                                    return;
                                  }

                                  _ftxt!.close().then((vtxt) {
                                    String path = '';
                                    if (vtxt is File) {
                                      path = tt("text.saveSuccess") + vtxt.path;
                                    }
                                    _ftxt = null;
                                    if (_fcsv == null) {
                                      if (path.isNotEmpty) {
                                        BotToast.showText(
                                          text: path,
                                          duration: const Duration(seconds: 10),
                                        );
                                      }
                                      return;
                                    }
                                    _fcsv!.close().then((vcsv) {
                                      if (vcsv is File) {
                                        path += '\nCSV: ${vcsv.path}';
                                      }
                                      if (path.isNotEmpty) {
                                        BotToast.showText(
                                          text: path,
                                          duration: const Duration(seconds: 10),
                                        );
                                      }
                                      setState(() {
                                        _isOpenFile = false;
                                      });
                                      _fcsv = null;
                                    });
                                  });
                                }
                              : null,
                          child: Text(tt('btn.saveFile')),
                        ), //保存文件
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (_max != 0 && !(_progress / _max).isNaN)
                      LinearProgressIndicator(
                        value: _progress / _max,
                      ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
