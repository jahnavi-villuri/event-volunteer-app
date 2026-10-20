import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formats.dart';
import '../widgets/event_artwork.dart';
import '../widgets/load_error_state.dart';
import 'create_event_screen.dart';
import 'create_announcement_screen.dart';
import 'manage_events_screen.dart';
import 'volunteer_requests_screen.dart';
import 'help_requests_screen.dart';

class HeadDashboardPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const HeadDashboardPage({super.key, required this.user});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'Head Volunteer';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $name 👋', style: AppTextStyles.pageHeading),
            const SizedBox(height: 6),
            const Text(
              'Manage your events, tasks and volunteers.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.add_circle_outline,
                    title: 'Create Event',
                    subtitle: 'Add a new event',
                    onTap: () => _push(context, const CreateEventScreen()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.event_note,
                    title: 'Manage Events',
                    subtitle: 'Events and tasks',
                    onTap: () => _push(context, const ManageEventsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.groups,
                    title: 'Recruiter Desk',
                    subtitle: 'Review applicants',
                    onTap: () =>
                        _push(context, const VolunteerRequestsScreen()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.campaign,
                    title: 'New Announcement',
                    subtitle: 'Send updates',
                    onTap: () =>
                        _push(context, const CreateAnnouncementScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.support_agent,
                    title: 'Help Requests',
                    subtitle: 'Student messages',
                    onTap: () => _push(context, const HelpRequestsScreen()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _DashboardCard(
                    icon: Icons.event,
                    title: 'View Events',
                    subtitle: 'Browse all events',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HeadEventsListPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.indigo, size: 30),
              const SizedBox(height: 12),
              Text(title, style: AppTextStyles.itemHeading),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeadEventsListPage extends StatefulWidget {
  const HeadEventsListPage({super.key});

  @override
  State<HeadEventsListPage> createState() => _HeadEventsListPageState();
}

class _HeadEventsListPageState extends State<HeadEventsListPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final data = await ApiService.getEvents();
      if (!mounted) return;
      setState(() {
        events = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'Could not load events. $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Events')),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              : loadError != null
              ? LoadErrorState(message: loadError!, onRetry: loadEvents)
              : events.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No events available.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: events.map((event) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: SizedBox(
                          width: 78,
                          child: EventArtwork(
                            eventName: event['name'] ?? 'Event',
                            imageUrl: event['image_url']?.toString(),
                            height: 74,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        title: Text(
                          event['name'] ?? 'Event',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${formatDate(event['date'])}'
                          '\n${event['location'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageEventTasksScreen(
                                eventId: (event['id'] as num).toInt(),
                                eventName: event['name'] ?? 'Event',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}
