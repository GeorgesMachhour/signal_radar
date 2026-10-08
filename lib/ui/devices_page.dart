import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import 'details_sheet.dart';
import 'widgets.dart';

class DevicesPage extends StatelessWidget {
  final ScannerService svc;
  const DevicesPage(this.svc, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final list = svc.live;
        if (list.isEmpty) return const Center(child: Text('Scanning… nothing detected yet'));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => DeviceTile(list[i], onTap: () => showDeviceSheet(context, svc, list[i])),
        );
      },
    );
  }
}
