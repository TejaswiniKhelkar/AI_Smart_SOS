import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/nearby_place.dart';

class NearbyServicesScreen extends StatelessWidget {
  final List<NearbyPlace> places;
  final double currentLat;
  final double currentLng;

  const NearbyServicesScreen({
    super.key,
    required this.places,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Nearby Emergency Services',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: places.isEmpty
          ? Center(
              child: Text(
                'No nearby services found.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: places.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final place = places[index];
                final isHospital = place.type == PlaceType.hospital;
                final isPolice = place.type == PlaceType.police;

                final icon = isHospital
                    ? Icons.local_hospital
                    : (isPolice
                        ? Icons.local_police
                        : Icons.local_fire_department);

                final color = isHospital
                    ? AppTheme.emergencyRed
                    : (isPolice
                        ? AppTheme.primaryCyan
                        : AppTheme.warningAmber);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration(borderRadius: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${place.distanceText} ΓÇó ${place.address ?? "Unknown Address"}',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (place.isOpen != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (place.isOpen!
                                              ? AppTheme.successGreen
                                              : AppTheme.emergencyRed)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      place.isOpen! ? 'Open' : 'Closed',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: place.isOpen!
                                            ? AppTheme.successGreen
                                            : AppTheme.emergencyRed,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    final url = Uri.parse(
                                      'https://www.google.com/maps/dir/?api=1'
                                      '&origin=$currentLat,$currentLng'
                                      '&destination=${place.latitude},${place.longitude}'
                                      '&travelmode=driving',
                                    );
                                    launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryCyan
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.navigation,
                                            size: 14,
                                            color: AppTheme.primaryCyan),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Navigate',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.primaryCyan,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
