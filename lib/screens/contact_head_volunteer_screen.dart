import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/session.dart';
import '../utils/formats.dart';

class ContactHeadVolunteerScreen extends StatefulWidget {
  const ContactHeadVolunteerScreen({super.key});

  @override
  State<ContactHeadVolunteerScreen> createState() =>
      _ContactHeadVolunteerScreenState();
}

class _ContactHeadVolunteerScreenState
    extends State<ContactHeadVolunteerScreen> {
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

  Future<void> send() async {
    final message = messageController.text.trim();

    if (selectedEventId == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an event and enter your message')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService.submitHelpRequest(
        userId: Session.userId,
        eventId: selectedEventId!,
        message: message,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your message was sent to the head volunteer. '
            'They will get back to you soon.',
          ),
        ),
      );

      Navigator.pop(context);
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
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Head Volunteer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.support_agent, size: 60, color: Colors.indigo),
            const SizedBox(height: 15),
            const Text(
              'Need help or have a question?',
              style: AppTextStyles.sectionHeading,
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a message to the head volunteer of the event. '
              'They will reach out to answer your query.',
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),

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
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Your message',
                prefixIcon: Icon(Icons.chat_bubble_outline),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : send,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('SEND MESSAGE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
