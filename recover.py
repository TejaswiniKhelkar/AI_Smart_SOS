import sys
with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
for line in lines:
    if 'Widget _buildTestEmergencyButton()' in line:
        break
    out.append(line)

new_widgets = '''  Widget _buildTestEmergencyButton() {
    return GestureDetector(
      onTap: () {
        AccidentAlertDialog.show(
          context,
          onSendSOS: _triggerSOS,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.emergencyRed,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emergencyRed.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Test Emergency',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.public, color: AppTheme.primaryCyan, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI SMART SOS',
                style: AppTheme.headingMedium.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(
                'Emergency Response',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.successGreen, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Protected',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w700,
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

  Widget _buildSOSButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: AppTheme.glassDecoration(borderRadius: 32),
        child: Column(
          children: [
            Text(
              'PRESS FOR EMERGENCY',
              style: AppTheme.bodyMedium.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _triggerSOS,
              child: AnimatedBuilder(
                animation: _sosPulse,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _sosPulse.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.redGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.1),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sos_rounded, color: Colors.white, size: 64),
                            const SizedBox(height: 8),
                            Text(
                              'SOS',
                              style: AppTheme.headingLarge.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Hold to send emergency alert',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: AppTheme.successGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Location shared with trusted contacts',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: AppTheme.glassDecoration(borderRadius: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.my_location, color: AppTheme.primaryCyan, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Location',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _gpsCoords,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gpsCoords.contains('°') ? AppTheme.successGreen : AppTheme.warningAmber,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActionCard(
                icon: Icons.local_police,
                label: 'Police',
                number: '100',
                color: AppTheme.primaryCyan,
                onTap: () => _triggerQuickAction('Police'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_hospital,
                label: 'Ambulance',
                number: '108',
                color: AppTheme.emergencyRed,
                onTap: () => _triggerQuickAction('Ambulance'),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.local_fire_department,
                label: 'Fire',
                number: '101',
                color: AppTheme.warningAmber,
                onTap: () => _triggerQuickAction('Fire'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String number,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: AppTheme.glassDecoration(borderRadius: 20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                number,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          setState(() {
            final state = context.findAncestorStateOfType<_HomeScreenState>();
            if (state != null) {
              state.setState(() => state._currentTab = 1);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.cyanGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Emergency Assistant',
                      style: AppTheme.headingSmall.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get safe guidance instantly.',
                      style: AppTheme.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contacts',
                style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                  ).then((_) => _fetchContacts());
                },
                child: Text(
                  'Manage',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingContacts)
            const Center(child: CircularProgressIndicator())
          else if (_contacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassDecoration(borderRadius: 16),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No contacts added yet',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ..._contacts.take(3).map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: AppTheme.glassDecoration(borderRadius: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          contact.name.substring(0, 1).toUpperCase(),
                          style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryCyan),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact.relationship,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call, color: AppTheme.successGreen),
                        onPressed: () {
                          // Call logic
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
'''
out.append(new_widgets)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(out)
