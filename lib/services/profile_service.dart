import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Manages user emergency profile via SharedPreferences + file storage for photos.
class ProfileService {
  static const String _storageKey = 'user_profile';

  /// Retrieves the saved user profile, or a default empty one.
  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return UserProfile();
    return UserProfile.decode(encoded);
  }

  /// Saves the user profile.
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, UserProfile.encode(profile));
  }

  /// Saves a profile photo from the given [sourcePath] and returns the
  /// stored file path.
  static Future<String> saveProfilePhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${dir.path}/profile');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    final ext = sourcePath.split('.').last;
    final destPath = '${profileDir.path}/profile_photo.$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Checks whether a profile photo exists on disk.
  static Future<bool> hasProfilePhoto() async {
    final profile = await getProfile();
    if (profile.profilePhotoPath == null) return false;
    return File(profile.profilePhotoPath!).existsSync();
  }

  /// Clears the profile (for testing/reset).
  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
