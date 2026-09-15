import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../screens/ai_profile_screen.dart';
import '../screens/ai_settings_screen.dart';
import '../services/location_service.dart';
import '../services/nearby_places_service.dart';
import '../screens/emergency_contacts_screen.dart';
import '../screens/nearby_services_screen.dart';

class GlobalDrawer extends StatelessWidget {
  final Function(int) onTabSelected;

  const GlobalDrawer({super.key, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppTheme.cyanGradient,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Smart SOS',
                          style: AppTheme.headingSmall.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Emergency Command',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            
            _buildNavItem(
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                onTabSelected(0);
              },
            ),
            _buildNavItem(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                onTabSelected(1);
              },
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              title: 'User Profile',
              onTap: () {
                Navigator.pop(context);
                onTabSelected(2);
              },
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            _buildNavItem(
              icon: Icons.contacts_outlined,
              title: 'Emergency Contacts',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                );
              },
            ),
            _buildNavItem(
              icon: Icons.location_on_outlined,
              title: 'Live Location',
              onTap: () async {
                Navigator.pop(context);
                try {
                  final loc = await LocationService.getLocationData();
                  final places = await NearbyPlacesService.fetchNearbyPlaces(loc.latitude, loc.longitude);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NearbyServicesScreen(
                          places: places,
                          currentLat: loc.latitude,
                          currentLng: loc.longitude,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to load location')),
                    );
                  }
                }
              },
            ),
            const Divider(height: 1, color: AppTheme.glassBorder),
            _buildNavItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryCyan),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
      ),
      onTap: onTap,
    );
  }
}
