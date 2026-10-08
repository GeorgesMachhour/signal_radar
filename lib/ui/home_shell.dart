import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/scanner_service.dart';
import 'devices_page.dart';
import 'network_page.dart';
import 'radar_page.dart';
import 'suspects_page.dart';

class HomeShell extends StatefulWidget {
  final ScannerService svc;
  const HomeShell(this.svc, {super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  String? _permMsg;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final r = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (!(r[Permission.locationWhenInUse]?.isGranted ?? false)) {
      setState(() => _permMsg = 'Location permission is required for Wi-Fi/BLE scanning.');
    }
    try {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {}
    await widget.svc.start();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    final pages = [
      RadarPage(svc),
      DevicesPage(svc),
      SuspectsPage(svc),
      NetworkPage(svc),
    ];
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final msg = _permMsg ?? svc.error;
        return Scaffold(
          appBar: AppBar(title: const Text('Signal Radar'), centerTitle: true),
          body: Column(children: [
            if (msg != null)
              Container(
                width: double.infinity,
                color: Colors.orange.shade900,
                padding: const EdgeInsets.all(8),
                child: Text(msg, style: const TextStyle(fontSize: 12)),
              ),
            Expanded(child: pages[_i]),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _i,
            onDestinationSelected: (i) => setState(() => _i = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.radar), label: 'Radar'),
              const NavigationDestination(icon: Icon(Icons.list), label: 'Devices'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: svc.suspects.isNotEmpty,
                  label: Text('${svc.suspects.length}'),
                  child: const Icon(Icons.warning_amber),
                ),
                label: 'Suspects',
              ),
              const NavigationDestination(icon: Icon(Icons.lan), label: 'Network'),
            ],
          ),
        );
      },
    );
  }
}
