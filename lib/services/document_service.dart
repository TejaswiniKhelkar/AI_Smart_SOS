import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_document.dart';

/// Manages emergency documents in the secure Document Locker.
class DocumentService {
  static const String _storageKey = 'emergency_documents';

  /// Returns the app's document locker directory.
  static Future<Directory> _getLockerDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final lockerDir = Directory('${dir.path}/document_locker');
    if (!await lockerDir.exists()) {
      await lockerDir.create(recursive: true);
    }
    return lockerDir;
  }

  /// Retrieves all saved documents.
  static Future<List<EmergencyDocument>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return [];
    return EmergencyDocument.decode(encoded);
  }

  /// Stores a file from [sourcePath] into the document locker and saves metadata.
  static Future<EmergencyDocument> addDocument({
    required String sourcePath,
    required String name,
    required DocumentType type,
  }) async {
    final lockerDir = await _getLockerDir();
    final sourceFile = File(sourcePath);
    final fileSize = await sourceFile.length();
    final ext = sourcePath.split('.').last;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final destPath = '${lockerDir.path}/${id}_$name.$ext';

    await sourceFile.copy(destPath);

    final doc = EmergencyDocument(
      id: id,
      name: name,
      type: type,
      filePath: destPath,
      dateAdded: DateTime.now(),
      fileSizeBytes: fileSize,
    );

    final docs = await getDocuments();
    docs.add(doc);
    await _save(docs);
    return doc;
  }

  /// Updates a document's metadata (name, type, shareability).
  static Future<void> updateDocument(EmergencyDocument updated) async {
    final docs = await getDocuments();
    final index = docs.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      docs[index] = updated;
      await _save(docs);
    }
  }

  /// Deletes a document and its stored file.
  static Future<void> deleteDocument(String id) async {
    final docs = await getDocuments();
    final doc = docs.firstWhere((d) => d.id == id, orElse: () => throw 'Not found');
    // Delete file from disk
    final file = File(doc.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    docs.removeWhere((d) => d.id == id);
    await _save(docs);
  }

  /// Returns documents filtered by type.
  static Future<List<EmergencyDocument>> getDocumentsByType(
      DocumentType type) async {
    final docs = await getDocuments();
    return docs.where((d) => d.type == type).toList();
  }

  /// Returns only shareable documents (for emergency sharing).
  static Future<List<EmergencyDocument>> getShareableDocuments() async {
    final docs = await getDocuments();
    return docs.where((d) => d.isShareable).toList();
  }

  static Future<void> _save(List<EmergencyDocument> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, EmergencyDocument.encode(docs));
  }
}
