import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_test/utils/byte.dart';
import 'package:bluetooth_test/utils/data.dart';
import 'package:bluetooth_test/utils/saveFile.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'i18n/mytranslate.dart';
import 'utils/getdatahandle.dart';

class DeviceHandle2Page extends StatefulWidget {
  const DeviceHandle2Page({
    super.key,
    required this.r,
  });
  final ScanResult r; //设备对象

  @override
  State<DeviceHandle2Page> createState() => _DeviceHandle2PageState();
}

class _DeviceHandle2PageState extends State<DeviceHandle2Page> {
  int mtu = 0; //MTU值
  double _setMTUVal = 185; //MTU设置值（根据IOS最大值设置）
  bool _isConnecting = false; //是否正在连接
  bool _isConnected = false; //是否已连接

  String _text = ""; //接收的数据
  String _deviceID = ""; //设备ID
  double _progress = 0; //进度条当前进度
  double _max = 0; //进度条最大进度
  int _fileMaxBits = 11; //一条数据预测占用位数
  int _progressFile = 0; //当前文件进度
  int _maxFile = 1; //文件最大进度

  StreamSubscription<bool>? _isConnectedListen; //连接状态监听

  final ScrollController _scrollController = ScrollController(); //滚动控制器

  BluetoothCharacteristic? mCharacteristic; //当前选择的特征值对象
  StreamSubscription<List<int>>? _cListen; //特征值监听

  List<BluetoothCharacteristic> _characteristics = []; //所有特征值对象集合
  String _selectCharacteristic = ""; //选择的特征值
  List pickerData = []; //特征值选择器数据

  final TextEditingController _textController = TextEditingController(
    text: '',
  ); //输入框控制器

  bool _isOpenNofity = false; //是否打开通知

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
    print("================");
    _selectCharacteristic = "-";
    pickerData.clear();
    List<BluetoothService> services = await widget.r.device.discoverServices();
    print(services);
    print("================");
    for (var service in services) {
      var value = service.uuid.toString();
      print("服务值 >>>> $value");
      if (service.uuid.toString().toUpperCase().substring(4, 8) == "FFFF") {
        _characteristics = service.characteristics;
        for (var characteristic in _characteristics) {
          var valuex = characteristic.uuid.toString();
          String function = '';
          switch (
              characteristic.uuid.toString().toUpperCase().substring(4, 8)) {
            case 'FF01':
              function = '写';
              break;
            case 'FF02':
              function = '指示,通知,读';
              break;
            case 'FF03':
              function = '指示,通知,读,写';
              break;
            case 'FF04':
              function = '指示';
              break;
            default:
          }
          String key = '${valuex.toUpperCase().substring(0, 8)} - $function';
          if (_selectCharacteristic == "-" || function == "指示,通知,读,写") {
            setState(() {
              _selectCharacteristic = key;
            });
          }
          setState(() {
            pickerData.add(key);
          });
          print("特征值 ---> $valuex");
        }
      }
    }
    if (_selectCharacteristic == "-") {
      setState(() {
        _selectCharacteristic = "NaN";
      });
    }
  }

  //mCharacteristic   4.扫描蓝牙设备备注有介绍、6.匹配对应权限特征中给它赋值
