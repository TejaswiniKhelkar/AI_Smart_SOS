import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/emergency_contact.dart';
import '../services/contact_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with TickerProviderStateMixin {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  late AnimationController _particleController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _loadContacts();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactService.getContacts();
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
    _fadeController.forward();
  }

  void _showAddEditSheet({EmergencyContact? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String selectedRelation = existing?.relationship ?? 'Family';

    final relationships = [
      'Family',
      'Friend',
      'Spouse',
      'Parent',
      'Sibling',
      'Colleague',
      'Neighbor',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder),
                  left: BorderSide(color: AppTheme.glassBorder),
                  right: BorderSide(color: AppTheme.glassBorder),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      existing != null ? 'EDIT CONTACT' : 'ADD CONTACT',
                      style: AppTheme.headingSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      existing != null
                          ? 'Update emergency contact details'
                          : 'Add a trusted emergency contact',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      style: AppTheme.bodyLarge
                          .copyWith(color: AppTheme.textPrimary),
                      decoration: AppTheme.inputDecoration(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextField(
                      controller: phoneCtrl,
                      style: AppTheme.bodyLarge
                          .copyWith(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.phone,
                      decoration: AppTheme.inputDecoration(
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Relationship dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRelation,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: AppTheme.primaryCyan),
                          style: AppTheme.bodyLarge
                              .copyWith(color: AppTheme.textPrimary),
                          items: relationships.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Row(
                                children: [
                                  Icon(
                                    _relationIcon(r),
                                    color: AppTheme.primaryCyan,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(r),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(() => selectedRelation = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.cyanGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: MaterialButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          
                          if (name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please fill in all fields',
                                  style: AppTheme.bodyMedium
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: AppTheme.emergencyRed,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            return;
                          }

                          if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a valid phone number (min 10 digits)',
                                  style: AppTheme.bodyMedium
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: AppTheme.emergencyRed,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            return;
                          }

                          if (existing != null) {
                            await ContactService.updateContact(
                              existing.copyWith(
                                name: name,
                                phone: phone,
                                relationship: selectedRelation,
                              ),
                            );
                          } else {
                            final contact = EmergencyContact(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              name: name,
                              phone: phone,
                              relationship: selectedRelation,
                            );
                            final success =
                                await ContactService.addContact(contact);
                            if (!success && ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Contact with this number already exists.',
                                    style: AppTheme.bodyMedium
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: AppTheme.emergencyRed,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadContacts();
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          existing != null ? 'UPDATE CONTACT' : 'SAVE CONTACT',
                          style: AppTheme.buttonText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Contact', style: AppTheme.headingSmall),
        content: Text(
          'Remove ${contact.name} from emergency contacts?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ContactService.deleteContact(contact.id);
              _loadContacts();
            },
            child: Text('Remove',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.emergencyRed)),
          ),
        ],
      ),
    );
  }

  IconData _relationIcon(String relationship) {
    switch (relationship) {
      case 'Family':
        return Icons.family_restroom;
      case 'Friend':
        return Icons.people_outline;
      case 'Spouse':
        return Icons.favorite_outline;
      case 'Parent':
        return Icons.escalator_warning;
      case 'Sibling':
        return Icons.group_outlined;
      case 'Colleague':
        return Icons.work_outline;
      case 'Neighbor':
        return Icons.home_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Particle background
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(_particleController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primaryCyan))
                          : _contacts.isEmpty
                              ? _buildEmptyState()
                              : _buildContactList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              border:
                  Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.contacts_outlined,
                color: AppTheme.primaryCyan, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMERGENCY CONTACTS',
                style: AppTheme.headingSmall.copyWith(fontSize: 14),
              ),
              Text(
                '${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}',
                style: AppTheme.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    color: AppTheme.primaryCyan.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 4),
                Text(
                  'Trusted',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withValues(alpha: 0.08),
              border:
                  Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.15)),
            ),
            child: Icon(Icons.person_add_outlined,
                color: AppTheme.primaryCyan.withValues(alpha: 0.5), size: 44),
          ),
          const SizedBox(height: 24),
          Text('No Emergency Contacts', style: AppTheme.headingSmall),
          const SizedBox(height: 8),
          Text(
            'Add trusted contacts who will receive\nyour SOS alerts with live location',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => _showAddEditSheet(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.cyanGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan,
                    intensity: 0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('ADD FIRST CONTACT', style: AppTheme.buttonText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return _buildContactCard(contact, index);
      },
    );
  }

  Widget _buildContactCard(EmergencyContact contact, int index) {
    final colors = [
      AppTheme.primaryCyan,
      AppTheme.successGreen,
      const Color(0xFF448AFF),
      AppTheme.warningAmber,
      const Color(0xFFE040FB),
    ];
    final accentColor = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        opacity: 0.06,
        borderColor: accentColor.withValues(alpha: 0.15),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.12),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.25), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : '?',
                        style: AppTheme.headingSmall.copyWith(
                          color: accentColor,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Text(contact.phone, style: AppTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
  
                  // Relationship badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_relationIcon(contact.relationship),
                            size: 14, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          contact.relationship,
                          style: AppTheme.bodySmall.copyWith(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('tel:${contact.phone}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    icon: const Icon(Icons.call, color: AppTheme.successGreen, size: 18),
                    label: Text('Call', style: AppTheme.bodyMedium.copyWith(color: AppTheme.successGreen)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppTheme.successGreen.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showAddEditSheet(existing: contact),
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyan, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDelete(contact),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.emergencyRed, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.emergencyRed.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppTheme.neonGlow(AppTheme.primaryCyan, intensity: 0.6),
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: AppTheme.primaryCyan,
        child: const Icon(Icons.person_add, color: AppTheme.background),
      ),
    );
  }
}

// ── Particle Painter ──────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(77);
    final paint = Paint();

    for (int i = 0; i < 45; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.15 + random.nextDouble() * 0.5;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.4 + random.nextDouble() * 1.0;
      final opacity = 0.06 + random.nextDouble() * 0.2;

      paint.color = (i % 7 == 0 ? AppTheme.primaryCyan : Colors.white)
          .withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
