
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const Ash7nApp());
}

class Ash7nApp extends StatelessWidget {
  const Ash7nApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ash7n',
      theme: ThemeData.dark(),
      home: const ScanScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _controller;
  bool _ready = false;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    await Permission.camera.request();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller.initialize();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    textRecognizer.close();
    super.dispose();
  }

  Future<void> scan() async {
    final image = await _controller.takePicture();
    final inputImage = InputImage.fromFile(File(image.path));
    final text = await textRecognizer.processImage(inputImage);

    final raw = text.text.replaceAll(RegExp(r'\s+'), '');
    final code = RegExp(r'\d{12,16}').firstMatch(raw)?.group(0);

    if (code == null) {
      showMsg("لم يتم العثور على كود");
      return;
    }

    final network = detectNetwork(code);
    if (network == "UNKNOWN") {
      chooseNetwork(code);
    } else {
      dial(network, code);
    }
  }

  String detectNetwork(String code) {
    if (code.startsWith("858")) return "VODAFONE";
    if (code.startsWith("102")) return "ORANGE";
    if (code.startsWith("556")) return "ETISALAT";
    if (code.startsWith("111")) return "WE";
    return "UNKNOWN";
  }

  void chooseNetwork(String code) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item("Vodafone", () => dial("VODAFONE", code)),
          item("Orange", () => dial("ORANGE", code)),
          item("Etisalat", () => dial("ETISALAT", code)),
          item("WE", () => dial("WE", code)),
        ],
      ),
    );
  }

  Widget item(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void dial(String network, String code) async {
    String ussd = "";
    if (network == "VODAFONE") ussd = "*858*1*$code#";
    if (network == "ORANGE") ussd = "*102*$code#";
    if (network == "ETISALAT") ussd = "*556*$code#";
    if (network == "WE") ussd = "*111*$code#";

    final uri = Uri.parse("tel:${Uri.encodeComponent(ussd)}");
    await launchUrl(uri);
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ready
          ? Stack(
              children: [
                CameraPreview(_controller),
                Center(
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: scan,
                      child: const Text("Scan Card"),
                    ),
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
