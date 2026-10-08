import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/signal_device.dart';

class Classifier {
  Map<String, dynamic> _oui = {};
  Map<String, dynamic> _mfg = {};
  Map<String, dynamic> _trackerUuids = {};
  Map<String, dynamic> _ports = {};
  late RegExp _cam, _camAp, _radar, _audio, _lanHttp;

  Future<void> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/oui_db.json')) as Map<String, dynamic>;
    _oui = Map<String, dynamic>.from(j['oui']);
    _mfg = Map<String, dynamic>.from(j['mfg']);
    _trackerUuids = Map<String, dynamic>.from(j['tracker_uuids']);
    _ports = Map<String, dynamic>.from(j['lan_ports']);
    RegExp r(String k) => RegExp(j[k] as String, caseSensitive: false);
    _cam = r('camera_name');
    _camAp = r('camera_ap');
    _radar = r('radar_name');
    _audio = r('bt_audio_name');
    _lanHttp = r('lan_http_kw');
  }

  Map<String, dynamic>? lookupOui(String? mac) {
    if (mac == null || mac.length < 8) return null;
    final v = _oui[mac.substring(0, 8).toUpperCase()];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  static bool isRandomMac(String mac) {
    if (mac.length < 2) return false;
    final b = int.tryParse(mac.substring(0, 2), radix: 16);
    return b != null && (b & 0x02) != 0;
  }

  void _reset(SignalDevice d, DeviceKind k) {
    d.suspicion = 0;
    d.reasons.clear();
    d.kind = k;
  }

  void _add(SignalDevice d, int pts, String reason) {
    d.suspicion = min(100, d.suspicion + pts);
    d.reasons.add(reason);
  }

  void _vendorCheck(SignalDevice d) {
    final addr = d.address;
    if (addr == null) return;
    if (isRandomMac(addr)) {
      d.extra['mac_type'] = 'Randomized / locally administered address';
      return;
    }
    final o = lookupOui(addr);
    if (o != null) {
      d.vendor = o['vendor'] as String?;
      if (o['cat'] == 'camera') {
        d.kind = DeviceKind.ipCamera;
        _add(d, 55, 'MAC belongs to ${d.vendor}, a surveillance camera/recorder maker');
      }
    }
  }

  void classifyWifi(SignalDevice d) {
    _reset(d, DeviceKind.wifiRouter);
    _vendorCheck(d);
    final n = d.name;
    if (n.isEmpty) {
      _add(d, 5, 'Hidden SSID');
      if ((d.distance ?? 99) < 5) _add(d, 10, 'Hidden network very close to you');
    } else if (_cam.hasMatch(n)) {
      d.kind = DeviceKind.ipCamera;
      _add(d, 45, 'Network name looks like a camera ("$n")');
    } else if (_camAp.hasMatch(n)) {
      d.kind = DeviceKind.ipCamera;
      _add(d, 35, 'Network name matches cheap hidden-camera AP pattern ("$n")');
    }
    if (_radar.hasMatch(n)) {
      d.kind = DeviceKind.radarSensor;
      _add(d, 30, 'Name suggests radar / presence sensor');
    }
    final caps = (d.security ?? '').toUpperCase();
    final open = !(caps.contains('WPA') || caps.contains('WEP') || caps.contains('SAE') || caps.contains('RSN'));
    if (open && d.kind == DeviceKind.ipCamera) _add(d, 15, 'Camera-like network is open (no password)');
  }

  void classifyBle(SignalDevice d) {
    _reset(d, DeviceKind.ble);
    _vendorCheck(d);
    for (final e in d.mfg.entries) {
      final nm = _mfg['${e.key}'];
      if (nm != null) d.vendor ??= nm as String;
    }
    var tracker = false;
    final apple = d.mfg[76];
    if (apple != null && apple.isNotEmpty && apple.first == 0x12) {
      tracker = true;
      _add(d, 40, 'Apple Find My beacon (AirTag or similar item tracker)');
    }
    for (final u in d.uuids) {
      final t = _trackerUuids[u];
      if (t != null && !tracker) {
        tracker = true;
        _add(d, 40, '$t tracker service advertised');
      }
    }
    if (tracker) d.kind = DeviceKind.tracker;
    final n = d.name;
    if (n.isNotEmpty) {
      if (_radar.hasMatch(n)) {
        d.kind = DeviceKind.radarSensor;
        _add(d, 30, 'Name suggests radar / presence sensor ("$n")');
      } else if (_cam.hasMatch(n)) {
        d.kind = DeviceKind.ipCamera;
        _add(d, 45, 'BLE name looks like a camera ("$n")');
      } else if (d.kind == DeviceKind.ble && _audio.hasMatch(n)) {
        d.kind = DeviceKind.bluetooth;
      }
    }
  }

  void classifyLan(SignalDevice d, {required List<int> ports, required bool isGateway}) {
    _reset(d, DeviceKind.lanHost);
    _vendorCheck(d);
    if (isGateway) {
      d.kind = DeviceKind.wifiRouter;
      d.extra['role'] = 'Default gateway (router)';
    }
    if (ports.contains(554) || ports.contains(8554)) {
      d.kind = DeviceKind.ipCamera;
      _add(d, 50, 'RTSP port open (video streaming)');
    } else if (ports.any((p) => p == 37777 || p == 34567 || p == 8000)) {
      d.kind = DeviceKind.ipCamera;
      _add(d, 45, 'Port typical of DVR / IP-camera protocols is open');
    }
    final blob = '${d.extra['http_server'] ?? ''} ${d.extra['http_title'] ?? ''} ${d.extra['http_auth'] ?? ''}';
    if (_lanHttp.hasMatch(blob)) {
      d.kind = DeviceKind.ipCamera;
      _add(d, 40, 'Web interface identifies as camera/recorder');
    }
    d.extra['open_ports'] =
        ports.isEmpty ? 'none of the probed ports' : ports.map((p) => '$p ${_ports['$p'] ?? ''}'.trim()).join(', ');
  }
}
