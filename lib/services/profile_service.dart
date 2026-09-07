import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

/// Manages user emergency profile securely in Firebase Firestore.
/// Ensures profile data isolation per authenticated user.
class ProfileService {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static DocumentReference? get _userDoc => _uid != null 
      ? FirebaseFirestore.instance.collection('users').doc(_uid)
      : null;

  /// Retrieves the saved user profile from Firestore, or a default empty one.
  static Future<UserProfile> getProfile() async {
    if (_userDoc == null) return UserProfile();
    
    final doc = await _userDoc!.get();
    if (!doc.exists) return UserProfile();

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return UserProfile();
    
    // We expect the profile to be inside an 'emergencyProfile' map
    // but we can also use top-level fields for name, email, phone as defaults
    final emergencyProfile = data['emergencyProfile'] as Map<String, dynamic>? ?? {};
    
    // Merge top-level auth data if missing in profile
    if (emergencyProfile['fullName'] == null || emergencyProfile['fullName'].toString().isEmpty) {
      emergencyProfile['fullName'] = data['name'] ?? '';
    }
    if (emergencyProfile['email'] == null || emergencyProfile['email'].toString().isEmpty) {
      emergencyProfile['email'] = data['email'] ?? '';
    }
    if (emergencyProfile['phone'] == null || emergencyProfile['phone'].toString().isEmpty) {
      emergencyProfile['phone'] = data['phone'] ?? '';
    }

    return UserProfile.fromJson(emergencyProfile);
  }

  /// Saves the user profile to Firestore.
  static Future<void> saveProfile(UserProfile profile) async {
    if (_userDoc == null) return;
    await _userDoc!.set({'emergencyProfile': profile.toJson()}, SetOptions(merge: true));
  }

  /// Saves a profile photo from the given [sourcePath] locally and returns the stored file path.
  /// (Note: Full cloud sync of images requires Firebase Storage, which is not set up yet).
  static Future<String> saveProfilePhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${dir.path}/profile');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    final ext = sourcePath.split('.').last;
    final destPath = '${profileDir.path}/profile_photo_${_uid ?? 'guest'}.$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Checks whether a profile photo exists on disk.
  static Future<bool> hasProfilePhoto() async {
    final profile = await getProfile();
    if (profile.profilePhotoPath == null) return false;
    return File(profile.profilePhotoPath!).existsSync();
  }

  /// Clears the local profile data (if any was cached).
  static Future<void> clearProfile() async {
    // We no longer use SharedPreferences for the profile. 
    // Data is tied to the current Firebase Auth session.
  }
}
