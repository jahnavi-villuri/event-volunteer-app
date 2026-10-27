import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../utils/formats.dart';
import '../theme/app_theme.dart';
import '../widgets/load_error_state.dart';
import 'create_announcement_screen.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<dynamic> announcements = [];
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadAnnouncements();
  }

  Future<void> loadAnnouncements() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final data = await ApiService.getAnnouncements();

      if (!mounted) return;

      setState(() {
        announcements = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Could not load announcements. $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load announcements: $e')),
      );
    }
  }

  Future<void> openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateAnnouncementScreen()),
    );

    if (created == true) {
      loadAnnouncements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHead = Session.isHeadVolunteer;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadAnnouncements,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Announcements', style: AppTextStyles.pageHeading),
                        SizedBox(height: 8),
                        Text(
                          'Latest updates from your events.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHead)
                    IconButton.filled(
                      onPressed: openCreate,
                      icon: const Icon(Icons.add),
                      tooltip: 'New Announcement',
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        'Stay in the loop',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFFFD58A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (loadError != null)
                LoadErrorState(message: loadError!, onRetry: loadAnnouncements)
              else if (announcements.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No announcements yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...announcements.map((a) {
                  return Card(
                    color: AppColors.pastelFor(a['id']),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.lavender,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.campaign,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  a['title'] ?? 'Announcement',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            a['message'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lavender,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    a['event_name'] ?? 'Community update',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatDateTime(a['created_at']),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
