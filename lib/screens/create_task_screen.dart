import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formats.dart';

class CreateTaskScreen extends StatefulWidget {
  final int? eventId;
  final String? eventName;
  final String? eventDate;
  final String? eventLocation;
  final Map<String, dynamic>? task;

  const CreateTaskScreen({
    super.key,
    this.eventId,
    this.eventName,
    this.eventDate,
    this.eventLocation,
    this.task,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final taskNameController = TextEditingController();
  final dateController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();
  final locationController = TextEditingController();
  final instructionsController = TextEditingController();
  final descriptionController = TextEditingController();
  final volunteersController = TextEditingController();
  final compensationAmountController = TextEditingController();
  final compensationCurrencyController = TextEditingController(text: 'INR');
  final compensationTermsController = TextEditingController();
  final requirementsController = TextEditingController();

  List<dynamic> events = [];
  bool loadingEvents = false;
  int? selectedEventId;
  bool isLoading = false;
  String taskStatus = 'Open';
  String compensationType = 'unpaid';

  static const _taskStatuses = [
    'Open',
    'Assigned',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  static const _sportsMeetActivities = [
    _ActivityPreset(
      'Registration and check-in',
      '07:00:00',
      '08:00:00',
      'Welcome participants and help them find the registration desk.',
      4,
    ),
    _ActivityPreset(
      'Scorekeeping',
      '08:00:00',
      '13:00:00',
      'Record match results and share completed score sheets with the event desk.',
      3,
    ),
    _ActivityPreset(
      'Hydration station',
      '08:00:00',
      '12:00:00',
      'Keep the water station tidy and help participants access drinking water.',
      4,
    ),
    _ActivityPreset(
      'Equipment setup',
      '06:30:00',
      '08:00:00',
      'Arrange sports equipment at the marked activity areas.',
      5,
    ),
    _ActivityPreset(
      'Crowd guidance',
      '08:00:00',
      '13:00:00',
      'Guide attendees between the ground, seating, and activity areas.',
      6,
    ),
    _ActivityPreset(
      'First aid support',
      '08:00:00',
      '13:00:00',
      'Assist the designated first-aid team and direct anyone needing help.',
      3,
    ),
  ];

  static const _culturalFestActivities = [
    _ActivityPreset(
      'Stage setup and decor',
      '07:30:00',
      '09:00:00',
      'Help arrange stage decor and prepare the performance area.',
      5,
    ),
    _ActivityPreset(
      'Guest ushering',
      '09:00:00',
      '13:00:00',
      'Welcome guests and guide them to the auditorium and seating areas.',
      6,
    ),
    _ActivityPreset(
      'Backstage support',
      '09:00:00',
      '14:00:00',
      'Help performers find the backstage waiting and entry areas.',
      4,
    ),
    _ActivityPreset(
      'Sound and lighting assistance',
      '08:00:00',
      '14:00:00',
      'Support the sound and lighting team with event-day coordination.',
      3,
    ),
    _ActivityPreset(
      'Stall coordination',
      '09:00:00',
      '14:00:00',
      'Help stall teams with setup and direct visitors around the fest.',
      5,
    ),
    _ActivityPreset(
      'Venue cleanup',
      '14:00:00',
      '16:00:00',
      'Collect event waste and help leave the auditorium and shared areas tidy.',
      5,
    ),
  ];

  List<_ActivityPreset> get suggestedActivities {
    final selectedEvent = events.where(
      (event) => (event['id'] as num?)?.toInt() == selectedEventId,
    );
    final name =
        widget.eventName ??
        (selectedEvent.isEmpty
            ? ''
            : selectedEvent.first['name']?.toString()) ??
        '';
    final normalizedName = name.toLowerCase();

    if (normalizedName.contains('sports') && normalizedName.contains('meet')) {
      return _sportsMeetActivities;
    }
    if (normalizedName.contains('cultural') &&
        normalizedName.contains('fest')) {
      return _culturalFestActivities;
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    selectedEventId = widget.eventId;
    dateController.text = _dateOnly(widget.eventDate);
    locationController.text = widget.eventLocation ?? '';
    final task = widget.task;
    if (task != null) {
      taskNameController.text = task['task_name']?.toString() ?? '';
      dateController.text = _dateOnly(task['date']?.toString());
      startTimeController.text = _dateOnlyTime(task['start_time']?.toString());
      endTimeController.text = _dateOnlyTime(task['end_time']?.toString());
      locationController.text = task['location']?.toString() ?? '';
      instructionsController.text = task['instructions']?.toString() ?? '';
      descriptionController.text = task['description']?.toString() ?? '';
      volunteersController.text = task['volunteers_required']?.toString() ?? '';
      compensationType =
          task['compensation_type']?.toString().toLowerCase() ?? 'unpaid';
      compensationAmountController.text =
          task['compensation_amount']?.toString() ?? '';
      compensationCurrencyController.text =
          task['compensation_currency']?.toString() ?? 'INR';
      compensationTermsController.text =
          task['compensation_terms']?.toString() ?? '';
      requirementsController.text =
          task['additional_requirements']?.toString() ?? '';
      taskStatus = _taskStatuses.contains(task['status'])
          ? task['status'].toString()
          : 'Open';
    }
    if (selectedEventId == null) {
      loadEvents();
    }
  }

  String _dateOnly(String? date) => date?.split('T').first ?? '';
  String _dateOnlyTime(String? time) {
    final value = time ?? '';
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  void _selectEvent(int? eventId) {
    final matchingEvents = events.where(
      (event) => (event['id'] as num?)?.toInt() == eventId,
    );
    if (matchingEvents.isEmpty) {
      setState(() => selectedEventId = eventId);
      return;
    }

    final event = matchingEvents.first;
    setState(() {
      selectedEventId = eventId;
      if (dateController.text.isEmpty) {
        dateController.text = _dateOnly(event['date']?.toString());
      }
      if (locationController.text.isEmpty) {
        locationController.text = event['location']?.toString() ?? '';
      }
    });
  }

  void _chooseActivity(_ActivityPreset activity) {
    setState(() {
      taskNameController.text = activity.name;
      startTimeController.text = activity.startTime;
      endTimeController.text = activity.endTime;
      instructionsController.text = activity.instructions;
      volunteersController.text = activity.volunteers.toString();
      if (dateController.text.isEmpty) {
        dateController.text = _dateOnly(widget.eventDate);
      }
      if (locationController.text.isEmpty) {
        locationController.text = widget.eventLocation ?? '';
      }
    });
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

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      dateController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}:00';
    }
  }

  Future<void> createTask() async {
    final taskName = taskNameController.text.trim();
    final date = dateController.text.trim();
    final startTime = startTimeController.text.trim();
    final endTime = endTimeController.text.trim();
    final location = locationController.text.trim();
    final volunteersRequired = int.tryParse(volunteersController.text.trim());
    final compensationAmount = compensationType == 'unpaid'
        ? null
        : double.tryParse(compensationAmountController.text.trim());

    if (selectedEventId == null ||
        taskName.isEmpty ||
        descriptionController.text.trim().isEmpty ||
        date.isEmpty ||
        startTime.isEmpty ||
        endTime.isEmpty ||
        location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Event, task name, description, date, times and location are required',
          ),
        ),
      );
      return;
    }
    if (volunteersRequired == null || volunteersRequired <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer capacity must be a positive whole number'),
        ),
      );
      return;
    }
    final startDateTime = DateTime.tryParse('${date}T$startTime');
    final endDateTime = DateTime.tryParse('${date}T$endTime');

    if (startDateTime == null ||
        endDateTime == null ||
        !endDateTime.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be later than start time')),
      );
      return;
    }
    if (compensationType != 'unpaid' &&
        (compensationAmount == null ||
            !compensationAmount.isFinite ||
            compensationAmount < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid non-negative compensation amount'),
        ),
      );
      return;
    }
    final currency = compensationCurrencyController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Currency must be a 3-letter code')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (widget.task case final task?) {
        final taskId = (task['id'] as num).toInt();
        await ApiService.updateTask(
          taskId: taskId,
          details: {
            'task_name': taskName,
            'description': descriptionController.text.trim(),
            'date': date,
            'start_time': '$startTime:00',
            'end_time': '$endTime:00',
            'location': location,
            'instructions': instructionsController.text.trim(),
            'volunteers_required': volunteersRequired,
            'status': taskStatus,
            'compensation_type': compensationType,
            'compensation_amount': compensationAmount,
            'compensation_currency': currency,
            'compensation_terms': compensationTermsController.text.trim(),
            'additional_requirements': requirementsController.text.trim(),
          },
        ).timeout(const Duration(seconds: 10));
      } else {
        await ApiService.createTask(
          eventId: selectedEventId!,
          taskName: taskName,
          date: date,
          startTime: '$startTime:00',
          endTime: '$endTime:00',
          location: location,
          instructions: instructionsController.text.trim(),
          description: descriptionController.text.trim(),
          volunteersRequired: volunteersRequired,
          status: taskStatus,
          compensationType: compensationType,
          compensationAmount: compensationAmount,
          compensationCurrency: currency,
          compensationTerms: compensationTermsController.text,
          additionalRequirements: requirementsController.text,
        ).timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.task == null ? 'Task created successfully' : 'Task updated',
          ),
        ),
      );

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
    taskNameController.dispose();
    dateController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    locationController.dispose();
    instructionsController.dispose();
    descriptionController.dispose();
    volunteersController.dispose();
    compensationAmountController.dispose();
    compensationCurrencyController.dispose();
    compensationTermsController.dispose();
    requirementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Create Task' : 'Edit Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedEventId == null) ...[
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
                        _selectEvent(value);
                      },
                    ),
              const SizedBox(height: 16),
            ],
            if (suggestedActivities.isNotEmpty) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey(suggestedActivities.first.name),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested activities',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap a suggestion to use it as the task name.',
                        style: TextStyle(
                          color: Color(0xFF71778B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: suggestedActivities.map((activity) {
                          return ChoiceChip(
                            label: Text(activity.name),
                            selected: taskNameController.text == activity.name,
                            onSelected: (_) => _chooseActivity(activity),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            TextField(
              controller: taskNameController,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                prefixIcon: Icon(Icons.task_alt),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Task description and responsibilities',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: taskStatus,
              decoration: const InputDecoration(
                labelText: 'Task status',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
              items: _taskStatuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => taskStatus = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              readOnly: true,
              onTap: pickDate,
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today),
                suffixIcon: Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startTimeController,
                    readOnly: true,
                    onTap: () => pickTime(startTimeController),
                    decoration: const InputDecoration(
                      labelText: 'Start Time',
                      prefixIcon: Icon(Icons.access_time),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endTimeController,
                    readOnly: true,
                    onTap: () => pickTime(endTimeController),
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      prefixIcon: Icon(Icons.access_time),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: instructionsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                prefixIcon: Icon(Icons.menu_book),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: volunteersController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Volunteer capacity',
                prefixIcon: Icon(Icons.groups),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: compensationType,
              decoration: const InputDecoration(
                labelText: 'Compensation',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'unpaid',
                  child: Text('Volunteer — unpaid'),
                ),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed stipend')),
                DropdownMenuItem(value: 'hourly', child: Text('Hourly rate')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  compensationType = value;
                  if (value == 'unpaid') compensationAmountController.clear();
                });
              },
            ),
            if (compensationType != 'unpaid') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: compensationAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: compensationType == 'fixed'
                            ? 'Stipend amount'
                            : 'Hourly amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: compensationCurrencyController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compensationTermsController,
                maxLength: 2000,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Compensation terms (optional)',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: requirementsController,
              maxLength: 2000,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Additional requirements (optional)',
                prefixIcon: Icon(Icons.checklist_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : createTask,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.task == null ? 'CREATE TASK' : 'SAVE TASK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPreset {
  final String name;
  final String startTime;
  final String endTime;
  final String instructions;
  final int volunteers;

  const _ActivityPreset(
    this.name,
    this.startTime,
    this.endTime,
    this.instructions,
    this.volunteers,
  );
}
