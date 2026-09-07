import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a new account.
  static Future<String?> signUp(String name, String email, String phone, String password) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'emergencyContacts': [],
          'emergencyProfile': {},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getMessageFromErrorCode(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Login to existing account.
  static Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getMessageFromErrorCode(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Logout current session.
  static Future<void> logout() async {
    await _auth.signOut();
    
    // Clear any previously cached local data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emergency_contacts');
    await prefs.remove('user_profile');
  }

  /// Sends a password reset email to the specified address.
  static Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getMessageFromErrorCode(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if a user is currently logged in.
  static Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  /// Check if the current user's email is verified.
  static Future<bool> isEmailVerified() async {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Reload the user to get the latest email verified status.
  static Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Send email verification to the currently logged in user.
  static Future<String?> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _getMessageFromErrorCode(e.code);
    } catch (e) {
      return 'Failed to send verification email.';
    }
  }

  /// Get the current user UID
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Map Firebase Auth error codes to user-friendly messages
  static String _getMessageFromErrorCode(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
