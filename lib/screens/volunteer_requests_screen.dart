import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ============================================================
// VOLUNTEER REQUESTS (ALL ENROLLMENTS)
// ============================================================

class VolunteerRequestsScreen extends StatefulWidget {
  const VolunteerRequestsScreen({super.key});

  @override
  State<VolunteerRequestsScreen> createState() =>
      _VolunteerRequestsScreenState();
}

class _VolunteerRequestsScreenState extends State<VolunteerRequestsScreen> {
  List<dynamic> requests = [];
  bool isLoading = true;
  int processingId = 0;
  String selectedFilter = 'All';

  String _requestStatus(dynamic request) =>
      (request['status']?.toString() ?? 'pending').toLowerCase();

  List<dynamic> get filteredRequests {
    if (selectedFilter == 'All') return requests;
    final targetStatus = switch (selectedFilter) {
      'Pending' => 'pending',
      'Accepted' => 'approved',
      _ => 'rejected',
    };
    return requests
        .where((request) => _requestStatus(request) == targetStatus)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getEnrollments();

      if (!mounted) return;

      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load requests: $e')));
    }
  }

  Future<void> updateStatus(int enrollmentId, String status) async {
    setState(() => processingId = enrollmentId);

    try {
      await ApiService.updateEnrollmentStatus(
        enrollmentId,
        status,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() => processingId = 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Volunteer approved' : 'Volunteer rejected',
          ),
        ),
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.accent;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'ACCEPTED';
      case 'rejected':
        return 'DECLINED';
      default:
        return 'PENDING';
    }
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volunteer_activism_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'VOLUNTEER MANAGEMENT',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Volunteer Recruiter Desk',
                        style: GoogleFonts.dmSerifDisplay(
                          color: AppColors.primaryDark,
                          fontSize: 31,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review applications and welcome the people joining your events.',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _RecruiterMetric(
                      label: 'Applicants',
                      count: requests.length,
                      color: AppColors.primary,
                      icon: Icons.groups_2_outlined,
                    ),
                    const SizedBox(width: 9),
                    _RecruiterMetric(
                      label: 'To review',
                      count: requests
                          .where(
                            (request) => _requestStatus(request) == 'pending',
                          )
                          .length,
                      color: AppColors.accent,
                      icon: Icons.hourglass_top_rounded,
                    ),
                    const SizedBox(width: 9),
                    _RecruiterMetric(
                      label: 'Accepted',
                      count: requests
                          .where(
                            (request) => _requestStatus(request) == 'approved',
                          )
                          .length,
                      color: AppColors.success,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Pending', 'Accepted', 'Declined'].map((
                    filter,
                  ) {
                    return ChoiceChip(
                      label: Text(filter),
                      selected: selectedFilter == filter,
                      onSelected: (_) =>
                          setState(() => selectedFilter = filter),
                      selectedColor: AppColors.lavender,
                      labelStyle: GoogleFonts.manrope(
                        color: selectedFilter == filter
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selectedFilter == filter
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (requests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'No applicants yet. New volunteer applications will appear here.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                else if (filteredRequests.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        'No ${selectedFilter.toLowerCase()} applicants.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredRequests.asMap().entries.map((entry) {
                    final req = entry.value;
                    final enrollmentId = (req['enrollment_id'] as num).toInt();
                    final status = _requestStatus(req);
                    final isProcessing = processingId == enrollmentId;

                    return TweenAnimationBuilder<double>(
                      key: ValueKey(enrollmentId),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 350 + entry.key * 70),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    child: const Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req['name'] ?? 'Student',
                                          style: GoogleFonts.manrope(
                                            color: AppColors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          req['email'] ?? '',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _statusChip(status),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '${req['task_name'] ?? 'Task'}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${req['event_name'] ?? ''} · '
                                'Student ID: ${req['student_id'] ?? ''}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (status == 'pending') ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: isProcessing
                                            ? null
                                            : () => updateStatus(
                                                enrollmentId,
                                                'approved',
                                              ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.green.shade50,
                                          foregroundColor:
                                              Colors.green.shade800,
                                        ),
                                        child: isProcessing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('ACCEPT VOLUNTEER'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: isProcessing
                                            ? null
                                            : () => updateStatus(
                                                enrollmentId,
                                                'rejected',
                                              ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red.shade50,
                                          foregroundColor: Colors.red.shade800,
                                        ),
                                        child: isProcessing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('DECLINE'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }
}

class _RecruiterMetric extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _RecruiterMetric({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 9),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// VOLUNTEERS OF A SINGLE TASK
// ============================================================

class TaskVolunteersScreen extends StatefulWidget {
  final int taskId;
  final String taskName;

  const TaskVolunteersScreen({
    super.key,
    required this.taskId,
    required this.taskName,
  });

  @override
  State<TaskVolunteersScreen> createState() => _TaskVolunteersScreenState();
}

class _TaskVolunteersScreenState extends State<TaskVolunteersScreen> {
  List<dynamic> volunteers = [];
  bool isLoading = true;
  int processingId = 0;

  @override
  void initState() {
    super.initState();
    loadVolunteers();
  }

  Future<void> loadVolunteers() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getTaskVolunteers(widget.taskId);

      if (!mounted) return;

      setState(() {
        volunteers = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load volunteers: $e')));
    }
  }

  Future<void> updateStatus(int enrollmentId, String status) async {
    setState(() => processingId = enrollmentId);

    try {
      await ApiService.updateEnrollmentStatus(
        enrollmentId,
        status,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() => processingId = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Volunteer approved' : 'Volunteer rejected',
          ),
        ),
      );

      loadVolunteers();
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
      appBar: AppBar(title: const Text('Volunteers')),
      body: RefreshIndicator(
        onRefresh: loadVolunteers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.taskName,
                style: GoogleFonts.dmSerifDisplay(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  height: 1.15,
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
              else if (volunteers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No volunteers yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...volunteers.map((v) {
                  final enrollmentId = (v['enrollment_id'] as num).toInt();
                  final status = v['status'] ?? 'pending';
                  final isProcessing = processingId == enrollmentId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  v['name'] ?? 'Student',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${v['email'] ?? ''} · ${v['student_id'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: isProcessing
                                        ? null
                                        : () => updateStatus(
                                            enrollmentId,
                                            'approved',
                                          ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green.shade50,
                                      foregroundColor: Colors.green.shade800,
                                    ),
                                    child: const Text('APPROVE'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: isProcessing
                                        ? null
                                        : () => updateStatus(
                                            enrollmentId,
                                            'rejected',
                                          ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red.shade800,
                                    ),
                                    child: const Text('REJECT'),
                                  ),
                                ),
                              ],
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
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
