import 'package:flutter/material.dart';
import '../models/signal_device.dart';
import '../services/scanner_service.dart';
import 'details_sheet.dart';
import 'radar_painter.dart';

class RadarPage extends StatefulWidget {
  final ScannerService svc;
  const RadarPage(this.svc, {super.key});
  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  double _range = 25;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.svc, _ctrl]),
      builder: (context, _) {
        final devs = widget.svc.live.where((d) => d.distance != null).toList();
        final sus = devs.where((d) => d.isSuspect).length;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final r in [10.0, 25.0, 50.0])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${r.toInt()} m'),
                    selected: _range == r,
                    onSelected: (_) => setState(() => _range = r),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(builder: (context, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    return GestureDetector(
                      onTapUp: (t) {
                        final hit = RadarPainter.hitDevice(devs, size, _range, t.localPosition);
                        if (hit != null) showDeviceSheet(context, widget.svc, hit);
                      },
                      child: CustomPaint(size: size, painter: RadarPainter(devs, _range, _ctrl.value)),
                    );
                  }),
                ),
              ),
            ),
          ),
          Wrap(spacing: 10, runSpacing: 4, alignment: WrapAlignment.center, children: [
            for (final k in DeviceKind.values.where((k) => k != DeviceKind.lanHost))
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: k.color),
                const SizedBox(width: 4),
                Text(k.label, style: const TextStyle(fontSize: 11)),
              ]),
          ]),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${devs.length} emitters · $sus suspicious · tap a dot for details',
                style: const TextStyle(fontSize: 12)),
          ),
        ]);
      },
    );
  }
}
