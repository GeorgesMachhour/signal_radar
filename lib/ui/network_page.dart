import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import 'details_sheet.dart';
import 'widgets.dart';

class NetworkPage extends StatelessWidget {
  final ScannerService svc;
  const NetworkPage(this.svc, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final list = svc.lan;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              FilledButton.icon(
                onPressed: svc.lanScanning ? null : svc.scanLan,
                icon: const Icon(Icons.search),
                label: const Text('Scan my Wi-Fi network'),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(svc.lanStatus, style: const TextStyle(fontSize: 12))),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Only scan networks you own or are authorized to test.',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => DeviceTile(list[i], onTap: () => showDeviceSheet(context, svc, list[i])),
            ),
          ),
        ]);
      },
    );
  }
}
