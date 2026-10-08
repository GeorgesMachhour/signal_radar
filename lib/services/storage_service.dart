import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/signal_device.dart';

/// Simple JSON file storage (no SQL).
class StorageService {
  File? _file;
  Map<String, dynamic> _data = {};
  Timer? _timer;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/signal_radar_history.json');
    try {
      if (await _file!.exists()) {
        _data = Map<String, dynamic>.from(jsonDecode(await _file!.readAsString()));
      }
    } catch (_) {
      _data = {};
    }
  }

  Map<String, dynamic>? get(String id) {
    final v = _data[id];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  void put(SignalDevice d) {
    _data[d.id] = d.toHistory();
    _timer ??= Timer(const Duration(seconds: 5), flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_data.length > 2000) {
      final entries = _data.entries.toList()
        ..sort((a, b) => ('${a.value['lastSeen']}').compareTo('${b.value['lastSeen']}'));
      for (final e in entries.take(_data.length - 2000)) {
        _data.remove(e.key);
      }
    }
    try {
      await _file?.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }

  Future<void> clear() async {
    _data = {};
    await flush();
  }
}
