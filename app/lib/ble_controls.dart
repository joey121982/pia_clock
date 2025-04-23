import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

const String serviceUuid = "1a39d1af-53ab-447b-9368-6f36ba2a09b6";
const String characteristicRxUuid = "1a39d1af-53ab-447b-9368-6f36ba2a09b7";
const String characteristicTxUuid = "1a39d1af-53ab-447b-9368-6f36ba2a09b8";

BluetoothDevice? _connectedDevice;
BluetoothCharacteristic? _rxCharacteristic;
BluetoothCharacteristic? _txCharacteristic;

Future<bool> connectToClock() async {
  try {
    // Request necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.bluetooth] != PermissionStatus.granted ||
        statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
        statuses[Permission.bluetoothScan] != PermissionStatus.granted) {
      return false;
    }

    // Start BLE scan
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    BluetoothDevice? targetDevice;
    StreamSubscription<List<ScanResult>>? scanSubscription;
    
    final completer = Completer<void>();

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        print(result.device.platformName);
        if (result.device.platformName == 'CLOCK825') {
          targetDevice = result.device;
          FlutterBluePlus.stopScan();
          scanSubscription?.cancel();
          completer.complete();
          break;
        }
      }
    });

    // Wait for device discovery or timeout
    await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      scanSubscription?.cancel();
      throw Exception('Device not found');
    });

    if (targetDevice == null) return false;

    // Connect to device
    await targetDevice!.connect(autoConnect: false);
    _connectedDevice = targetDevice;

    // Discover services
    List<BluetoothService> services = await targetDevice!.discoverServices();
    BluetoothService? service = services.firstWhere(
      (s) => s.serviceUuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
      orElse: () => throw Exception('Service not found'),
    );

    // Get characteristics
    _rxCharacteristic = service.characteristics.firstWhere(
      (c) => c.characteristicUuid.toString().toLowerCase() == characteristicRxUuid.toLowerCase(),
      orElse: () => throw Exception('RX characteristic not found'),
    );

    _txCharacteristic = service.characteristics.firstWhere(
      (c) => c.characteristicUuid.toString().toLowerCase() == characteristicTxUuid.toLowerCase(),
      orElse: () => throw Exception('TX characteristic not found'),
    );

    // Enable notifications for TX characteristic
    await _txCharacteristic!.setNotifyValue(true);

    return true;
  } catch (e) {
    print('Connection error: $e');
    return false;
  }
}

Future<Map<String, int>> getTimeFromClock() async {
  if (_txCharacteristic == null) throw Exception('Not connected to clock');

  List<int> value = await _txCharacteristic!.read();
  String timeStr = String.fromCharCodes(value);
  List<String> parts = timeStr.split(':');
  
  if (parts.length != 4) throw Exception('Invalid time format: $timeStr');

  return {
    'hours': int.parse(parts[0]),
    'minutes': int.parse(parts[1]),
    'seconds': int.parse(parts[2]),
    'day': int.parse(parts[3]),
  };
}

Future<void> sendTimeToClock(int hours, int minutes, int seconds, int day) async {
  if (_rxCharacteristic == null) throw Exception('Not connected to clock');

  String timeStr = 
    '${hours.toString().padLeft(2, '0')}:'
    '${minutes.toString().padLeft(2, '0')}:'
    '${seconds.toString().padLeft(2, '0')}:$day';

  await _rxCharacteristic!.write(timeStr.codeUnits, withoutResponse: false);
}