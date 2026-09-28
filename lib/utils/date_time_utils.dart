import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Date and Time utility for AI Smart SOS.
/// 
/// Ensures all dates and times are handled correctly for the target timezone:
/// Asia/Kolkata (IST: UTC+05:30)
class DateTimeUtils {
  static const String istTimezoneName = 'Asia/Kolkata';
  static bool _initialized = false;
  
  static void init() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Gets the Location object for India Standard Time (IST).
  static tz.Location get istLocation {
    init();
    return tz.getLocation(istTimezoneName);
  }

  /// Converts any [DateTime] (UTC or local) to the IST Timezone.
  static tz.TZDateTime toIST(DateTime dateTime) {
    init();
    return tz.TZDateTime.from(dateTime, istLocation);
  }

  /// Converts a Firebase [Timestamp] to an IST [TZDateTime].
  static tz.TZDateTime fromFirebaseTimestamp(Timestamp timestamp) {
    return toIST(timestamp.toDate());
  }

  /// Formats a [DateTime] into the consistent professional app format:
  /// e.g. "26 Sep 2026, 7:23 PM"
  /// Automatically converts the provided time to IST before formatting.
  static String formatAppStandard(DateTime dateTime) {
    final istTime = toIST(dateTime);
    return DateFormat('dd MMM yyyy, h:mm a').format(istTime);
  }

  /// Formats a [DateTime] into a time-only format:
  /// e.g. "7:23 PM"
  static String formatTimeOnly(DateTime dateTime) {
    final istTime = toIST(dateTime);
    return DateFormat('h:mm a').format(istTime);
  }

  /// Safely formats a date of birth or date-only value where we DO NOT want
  /// timezone shifts to inadvertently change the calendar date.
  /// It treats the DateTime exactly as it is locally without TZ conversion.
  static String formatDateOnly(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// Parses an ISO string representing a date-only value.
  /// (e.g. "2006-05-13")
  static DateTime parseDateOnly(String dateStr) {
    // Keep it local so the calendar day doesn't shift when converting.
    return DateTime.parse(dateStr);
  }

  /// Gets the current real time in IST.
  static tz.TZDateTime nowIST() {
    init();
    return tz.TZDateTime.now(istLocation);
  }
}
