import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_helper/bluetooth_device.dart';
import 'package:bluetooth_helper/bluetooth_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app22/fileHandler.dart';

void main() => runApp(MyApp1());

class MyApp1 extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _readCharacteristic = 'f0001299-0451-4000-b000-000000000000';

  String _writeCharacteristic2 = 'f000129a-0451-4000-b000-000000000000';
  static const double MAGIC_MICROVOLTS_BIT = 0.000186265;
  BluetoothDevice _device;
  int packNumber = 0;
  List<BluetoothDevice> devices = [];
  List<BluetoothDevice> connectedDevices = [];
  List<int> chunk = [];
  List<List<double>> data = [];
  bool showData = false;
  GlobalKey scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
   // BluetoothHelper.enableDebug();

    if (Platform.isAndroid) {
      _device = BluetoothDevice.create('A0:E6:F8:CF:0F:85', 'Neural');
    }

    checkBluetooth();

  }

  void checkBluetooth() {
    Timer.periodic(Duration(seconds: 2), (timer) {
      BluetoothHelper.bluetoothIsEnable.then((bluetoothEnabled) {
        if (!bluetoothEnabled) {
          BluetoothHelper.bluetoothEnable().then((value) {
            print('bluetooth $value');
          });
        }
      });
    });
  }

  Future scan() {
    return BluetoothHelper.me.scan(timeout: 2).then((value) {
      setState(() {
        devices = value.where((element) => element.deviceId.startsWith('')).toList();
        print('Devices: $devices');
      });
    });
  }

  void deviceCallback(dynamic e) {
    try {
      var list = Uint8List.fromList([0x00, 0x00, e.data[1], e.data[0]]);
      ByteData bd = list.buffer.asByteData();
      var num = bd.getInt32(0);
      List<int> data = [];
      if (num == packNumber + 1) {
        packNumber = num;
      } else if (num > (packNumber + 1)) {
        print('lost ${num - packNumber - 1} packs between $packNumber and $num');
        this.chunk.clear();
        packNumber = num;
      }
      for (int offset = 2; offset < 20; offset += 3) {
        var list = Uint8List.fromList(
            [0x00, e.data[offset + 2], e.data[offset + 1], e.data[offset]]);
        data.add(list.buffer.asByteData().getInt32(0));
      }
      // if (data.length < 10)
/*        Scaffold.of(context).showSnackBar(
            SnackBar(
          content: Text("Пошли данные"),
          backgroundColor: Colors.lightBlueAccent[100].withOpacity(0.6),
          duration: Duration(milliseconds: 800),
        ));*/
      chunk.addAll(data);
      if (chunk.length > 24) {
        chunk = chunk.sublist(0, 24);
      }
      if (chunk.length == 24) {
        this.data.add(chunk.map((e) => MAGIC_MICROVOLTS_BIT * e).toList());
        if (this.data.length % 100 == 0)
          print('${this.data.length}');
        if (this.data.length == 5000) {
          StatisticsPage.saveStats(this.data, DateTime.now()).then((value) {
            this.data.removeRange(0, 5000);
            setState(() {
            });
          });
        }
        chunk.clear();
      }
    } catch (e) {
      if (e is NoSuchMethodError) {
        //...
      } else print((e as Error).stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
        body: WillPopScope(
          child: (_device != null && showData) ?
          StatisticsPage() : Column(
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: scan,
                  child: devices.isEmpty ?
                  Stack(
                    children: [
                      Container(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Проведите сверзу вниз (как в хроме).\nЕсли ничего не найдено: \nУбедитесь что гарнитура включена и зеленый светодиод мигает раз в секунду.\nЕсли он мигает быстро, выключите блютуз и включите снова.'
                            '\n Попробуйте еще раз'),
                      ),
                      ),
                    ListView()
                    ],
                  ) :
                  ListView(
                      children:
                      devices.map((e) {
                        return Material(
                          child: ListTile(
                            title: Text(e.deviceName),
                            subtitle: Text(e.deviceId),
                              trailing: Icon(e.deviceState == 1 ? Icons.sync : Icons.circle, color: e.deviceState == 2 ? Colors.green : Colors.grey),
                            onTap: () async {

                              await disconnect();
                              if (_device != e && e.isDisconnected) {
                                _device = e;
                                await _device.connect();
                                chunk = [];
                                _device.eventCallback = deviceCallback;
                                await _device.discoverCharacteristics(2);
                                bool _setResult = await _device.setCharacteristicNotification(_readCharacteristic, true);
                                var writeResult = await _device.characteristicWrite(_writeCharacteristic2, [0x01, 0x00]);
                                var attempt = 0;
                                while (!writeResult && attempt < 5) {
                                  await Future.delayed(Duration(seconds: 1));
                                  writeResult = await _device.characteristicWrite(_writeCharacteristic2, [0x01, 0x00]);
                                  attempt++;
                                }
                                if (!writeResult) {
                                  await this._device.disconnect();
                                  return;
                                }
                                showData = true;
                                print('Writeresult $_setResult $writeResult');
                                print('bluetooth $writeResult');
                                setState(() {});
                              } else {
                                _device = null;
                                showData = false;
                              }
                              setState(() {});
                            },
                          ),
                        );
                      }).toList()
                  ),
                )
              )
            ],
          ),
          onWillPop: () {
            if (showData) {
              setState(() {
                showData = false;
              });
            } else {
                Navigator.pop(context);
            }
          },
        ),
      );
  }

  void disconnect() async {
    if (_device != null) {
      var writeResult = await _device.characteristicWrite(_writeCharacteristic2, [0x00, 0x00]).catchError((_){});
      var attempt = 0;
      while (!writeResult && attempt < 5) {
        await Future.delayed(Duration(seconds: 1));
        writeResult = await _device.characteristicWrite(_writeCharacteristic2, [0x00, 0x00]).catchError((_){});
        attempt++;
      }
      if (writeResult) {
        print('Sucesfully disco');
      }
      this._device.disconnect();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
