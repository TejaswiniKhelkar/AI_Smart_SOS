import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/emergency_document.dart';
import '../services/document_service.dart';
import '../widgets/reusable_widgets.dart';

class DocumentLockerScreen extends StatefulWidget {
  const DocumentLockerScreen({super.key});

  @override
  State<DocumentLockerScreen> createState() => _DocumentLockerScreenState();
}

class _DocumentLockerScreenState extends State<DocumentLockerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<EmergencyDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadDocuments();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    final docs = await DocumentService.getDocuments();
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  Future<void> _pickAndAddDocument() async {
    // Show type picker first
    final type = await showModalBottomSheet<DocumentType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildTypePicker(ctx),
    );
    if (type == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final name =
        file.name.split('.').first.replaceAll('_', ' ').replaceAll('-', ' ');

    await DocumentService.addDocument(
      sourcePath: file.path!,
      name: name,
      type: type,
    );
    _loadDocuments();
  }

  Future<void> _toggleShareable(EmergencyDocument doc) async {
    final updated = doc.copyWith(isShareable: !doc.isShareable);
    await DocumentService.updateDocument(updated);
    _loadDocuments();
  }

  Future<void> _deleteDocument(EmergencyDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Document', style: AppTheme.headingSmall),
        content: Text('Remove "${doc.name}" from your locker?',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.emergencyRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DocumentService.deleteDocument(doc.id);
      _loadDocuments();
    }
  }

  Widget _buildTypePicker(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.glassBorder),
          left: BorderSide(color: AppTheme.glassBorder),
          right: BorderSide(color: AppTheme.glassBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('SELECT DOCUMENT TYPE',
              style: AppTheme.headingSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 16),
          ...DocumentType.values.map((type) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Row(
                  children: [
                    Text(type.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Text(type.label,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textMuted, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ParticleBackground(
          seed: 111,
          child: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _documents.isEmpty
                              ? EmptyStateWidget(
                                  icon: Icons.folder_open_outlined,
                                  title: 'No Documents',
                                  subtitle:
                                      'Store your medical records, insurance,\nand identity documents securely',
                                  actionText: 'ADD DOCUMENT',
                                  onAction: _pickAndAddDocument,
                                )
                              : _buildDocumentList(),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButton: _documents.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow:
                    AppTheme.neonGlow(AppTheme.primaryCyan, intensity: 0.6),
              ),
              child: FloatingActionButton(
                onPressed: _pickAndAddDocument,
                backgroundColor: AppTheme.primaryCyan,
                child:
                    const Icon(Icons.add, color: AppTheme.background, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.glassWhite,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DOCUMENT LOCKER',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14)),
              Text('${_documents.length} document${_documents.length == 1 ? "" : "s"} stored',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    color: AppTheme.successGreen, size: 16),
                const SizedBox(width: 4),
                Text('Secure',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return _buildDocumentCard(doc);
      },
    );
  }

  Widget _buildDocumentCard(EmergencyDocument doc) {
    final typeColors = {
      DocumentType.medicalReport: AppTheme.emergencyRed,
      DocumentType.insurance: AppTheme.warningAmber,
      DocumentType.prescription: const Color(0xFF448AFF),
      DocumentType.bloodReport: AppTheme.emergencyRed,
      DocumentType.drivingLicense: AppTheme.successGreen,
      DocumentType.identity: AppTheme.primaryCyan,
      DocumentType.other: AppTheme.textMuted,
    };
    final color = typeColors[doc.type] ?? AppTheme.primaryCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: color.withValues(alpha: 0.15),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: Text(doc.type.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.name,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(doc.type.label,
                          style: AppTheme.bodySmall.copyWith(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 8),
                      Text('•',
                          style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(doc.fileSizeText,
                          style: AppTheme.bodySmall.copyWith(fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('•',
                          style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(
                          DateFormat('dd MMM yyyy').format(doc.dateAdded),
                          style: AppTheme.bodySmall.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            // Share toggle
            GestureDetector(
              onTap: () => _toggleShareable(doc),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: doc.isShareable
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.glassWhite,
                ),
                child: Icon(
                  doc.isShareable
                      ? Icons.share_rounded
                      : Icons.share_outlined,
                  color: doc.isShareable
                      ? AppTheme.successGreen
                      : AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Delete
            GestureDetector(
              onTap: () => _deleteDocument(doc),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.emergencyRed.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.delete_outline,
                    color: AppTheme.emergencyRed.withValues(alpha: 0.7),
                    size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