//_BleDataCallback 方法在6.匹配对应权限特征中 调用
  Future<void> bleDataCallback() async {
    print(">>> 等待蓝牙返回数据 <<<");
    if (mCharacteristic == null) {
      return;
    }
    await mCharacteristic!.setNotifyValue(_isOpenNofity);
    _cListen = mCharacteristic!.value.listen((List<int> value) {
      // do something with new value
      // print("我是蓝牙返回数据 - $value");
      if (value.isEmpty) {
        print("我是蓝牙返回数据 - 空！！$value <<");
        return;
      }
      List<int> data = [];
      if (value.length > 10) {
        for (int i = value.length - 10; i < value.length; i++) {
          // String dataStr = value[i].toRadixString(16);
          // if (dataStr.length < 2) {
          //   dataStr = "0$dataStr";
          // }
          // String dataEndStr = "0x$dataStr";
          data.add(value[i]);
        }
      }
      // // print("蓝牙返回数据 >> $value");
      // print("处理后 >> $data");
      // // print(">> ${utf8.decode(value)}");
      // print(">> ${utf8.decode(data)}");
      String dataStr = utf8.decode(value);
      _fileMaxBits = _fileMaxBits < value.length ? _fileMaxBits : value.length;
      print(">> $dataStr");
      List temp = dataHandle(
        dataStr,
        _text,
        _deviceID,
        _progress,
        _max,
        _fileMaxBits,
        _progressFile,
        _maxFile,
      );
      setState(() {
        _text = temp[1];
        _deviceID = temp[2];
        _progress = temp[3];
        _max = temp[4];
        _fileMaxBits = temp[5];
        _progressFile = temp[6];
        _maxFile = temp[7];
      });
      if (temp[0] == "FileEnd") {
        BotToast.showText(text: '传输完成');
        _fileMaxBits = 0;
        Timer(const Duration(milliseconds: 500), () {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        });
      } else {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    }, onDone: () {
      print(">>> 蓝牙返回数据结束 <<<");
    }, onError: (error) {
      print(">>> 蓝牙返回数据错误: $error <<<");
    }, cancelOnError: false);

    // List<BluetoothDescriptor> descriptors = c.descriptors;
    // for (BluetoothDescriptor descriptor in descriptors) {
    //   print(">>> descriptor: ${descriptor.uuid} <<<");
    //   if (descriptor.uuid.toString().toUpperCase().substring(4, 8) == "2902") {
    //     // descriptor.write(ENABLE_INDICATION);
    //     descriptor.value.listen((value) {
    //       print(">>> descriptor value: $value <<<");
    //     });
    //   }
    // }
  }

  //连接蓝牙设备
  void link() {
    setState(() {
      _isConnecting = true;
    });
    widget.r.device.connect(autoConnect: false).then(
      (value) {
        setState(() {
          _isConnecting = false;
        });
        if (_isConnectedListen != null) {
          _isConnectedListen = null;
        }
        _isConnectedListen =
            widget.r.device.isDiscoveringServices.listen((event) {
          if (!_isConnecting && !event && _selectCharacteristic == "") {
            _selectCharacteristic = "-";
            _buleDiscoverServices();
          }
        });
      },
    ).catchError((e) {
      print(">>> 连接失败1: $e <<<");
      setState(() {
        _isConnecting = false;
      });
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
          fontFamily: Platform.isWindows ? "Roboto" : "",
        ),
        selectedTextStyle: const TextStyle(color: Colors.red),
        columnPadding: const EdgeInsets.all(8.0),
        onConfirm: (Picker picker, List value) {
          print(value.toString());
          print(picker.getSelectedValues());
          String selectVal = picker.getSelectedValues().isNotEmpty
              ? picker.getSelectedValues()[0]
              : "";
          setState(() {
            _selectCharacteristic = selectVal;
          });
        });
    picker.showBottomSheet(context);
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
              onPressed = () => widget.r.device.disconnect().then((value) {
                    setState(() {
                      _cListen?.cancel();
                      _cListen = null;
                      _isOpenNofity = false;
                      mCharacteristic = null;
                      _characteristics.clear();
                      _selectCharacteristic = "";
                      pickerData.clear();
                    });
                  });
              text = 'DISCONNECT';
              break;
            case BluetoothDeviceState.disconnected:
              _isConnected = false;
              onPressed = () {
                try {
                  link();
                } catch (e) {
                  print(">>>Error: $e<<<");
                }
              };
              text = 'CONNECT';
              _selectCharacteristic = "";
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
                            snapshot.data == BluetoothDeviceState.connected
                                ? StreamBuilder<int>(
                                    stream: rssiStream(),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.hasData
                                            ? '${snapshot.data}dBm'
                                            : '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      );
                                    })
                                : Text(
                                    '',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
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
                        Text('MTU:${mtu == 0 ? "" : mtu}'),
                        SizedBox(
                          width: 100.w-200,
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
                            "Set MTU ${_setMTUVal.toInt()}",
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                        ElevatedButton(
                          onPressed: _selectCharacteristic != ""
                              ? () {
                                  for (BluetoothCharacteristic c
                                      in _characteristics) {
                                    if (c.uuid
                                            .toString()
                                            .toUpperCase()
                                            .substring(0, 8) ==
                                        _selectCharacteristic.substring(0, 8)) {
                                      print(
                                          "匹配到正确的特征值 >>> ${c.uuid.toString()} <<<");
                                      if (mCharacteristic != null) {
                                        mCharacteristic!.setNotifyValue(false);
                                        _cListen!.cancel();
                                        mCharacteristic = null;
                                        _cListen = null;
                                      }
                                      setState(() {
                                        mCharacteristic = c;
                                      });

                                      // const timeout =
                                      //     Duration(milliseconds: 100);
                                      // Timer(timeout, () {
                                      //收到下位机返回蓝牙数据回调监听
                                      bleDataCallback();
                                      // });
                                      BotToast.showText(
                                          text: tt('text.setSuccess'));
                                    }
                                  }
                                }
                              : null,
                          child: Text(tt('text.setLinkMode')),
                        ), //设置连接模式
                      ],
                    ),
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
                                  _textController.text = "";
                                }),
                                icon: const Icon(Icons.cancel),
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              snapshot.data == BluetoothDeviceState.connected &&
                                      mCharacteristic != null
                                  ? () async {
                                      setState(() {
                                        _text = "";
                                      });
                                      _progress = 0; //进度条当前进度
                                      _max = 200; //进度条最大进度
                                      _fileMaxBits = 11; //一条数据预测占用位数
                                      _progressFile = 0; //当前文件进度
                                      _maxFile = 1; //文件最大进度
                                      print(tobyte(_textController.text));
                                      mCharacteristic!
                                          .write(tobyte(_textController.text));
                                      // var descriptors =
                                      //     mCharacteristic!.descriptors;
                                      // print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv");
                                      // print(descriptors.length);
                                      // for (BluetoothDescriptor d in descriptors) {
                                      //   List<int> value = await d.read();
                                      //   print(value);
                                      //   print('d.write');
                                      //   d
                                      //       .write(tobyte(_textController.text))
                                      //       .catchError((e) => print('Error::$e'));
                                      // }
                                      // print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
                                    }
                                  : null,
                          child: const Text("send"),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: _isOpenNofity,
                              onChanged: mCharacteristic != null
                                  ? (val) {
                                      mCharacteristic!.setNotifyValue(val).then(
                                        (value) {
                                          if (!value) {
                                            return;
                                          }
                                          setState(() {
                                            _isOpenNofity = val;
                                          });
                                        },
                                      ).catchError((e) {
                                        print('Notify Error:$e');
                                        BotToast.showText(
                                            text:
                                                '${tt('text.nofitySetError')}:$e');
                                      });
                                    }
                                  : null,
                            ),
                            const Text('打开通知'),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _text != ""
                              ? () async {
                                  bool temp = await saveFile(_deviceID, _text);
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
                    SizedBox(
                      //收到的数据显示区
                      height: 100.h - 400,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return ListTile(
                                  title: Text(_text),
                                );
                              },
                              childCount: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
