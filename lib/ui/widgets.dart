import 'package:flutter/material.dart';
import '../models/signal_device.dart';

class DeviceTile extends StatelessWidget {
  final SignalDevice d;
  final VoidCallback onTap;
  const DeviceTile(this.d, {required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final sub = [d.address, d.ip, d.vendor].whereType<String>().join(' · ');
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.circle, color: d.kind.color),
      title: Text(d.name.isEmpty ? '(no name) · ${d.kind.label}' : d.name),
      subtitle: Text(sub.isEmpty ? d.kind.label : '${d.kind.label}\n$sub'),
      isThreeLine: sub.isNotEmpty,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (d.isSuspect) const Icon(Icons.warning_amber, color: Colors.redAccent, size: 18),
          Text(d.distanceText),
          Text(d.rssiText, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }
}
