import 'package:flutter/material.dart';

enum DeviceKind { wifiRouter, ipCamera, radarSensor, bluetooth, ble, tracker, lanHost, other }

extension DeviceKindX on DeviceKind {
  String get label {
    switch (this) {
      case DeviceKind.wifiRouter: return 'Wi-Fi router / AP';
      case DeviceKind.ipCamera: return 'IP camera';
      case DeviceKind.radarSensor: return 'Radar / presence sensor';
      case DeviceKind.bluetooth: return 'Bluetooth (audio)';
      case DeviceKind.ble: return 'BLE device';
      case DeviceKind.tracker: return 'Item tracker';
      case DeviceKind.lanHost: return 'Network host';
      case DeviceKind.other: return 'Other emitter';
    }
  }

  Color get color {
    switch (this) {
      case DeviceKind.wifiRouter: return const Color(0xFF2196F3);
      case DeviceKind.ipCamera: return const Color(0xFFFF5252);
      case DeviceKind.radarSensor: return const Color(0xFFFFA726);
      case DeviceKind.bluetooth: return const Color(0xFF26C6DA);
      case DeviceKind.ble: return const Color(0xFFAB47BC);
      case DeviceKind.tracker: return const Color(0xFFFFEE58);
      case DeviceKind.lanHost: return const Color(0xFF90A4AE);
      case DeviceKind.other: return const Color(0xFF9E9E9E);
    }
  }
}

class SignalDevice {
  final String id;
  final String source; // wifi | ble | lan
  DeviceKind kind;
  String name;
  String? address; // MAC / BSSID
  String? ip;
  String? vendor;
  double? rssi;
  double? distance;
  int? frequency;
  String? security;
  final Map<String, String> extra = {};
  Map<int, List<int>> mfg = {};
  Set<String> uuids = {};
  DateTime firstSeen = DateTime.now();
  DateTime lastSeen = DateTime.now();
  int suspicion = 0;
  final List<String> reasons = [];
  bool trusted = false;

  SignalDevice({
    required this.id,
    required this.source,
    this.kind = DeviceKind.other,
    this.name = '',
    this.address,
    this.ip,
    this.rssi,
    this.frequency,
    this.security,
  });

  bool get isSuspect => suspicion >= 40 && !trusted;

  String get distanceText =>
      distance == null ? '—' : '~${distance!.toStringAsFixed(distance! < 10 ? 1 : 0)} m';
  String get rssiText => rssi == null ? '—' : '${rssi!.round()} dBm';

  Map<String, dynamic> toHistory() => {
        'name': name,
        'address': address,
        'vendor': vendor,
        'kind': kind.name,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'trusted': trusted,
      };

  Map<String, dynamic> toReport() => {
        'type': kind.label,
        'name': name,
        'mac': address,
        'ip': ip,
        'vendor': vendor,
        'rssi_dbm': rssi?.round(),
        'distance_m': distance == null ? null : double.parse(distance!.toStringAsFixed(1)),
        'frequency_mhz': frequency,
        'security': security,
        'suspicion': suspicion,
        'reasons': reasons,
        'details': extra,
        'first_seen': firstSeen.toIso8601String(),
        'last_seen': lastSeen.toIso8601String(),
      };
}
