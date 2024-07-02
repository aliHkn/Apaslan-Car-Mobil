import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothPage(),
    );
  }
}

class BluetoothPage extends StatefulWidget {
  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothConnection? connection;
  BluetoothDevice? selectedDevice;
  bool isConnected = false;
  bool isOn = false;
  String password = "123456";

  @override
  void initState() {
    super.initState();
    FlutterBluetoothSerial.instance.state.then((state) {
      if (state == BluetoothState.STATE_ON) {
        setState(() {});
      }
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      if (state == BluetoothState.STATE_OFF) {
        setState(() {
          isConnected = false;
          connection?.dispose();
          connection = null;
        });
      }
    });
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      isConnected = false;
      connection?.dispose();
      connection = null;
    });

    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        selectedDevice = device;
        isConnected = true;
      });

      // Şifre kontrolü
      connection!.output.add(Uint8List.fromList(utf8.encode('$password\n')));
    } catch (e) {
      print('Cannot connect, exception occurred');
      print(e);
    }
  }

  void disconnect() async {
    await connection?.close();
    setState(() {
      isConnected = false;
      selectedDevice = null;
    });
  }

  Future<void> _showDeviceList(BuildContext context) async {
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: devices.map((device) {
            return ListTile(
              title: Text(device.name ?? "Unknown"),
              subtitle: Text(device.address),
              onTap: () {
                Navigator.pop(context);
                connectToDevice(device);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void sendJoystickData(double x, double y) {
    if (connection != null && isConnected) {
      String data = jsonEncode({
        'password': password,
        'status': isOn ? 1 : 0,
        'x': x,
        'y': y,
      });
      connection!.output.add(Uint8List.fromList(utf8.encode('$data\n')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apaslan Düt Düt'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bluetooth,
              color: isConnected ? Colors.green : Colors.red,
            ),
            onPressed: isConnected ? disconnect : () => _showDeviceList(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('Pedal'),
              value: isOn,
              onChanged: (value) {
                setState(() {
                  isOn = value;
                  sendJoystickData(0, 0);
                });
              },
            ),
            Spacer(flex: 3),
            Expanded(
              flex: 2,
              child: Center(
                child: isConnected
                    ? Joystick(
                        mode: JoystickMode.all,
                        listener: (details) {
                          sendJoystickData(details.x, details.y);
                        },
                      )
                    : Text('Not connected'),
              ),
            ),
            Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
