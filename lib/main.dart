import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'app_theme.dart';
import 'services/accelerometer_service.dart';
import 'services/gyroscope_service.dart';
import 'services/impact_detection_service.dart';
import 'services/accident_motion_detector.dart';
import 'services/network_service.dart';
import 'services/sync_queue_service.dart';
import 'services/settings_service.dart';
import 'utils/date_time_utils.dart';

@pragma('vm:entry-point')
void backgroundMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  debugPrint('[BackgroundIsolate] Started.');

  final accelService = AccelerometerService();
  final gyroService = GyroscopeService();
  final impactService = ImpactDetectionService(
    accelerometerService: accelService,
    impactThreshold: 35.0, // High threshold for crash/severe impact
  );
  
  final detector = AccidentMotionDetector(
    impactService: impactService,
    gyroscopeService: gyroService,
    impactThreshold: 35.0,
    rotationThreshold: 15.0, // Require significant abnormal rotation
    filterConfig: const FalsePositiveFilterConfig(
      walkingAccelMax: 25.0, // Suppress running/fast walking
      handShakeAccelMax: 40.0, // Suppress strong manual shaking
      handShakeGyroMax: 15.0,
      pickupAccelMax: 30.0,
      pickupGyroMax: 15.0,
      normalRotationAccelMax: 25.0,
      normalRotationGyroMax: 20.0,
      gentlePlaceAccelMax: 35.0,
    ),
    confidenceConfig: const ConfidenceAnalysisConfig(
      strongImpactThreshold: 50.0,
      strongRotationThreshold: 25.0,
      minConfidenceScore: 3.0,
      postImpactStabilityPenalty: -2.0, // CRITICAL: Reject stable phone drops
      sustainedAbnormalityBonus: 1.5, // Reward sustained erratic motion (real crash)
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
    } else if (call.method == 'simulateTestAccident') {
      debugPrint('[BackgroundIsolate] Received diagnostic test command. Firing alert...');
      channel.invokeMethod('showAccidentAlert');
    } else if (call.method == 'enforceHighConfidenceCooldown') {
      debugPrint('[BackgroundIsolate] Enforcing cooldown...');
      detector.enforceHighConfidenceCooldown();
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
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  NetworkService().init();
  SyncQueueService().init();
  DateTimeUtils.init();
  
  final settings = await SettingsService.getSettings();
  ThemeNotifier.instance.value = settings.darkTheme;
  
  runApp(const SmartSOSApp());
}

class SmartSOSApp extends StatelessWidget {
  const SmartSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeNotifier.instance,
      builder: (context, isDark, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: false,
          title: 'AI Smart SOS',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}