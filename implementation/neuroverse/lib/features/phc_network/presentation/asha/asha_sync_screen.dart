import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../data/phc_repository.dart';

class AshaSyncScreen extends StatefulWidget {
  const AshaSyncScreen({super.key});

  @override
  State<AshaSyncScreen> createState() => _AshaSyncScreenState();
}

class _AshaSyncScreenState extends State<AshaSyncScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final repo = PhcRepository();
    final asha = repo.currentAsha;
    final doctor = repo.doctor;
    final pendingCount = repo.pendingSyncCount;
    final totalVisited = asha.visitedCount;
    final totalSkipped = asha.skippedCount;
    final target = asha.targetElders;
    final progress = ((totalVisited + totalSkipped) / target).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr('asha_sync_cloud')),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimaryLight,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sync Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: pendingCount > 0
                      ? [const Color(0xFF00796B), const Color(0xFF004D40)]
                      : [Colors.teal.shade700, Colors.teal.shade900],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pendingCount > 0
                                  ? context.tr('offline_sync_pending', params: {'count': pendingCount.toString()})
                                  : context.tr('offline_sync_done'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              context.tr('sync_linked_facility_fmt', params: {
                                'code': doctor.facilityCode,
                                'hospital': doctor.hospitalName,
                              }),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    asha.lastSyncTime != null
                        ? context.tr('sync_last_sync_fmt', params: {
                            'time': '${asha.lastSyncTime!.hour}:${asha.lastSyncTime!.minute.toString().padLeft(2, '0')}'
                          })
                        : context.tr('sync_never'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSyncing
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final successMsg = context.tr('offline_sync_done');
                            setState(() => _isSyncing = true);
                            await repo.syncAllOfflineWithCloud();
                            if (mounted) {
                              setState(() => _isSyncing = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text('$successMsg ✓'),
                                ),
                              );
                            }
                          },
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_isSyncing ? context.tr('sync_syncing') : context.tr('asha_sync_cloud')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly Target Progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('sync_cluster_target'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        context.tr('sync_done_pct_fmt', params: {'pct': (progress * 100).toInt().toString()}),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(context.tr('sync_stat_visited'), '$totalVisited', Colors.green),
                      _buildMiniStat(context.tr('sync_stat_skipped'), '$totalSkipped', Colors.orange),
                      _buildMiniStat(context.tr('sync_stat_total_target'), '$target', Colors.blueGrey),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export Reports Section
            Text(
              context.tr('sync_reports_heading'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: context.tr('sync_pdf_title'),
              subtitle: context.tr('sync_pdf_sub'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('sync_pdf_snack'))),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.tr('sync_whatsapp_title'),
              subtitle: context.tr('sync_doctor_contact_sub', params: {
                'name': doctor.name,
                'phone': doctor.phone,
              }),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('sync_whatsapp_snack_fmt', params: {'doctor': doctor.name}))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
