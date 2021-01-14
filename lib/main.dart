import 'dart:ffi' as ffi; // For FFI
import 'package:ffi/ffi.dart';
// ignore: implementation_imports
import 'package:ffi/src/utf8.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart' as window_size;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  window_size.getWindowInfo().then((window) {
    if (window.screen != null) {
      final screenFrame = window.screen.visibleFrame;
      final width = max((screenFrame.width / 2).roundToDouble(), 735.0);
      final height = max((screenFrame.height / 2).roundToDouble(), 730.0);
      final left = ((screenFrame.width - width) / 2).roundToDouble();
      final top = ((screenFrame.height - height) / 3).roundToDouble();
      final frame = Rect.fromLTWH(left, top, 735, 730);

      window_size.setWindowFrame(frame);
      window_size.setWindowTitle('NatType Test');
    }
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
    );
  }
}

/// This is the stateful widget that the main application instantiates.
class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

typedef stun_test_func = ffi.Pointer<Utf8> Function(); // FFI fn signature
typedef StunTest = ffi.Pointer<Utf8> Function(); // Dart fn signature
final stunTestLib =
    ffi.DynamicLibrary.open("data\\flutter_assets\\assets\\stun.dll");
final StunTest runStunTest = stunTestLib
    .lookup<ffi.NativeFunction<stun_test_func>>('RunTest')
    .asFunction();
final natType = {
  0: "Test failed",
  1: "Unexpected response from the STUN server",
  2: "Not behind a NAT",
  3: "UDP is blocked",
  4: "Full cone NAT",
  5: "Symmetric NAT",
  6: "Restricted NAT",
  7: "Port restricted NAT",
  8: "Symmetric UDP firewall",
};

/// This is the private State class that goes with MyStatefulWidget.
class _HomeState extends State<Home> {
  bool isButtonDisabled = true;
  final _inputServerCtl = TextEditingController();
  var natInfo = {
    "ip": 0,
    "nat": "",
    "port": 0,
  };

  @override
  void initState() {
    super.initState();
    isButtonDisabled = false;
    _inputServerCtl.addListener(_handleInput);
  }

  void dispose() {
    _inputServerCtl.dispose();
    super.dispose();
  }

  _handleInput() {
    print("input:${_inputServerCtl.text}");
  }

  loadData() async {
    // 通过spawn新建一个isolate，并绑定静态方法
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(dataLoader, receivePort.sendPort);

    // 获取新isolate的监听port
    SendPort sendPort = await receivePort.first;
    // 调用sendReceive自定义方法
    Map result = await sendReceive(sendPort, " ");
    setState(() {
      natInfo['nat'] = natType[result['nat']];
      natInfo['ip'] = result['ip'].toString();
      natInfo['port'] = result['port'].toString();
      isButtonDisabled = false;
    });
  }

// 创建自己的监听port，并且向新isolate发送消息
  Future sendReceive(SendPort sendPort, String url) {
    ReceivePort receivePort = ReceivePort();
    sendPort.send([url, receivePort.sendPort]);
    // 接收到返回值，返回给调用者
    return receivePort.first;
  }

  // isolate的绑定方法
  static dataLoader(SendPort sendPort) async {
    // 创建监听port，并将sendPort传给外界用来调用
    ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    // 监听外界调用
    await for (var msg in receivePort) {
      SendPort callbackPort = msg[1];
      var result = jsonDecode(runStunTest().ref.toString());
      callbackPort.send(result);
    }
  }

  _handleTest() {
    setState(() {
      isButtonDisabled = true;
    });
    loadData();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(30.0, 10.0, 0, 0),
                child: Text(
                  "STUN Server",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            height: 50.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 4.0, 30.0, 8.0),
              child: TextField(
                controller: _inputServerCtl..text = 'stun.syncthing.net',
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true, // Added this
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(80.0, 10.0, 80.0, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    "Network status",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    SizedBox(
                      height: 80.0,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text("NAT Type :",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                            Text("External IP :",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                            Text("External Port :",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                          ]),
                    ),
                    SizedBox(
                      height: 80.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          SizedBox(
                            width: 120,
                            child: Text(
                              natInfo['nat'],
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              natInfo['ip'] == 0 ? " " : natInfo['ip'],
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              natInfo['port'] == 0 ? " " : natInfo['port'],
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 30.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlineButton(
                  onPressed: isButtonDisabled ? null : _handleTest,
                  child: Text(isButtonDisabled ? "Testing ..." : "Test"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
