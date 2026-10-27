import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formats.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  List<dynamic> events = [];
  bool loadingEvents = false;
  int? selectedEventId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() => loadingEvents = true);
    try {
      final data = await ApiService.getEvents();
      if (!mounted) return;
      setState(() {
        events = data;
        loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingEvents = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    }
  }

  Future<void> publish() async {
    final title = titleController.text.trim();
    final message = messageController.text.trim();

    if (selectedEventId == null || title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event, title and message are required')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService.createAnnouncement(
        eventId: selectedEventId!,
        title: title,
        message: message,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement published')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Announcement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            loadingEvents
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : DropdownButtonFormField<int>(
                    initialValue: selectedEventId,
                    decoration: const InputDecoration(
                      labelText: 'Event',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    items: events
                        .map(
                          (event) => DropdownMenuItem<int>(
                            value: (event['id'] as num).toInt(),
                            child: Text(
                              '${event['name'] ?? 'Event'} - '
                              '${formatDate(event['date'])}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedEventId = value);
                    },
                  ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                prefixIcon: Icon(Icons.campaign),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : publish,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('PUBLISH'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
