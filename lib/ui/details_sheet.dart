import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/signal_device.dart';
import '../services/scanner_service.dart';

void showDeviceSheet(BuildContext context, ScannerService svc, SignalDevice d) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(builder: (ctx, setS) {
      final rows = <MapEntry<String, String?>>[
        MapEntry('Type', d.kind.label),
        MapEntry('Name', d.name.isEmpty ? '(none / hidden)' : d.name),
        MapEntry('MAC / BSSID', d.address),
        MapEntry('IP', d.ip),
        MapEntry('Vendor', d.vendor),
        MapEntry('Signal', d.rssiText),
        MapEntry('Distance (approx.)', d.distanceText),
        MapEntry('Frequency', d.frequency == null ? null : '${d.frequency} MHz'),
        MapEntry('Security', d.security),
        for (final e in d.extra.entries) MapEntry(e.key, e.value),
        MapEntry('First seen', d.firstSeen.toLocal().toString().split('.').first),
        MapEntry('Last seen', d.lastSeen.toLocal().toString().split('.').first),
        MapEntry('Suspicion score', '${d.suspicion}/100'),
      ];
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in rows.where((r) => r.value != null && r.value!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: Text(r.key, style: const TextStyle(color: Colors.white54))),
                  Expanded(child: SelectableText(r.value!)),
                ]),
              ),
            if (d.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Why flagged', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final r in d.reasons) Text('• $r'),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trusted (mine / known)'),
              value: d.trusted,
              onChanged: (v) {
                svc.setTrusted(d, v);
                setS(() {});
              },
            ),
            Row(children: [
              if (d.address != null)
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy MAC'),
                  onPressed: () => Clipboard.setData(ClipboardData(text: d.address!)),
                ),
              if (d.ip != null)
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy IP'),
                  onPressed: () => Clipboard.setData(ClipboardData(text: d.ip!)),
                ),
            ]),
          ]),
        ),
      );
    }),
  );
}
