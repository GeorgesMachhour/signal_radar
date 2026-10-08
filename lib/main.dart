import 'package:flutter/material.dart';
import 'services/classifier.dart';
import 'services/scanner_service.dart';
import 'services/storage_service.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  final classifier = Classifier();
  await classifier.load();
  runApp(SignalRadarApp(ScannerService(classifier, storage)));
}

class SignalRadarApp extends StatelessWidget {
  final ScannerService svc;
  const SignalRadarApp(this.svc, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: HomeShell(svc),
    );
  }
}
