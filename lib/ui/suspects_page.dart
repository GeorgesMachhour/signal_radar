import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/scanner_service.dart';
import 'details_sheet.dart';

class SuspectsPage extends StatelessWidget {
  final ScannerService svc;
  const SuspectsPage(this.svc, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final list = svc.suspects;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: Text('${list.length} possible surveillance / tracking devices.\n'
                    'Heuristic guesses, not proof. Mark your own devices as Trusted.',
                    style: const TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy report'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: svc.reportJson()));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('JSON report copied')));
                },
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Nothing suspicious so far'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final d = list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: InkWell(
                          onTap: () => showDeviceSheet(context, svc, d),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(Icons.circle, size: 12, color: d.kind.color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(d.name.isEmpty ? d.kind.label : '${d.name} · ${d.kind.label}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Text(d.distanceText),
                              ]),
                              const SizedBox(height: 4),
                              Text([d.address, d.ip, d.vendor].whereType<String>().join(' · '),
                                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: d.suspicion / 100,
                                color: Colors.redAccent,
                                backgroundColor: Colors.white12,
                              ),
                              const SizedBox(height: 6),
                              for (final r in d.reasons) Text('• $r', style: const TextStyle(fontSize: 12)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}
