import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formats.dart';
import '../widgets/load_error_state.dart';

class HelpRequestsScreen extends StatefulWidget {
  const HelpRequestsScreen({super.key});

  @override
  State<HelpRequestsScreen> createState() => _HelpRequestsScreenState();
}

class _HelpRequestsScreenState extends State<HelpRequestsScreen> {
  List<dynamic> requests = [];
  bool isLoading = true;
  int processingId = 0;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final data = await ApiService.getHelpRequests();

      if (!mounted) return;

      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Could not load help requests. $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load requests: $e')));
    }
  }

  Future<void> resolve(int requestId) async {
    setState(() {
      processingId = requestId;
    });

    try {
      await ApiService.updateHelpRequestStatus(
        requestId,
        'resolved',
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        processingId = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Help request marked as resolved')),
      );

      loadRequests();
    } catch (e) {
      if (!mounted) return;

      setState(() => processingId = 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Help Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9EEFF), Color(0xFFF5F3FF), Color(0xFFF8F7FC)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: loadRequests,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Help Requests', style: AppTextStyles.pageHeading),
                  const SizedBox(height: 8),
                  const Text(
                    'Questions and help requests from volunteers.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  if (isLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],

                  if (loadError != null) ...[
                    LoadErrorState(message: loadError!, onRetry: loadRequests),
                  ],

                  if (!isLoading && loadError == null && requests.isEmpty) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'No help requests yet.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],

                  ...requests.map((req) {
                    final requestId = (req['id'] as num).toInt();
                    final status = req['status'] ?? 'open';
                    final isProcessing = processingId == requestId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Icon(
                                    Icons.support_agent,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        req['name'] ?? 'Student',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${req['event_name'] ?? ''} · '
                                        '${formatDateTime(req['created_at'])}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (status == 'resolved'
                                            ? Colors.green
                                            : Colors.orange)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: status == 'resolved'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              req['message'] ?? '',
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                            if (status == 'open') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: isProcessing
                                      ? null
                                      : () => resolve(requestId),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade50,
                                    foregroundColor: Colors.indigo,
                                  ),
                                  child: const Text('MARK AS RESOLVED'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
