import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'app_theme.dart';
import 'services/accelerometer_service.dart';
import 'services/gyroscope_service.dart';
import 'services/impact_detection_service.dart';
import 'services/accident_motion_detector.dart';

@pragma('vm:entry-point')
void backgroundMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  debugPrint('[BackgroundIsolate] Started.');

  final accelService = AccelerometerService();
  final gyroService = GyroscopeService();
  final impactService = ImpactDetectionService(
    accelerometerService: accelService,
    impactThreshold: 20.0,
  );
  
  final detector = AccidentMotionDetector(
    impactService: impactService,
    gyroscopeService: gyroService,
    impactThreshold: 20.0,
    rotationThreshold: 8.0,
    filterConfig: const FalsePositiveFilterConfig(
      handShakeAccelMax: 25.0, // allow harder test shakes to pass through filter
      pickupAccelMax: 25.0,
    ),
    confidenceConfig: const ConfidenceAnalysisConfig(
      strongImpactThreshold: 22.0,
      strongRotationThreshold: 10.0,
      minConfidenceScore: 2.0,
      postImpactStabilityPenalty: 0.0, // Disable stability penalty for testing so it doesn't reject manual tests as "phone drops"
    ),
  );
  
  int accelCount = 0;
  int gyroCount = 0;
  
  const channel = MethodChannel('com.example.ai_smart_sos/background_sensor');
  
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onAccelerometerData') {
      accelCount++;
      if (accelCount % 100 == 0) {
        debugPrint('[BackgroundIsolate] Received $accelCount accelerometer events (e.g. x=${call.arguments['x']})');
      }
      final args = call.arguments as Map;
      accelService.injectReading(
        (args['x'] as num).toDouble(),
        (args['y'] as num).toDouble(),
        (args['z'] as num).toDouble(),
      );
    } else if (call.method == 'onGyroscopeData') {
      gyroCount++;
      if (gyroCount % 100 == 0) {
        debugPrint('[BackgroundIsolate] Received $gyroCount gyroscope events (e.g. x=${call.arguments['x']})');
      }
      final args = call.arguments as Map;
      gyroService.injectReading(
        (args['x'] as num).toDouble(),
        (args['y'] as num).toDouble(),
        (args['z'] as num).toDouble(),
      );
    }
  });
  
  detector.eventStream.listen((event) {
    if (event.type == MotionEventType.highConfidenceAccidentDetected) {
      debugPrint('[BackgroundIsolate] High-confidence accident detected! Waking UI.');
      channel.invokeMethod('showAccidentAlert');
    }
  });
  
  detector.startDetection();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartSOSApp());
}

class SmartSOSApp extends StatelessWidget {
  const SmartSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Smart SOS',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}