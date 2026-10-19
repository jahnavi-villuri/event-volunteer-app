import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formats.dart';
import '../widgets/event_artwork.dart';
import 'create_task_screen.dart';
import 'volunteer_requests_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  List<dynamic> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (events.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    'No events available.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ...events.map((event) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: SizedBox(
                      width: 76,
                      child: EventArtwork(
                        eventName: event['name'] ?? 'Event',
                        imageUrl: event['image_url']?.toString(),
                        height: 72,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    title: Text(
                      event['name'] ?? 'Event',
                      style: AppTextStyles.itemHeading,
                    ),
                    subtitle: Text(
                      '${formatDate(event['date'])}\n${event['location'] ?? ''}',
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
                            eventDate: event['date']?.toString(),
                            eventLocation: event['location']?.toString(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ManageEventTasksScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String? eventDate;
  final String? eventLocation;

  const ManageEventTasksScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    this.eventDate,
    this.eventLocation,
  });

  @override
  State<ManageEventTasksScreen> createState() => _ManageEventTasksScreenState();
}

class _ManageEventTasksScreenState extends State<ManageEventTasksScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getTasks(widget.eventId);

      if (!mounted) return;

      setState(() {
        tasks = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    }
  }

  Future<void> openCreateTask() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTaskScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
          eventDate: widget.eventDate,
          eventLocation: widget.eventLocation,
        ),
      ),
    );

    if (created == true) {
      loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Task',
            onPressed: openCreateTask,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadTasks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.eventName,
                style: AppTextStyles.pageHeading,
              ),
              const SizedBox(height: 18),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (tasks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No tasks for this event yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...tasks.asMap().entries.map((entry) {
                  final task = entry.value;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(task['id'] ?? entry.key),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + entry.key * 60),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['task_name'] ?? 'Task',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatDate(task['date'])}  ·  '
                            '${formatTime(task['start_time'])} - '
                            '${formatTime(task['end_time'])}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${task['location'] ?? ''}'
                            '${(task['volunteers_required'] as num?)?.toInt() != null ? '  ·  Needs ${(task['volunteers_required'] as num).toInt()} volunteers' : ''}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TaskVolunteersScreen(
                                              taskId: (task['id'] as num)
                                                  .toInt(),
                                              taskName:
                                                  task['task_name'] ?? 'Task',
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups),
                                  label: const Text('VOLUNTEERS'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
