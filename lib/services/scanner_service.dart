import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/signal_device.dart';
import 'classifier.dart';
import 'storage_service.dart';

/// Log-distance path-loss estimate. Rough: walls, antennas and phones change it a lot.
double estimateDistance(double rssi, bool wifi) {
  final ref = wifi ? -40.0 : -59.0; // RSSI at 1 m
  final n = wifi ? 2.8 : 2.2;
  final d = pow(10, (ref - rssi) / (10 * n)).toDouble();
  return d.clamp(0.2, 200.0).toDouble();
}

class ScannerService extends ChangeNotifier {
  final Classifier classifier;
  final StorageService storage;
  ScannerService(this.classifier, this.storage);

  final Map<String, SignalDevice> _devices = {};
  bool running = false;
  String? error;
  String lanStatus = 'Not scanned yet';
  bool lanScanning = false;

  Timer? _wifiTimer, _uiTimer;
  StreamSubscription? _bleSub;

  List<SignalDevice> get live {
    final now = DateTime.now();
    return _devices.values
        .where((d) => d.source != 'lan' && now.difference(d.lastSeen).inSeconds < 25)
        .toList()
      ..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));
  }

  List<SignalDevice> get lan =>
      _devices.values.where((d) => d.source == 'lan').toList()..sort((a, b) => (a.ip ?? '').compareTo(b.ip ?? ''));

  List<SignalDevice> get suspects {
    final list = [...live, ...lan].where((d) => d.isSuspect).toList();
    list.sort((a, b) => b.suspicion.compareTo(a.suspicion));
    return list;
  }

  // ---------- lifecycle ----------
  Future<void> start() async {
    if (running) return;
    running = true;
    error = null;
    _wifiTimer = Timer.periodic(const Duration(seconds: 8), (_) => _wifiScan());
    _wifiScan();
    _bleSub = FlutterBluePlus.scanResults.listen(_onBle, onError: (e) => error = 'BLE: $e');
    _bleLoop();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => notifyListeners());
  }

  Future<void> stop() async {
    running = false;
    _wifiTimer?.cancel();
    _uiTimer?.cancel();
    await _bleSub?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await storage.flush();
  }

  // ---------- Wi-Fi ----------
  Future<void> _wifiScan() async {
    try {
      final can = await WiFiScan.instance.canStartScan(askPermissions: false);
      if (can == CanStartScan.yes) await WiFiScan.instance.startScan();
      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: false);
      if (canGet != CanGetScannedResults.yes) {
        error = 'Wi-Fi results unavailable ($canGet). Is Location turned ON?';
        return;
      }
      final aps = await WiFiScan.instance.getScannedResults();
      for (final ap in aps) {
        final bssid = ap.bssid.toUpperCase();
        final d = SignalDevice(
          id: 'wifi:$bssid',
          source: 'wifi',
          name: ap.ssid,
          address: bssid,
          rssi: ap.level.toDouble(),
          frequency: ap.frequency,
          security: ap.capabilities,
        );
        d.extra['band'] = ap.frequency > 5900 ? '6 GHz' : (ap.frequency > 4900 ? '5 GHz' : '2.4 GHz');
        d.extra['channel'] = '${_channel(ap.frequency)}';
        _commit(d, classifier.classifyWifi);
      }
    } catch (e) {
      error = 'Wi-Fi: $e';
    }
  }

  int _channel(int f) {
    if (f == 2484) return 14;
    if (f < 2484) return (f - 2407) ~/ 5;
    if (f > 5900) return (f - 5950) ~/ 5;
    return (f - 5000) ~/ 5;
  }

  // ---------- BLE ----------
  Future<void> _bleLoop() async {
    while (running) {
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 12),
          androidScanMode: AndroidScanMode.lowLatency,
          continuousUpdates: true,
        );
        await FlutterBluePlus.isScanning.where((s) => s == false).first;
      } catch (e) {
        error = 'BLE: $e';
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  void _onBle(List<ScanResult> results) {
    final now = DateTime.now();
    for (final r in results) {
      final mac = r.device.remoteId.str.toUpperCase();
      final id = 'ble:$mac';
      final old = _devices[id];
      if (old != null && now.difference(old.lastSeen).inMilliseconds < 600) continue;
      final adv = r.advertisementData;
      final d = SignalDevice(
        id: id,
        source: 'ble',
        name: adv.advName.isNotEmpty ? adv.advName : r.device.platformName,
        address: mac,
        rssi: r.rssi.toDouble(),
      );
      d.mfg = Map<int, List<int>>.from(adv.manufacturerData);
      d.uuids = adv.serviceUuids.map((g) => g.str.toLowerCase()).toSet();
      d.extra['connectable'] = '${adv.connectable}';
      if (adv.txPowerLevel != null) d.extra['advertised_tx_power'] = '${adv.txPowerLevel} dBm';
      if (d.uuids.isNotEmpty) d.extra['service_uuids'] = d.uuids.join(', ');
      if (d.mfg.isNotEmpty) {
        d.extra['manufacturer_ids'] = d.mfg.keys.join(', ');
      }
      _commit(d, classifier.classifyBle);
    }
  }

  // ---------- merge ----------
  void _commit(SignalDevice n, void Function(SignalDevice) classify) {
    final now = DateTime.now();
    final old = _devices[n.id];
    if (old != null) {
      if (n.rssi != null && old.rssi != null) n.rssi = old.rssi! * 0.7 + n.rssi! * 0.3;
      n.firstSeen = old.firstSeen;
      n.trusted = old.trusted;
      if (n.name.isEmpty) n.name = old.name;
      for (final e in old.mfg.entries) {
        n.mfg.putIfAbsent(e.key, () => e.value);
      }
      n.uuids.addAll(old.uuids);
    } else {
      final h = storage.get(n.id);
      if (h != null) {
        n.firstSeen = DateTime.tryParse('${h['firstSeen']}') ?? now;
        n.trusted = h['trusted'] == true;
      }
    }
    n.lastSeen = now;
    if (n.rssi != null) n.distance = estimateDistance(n.rssi!, n.source == 'wifi');
    classify(n);
    _devices[n.id] = n;
    storage.put(n);
  }

  void setTrusted(SignalDevice d, bool v) {
    d.trusted = v;
    storage.put(d);
    notifyListeners();
  }

  String reportJson() => const JsonEncoder.withIndent('  ').convert({
        'generated': DateTime.now().toIso8601String(),
        'suspects': suspects.map((d) => d.toReport()).toList(),
      });

  // ---------- LAN scan ----------
  Future<void> scanLan() async {
    if (lanScanning) return;
    lanScanning = true;
    lanStatus = 'Preparing…';
    _devices.removeWhere((k, v) => v.source == 'lan');
    notifyListeners();
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      final gw = await info.getWifiGatewayIP();
      if (ip == null || !ip.contains('.')) {
        lanStatus = 'Not connected to a Wi-Fi network';
        return;
      }
      final base = ip.substring(0, ip.lastIndexOf('.') + 1);
      const ports = [80, 443, 554, 8000, 8080, 8554, 34567, 37777];
      final found = <String, List<int>>{};
      for (int start = 1; start <= 254; start += 24) {
        final batch = <Future<void>>[];
        for (int i = start; i < start + 24 && i <= 254; i++) {
          final host = '$base$i';
          if (host == ip) continue;
          batch.add(_probeHost(host, ports, found));
        }
        await Future.wait(batch);
        lanStatus = 'Scanning $base… ${min(start + 23, 254)}/254';
        notifyListeners();
      }
      final arp = await _readArp();
      await Future.wait(found.entries.map((e) async {
        final host = e.key;
        final d = SignalDevice(id: 'lan:$host', source: 'lan', ip: host, address: arp[host]);
        try {
          final rev = await InternetAddress(host).reverse().timeout(const Duration(milliseconds: 800));
          if (rev.host != host) d.name = rev.host;
        } catch (_) {}
        for (final p in [80, 8080]) {
          if (e.value.contains(p)) {
            await _httpBanner(host, p, d);
            break;
          }
        }
        if (host == gw && d.name.isEmpty) d.name = 'Gateway';
        classifier.classifyLan(d, ports: e.value, isGateway: host == gw);
        _devices[d.id] = d;
        storage.put(d);
      }));
      lanStatus = 'Done: ${found.length} hosts responded';
    } catch (e) {
      lanStatus = 'Error: $e';
    } finally {
      lanScanning = false;
      notifyListeners();
    }
  }

  Future<void> _probeHost(String host, List<int> ports, Map<String, List<int>> found) async {
    bool alive = false;
    final open = <int>[];
    await Future.wait(ports.map((p) async {
      try {
        final s = await Socket.connect(host, p, timeout: const Duration(milliseconds: 500));
        s.destroy();
        alive = true;
        open.add(p);
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 111) alive = true; // connection refused = host is up
      } catch (_) {}
    }));
    if (alive) {
      open.sort();
      found[host] = open;
    }
  }

  Future<Map<String, String>> _readArp() async {
    final m = <String, String>{};
    try {
      final lines = await File('/proc/net/arp').readAsLines();
      for (final l in lines.skip(1)) {
        final p = l.trim().split(RegExp(r'\s+'));
        if (p.length >= 4 && p[3] != '00:00:00:00:00:00') m[p[0]] = p[3].toUpperCase();
      }
    } catch (_) {} // blocked on most Android 10+ devices
    return m;
  }

  Future<void> _httpBanner(String host, int port, SignalDevice d) async {
    final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
    try {
      final req = await c.getUrl(Uri.parse('http://$host:$port/'));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      final server = resp.headers.value('server');
      if (server != null) d.extra['http_server'] = server;
      final auth = resp.headers.value('www-authenticate');
      if (auth != null) d.extra['http_auth'] = auth;
      final bytes = <int>[];
      await for (final chunk in resp.timeout(const Duration(seconds: 2))) {
        bytes.addAll(chunk);
        if (bytes.length > 4096) break;
      }
      final m = RegExp(r'<title[^>]*>([^<]{1,80})', caseSensitive: false)
          .firstMatch(utf8.decode(bytes, allowMalformed: true));
      if (m != null) d.extra['http_title'] = m.group(1)!.trim();
    } catch (_) {
    } finally {
      c.close(force: true);
    }
  }
}
