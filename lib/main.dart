import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:screen_capturer/screen_capturer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupInitialService();
  runApp(const MyApp());
}

setupInitialService() async {
  try {
    bool isAllowed = await screenCapturer.isAccessAllowed();
    if (!isAllowed) {
      await screenCapturer.requestAccess();
      setupInitialService();
    }
  } catch (e) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Root of the application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezy Stuff',
      scrollBehavior: CupertinoScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ezy Stuff'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isMonitoring = false;
  late Stopwatch _stopwatch;
  Timer? _uiTimer;
  Timer? _screenshotTimer; // Timer for automatic screenshot capturing

  List<Uint8List?> capturedImages = [];

  // Replace with your actual API key
  final String _apiKey = 'MCtK4B4oBnF21Jfj5rLmxPGkX9CFe3kj';
  final String _uploadUrl = 'https://www.imghippo.com/v1/upload';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _screenshotTimer?.cancel(); // Cancel the screenshot timer
    super.dispose();
  }

  // Function to capture screenshots
  Future<void> captureScreenshot() async {
    try {
      CapturedData? capturedData =
          await screenCapturer.capture(mode: CaptureMode.screen, silent: true);
      if (capturedData != null) {
        setState(() {
          // Optionally limit the number of screenshots stored
          if (capturedImages.length >= 50) {
            capturedImages.removeAt(0); // Remove the oldest screenshot
          }
          capturedImages.add(capturedData.imageBytes);
        });

        uploadScreenshot(capturedImages.last!);
      }
    } on PlatformException catch (e) {
      // Handle exception if screenshot fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture screenshot: ${e.message}')),
      );
    }
  }

  // Function to upload screenshots to Freeimage.host
  Future<void> uploadScreenshot(Uint8List imageBytes) async {
    try {
      var uri = Uri.parse(_uploadUrl);
      var request = MultipartRequest('POST', uri);

      // Add fields
      request.fields['api_key'] = _apiKey;
      // request.fields['action'] = 'upload';
      // request.fields['format'] = 'json';

      // Add the image file
      request.files.add(
        MultipartFile.fromBytes(
          'file', // Field name for the file
          imageBytes,
          filename: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
          contentType: MediaType('image', 'png'),
        ),
      );

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot uploaded successfully:')),
        );
      } else {
        // Handle HTTP errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Upload failed with status code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Handle any other exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during upload: $e')),
      );
    }
  }

  // Toggle monitoring state
  void toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _startMonitoring();
      } else {
        _pauseMonitoring();
      }
    });
  }

  // Start the stopwatch and timers
  void _startMonitoring() {
    _stopwatch.start();
    // UI Timer: Updates the UI every 30 milliseconds
    _uiTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {}); // Update the UI
    });
    // Screenshot Timer: Captures a screenshot every 10 seconds
    _screenshotTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      captureScreenshot();
    });
  }

  // Pause the stopwatch and cancel timers
  void _pauseMonitoring() {
    _stopwatch.stop();
    _uiTimer?.cancel();
    _screenshotTimer?.cancel(); // Cancel the screenshot timer
  }

  // Format the elapsed time
  String _formattedTime() {
    final elapsed = _stopwatch.elapsed;
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    final centiseconds = (elapsed.inMilliseconds.remainder(1000) / 10).floor();

    if (hours > 0) {
      return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}.${_twoDigits(centiseconds)}';
    } else {
      return '${_twoDigits(minutes)}:${_twoDigits(seconds)}.${_twoDigits(centiseconds)}';
    }
  }

  // Helper function to ensure two digits
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            // Align items to the center
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Timer Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _formattedTime(),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Tracking Status
              Text(
                'Tracking status: ${_isMonitoring ? "Tracking" : "Not tracking"}',
                style: TextStyle(
                  fontSize: 20,
                  color: _isMonitoring ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // Toggle Button
              ElevatedButton(
                onPressed: toggleMonitoring,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor:
                      _isMonitoring ? Colors.red : Colors.green, // Button color
                ),
                child: Icon(
                  _isMonitoring ? Icons.stop : Icons.play_arrow,
                  size: 34, // Corrected Icon size
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Capture Screenshot Button (optional)

              capturedImages.isNotEmpty
                  ? ListView.builder(
                      itemCount: capturedImages.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final image = capturedImages[index];
                        if (image != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Image.memory(
                              image,
                              height: 100,
                              width: 100,
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    )
                  : const Center(
                      child: Text(
                        'No screenshots captured.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
