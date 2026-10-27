import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? event;

  const CreateEventScreen({super.key, this.event});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _date = TextEditingController();
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();
  final _location = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _volunteers = TextEditingController();
  final _roles = TextEditingController();
  final _meetingPoint = TextEditingController();
  final _reporting = TextEditingController();
  final _contactPhone = TextEditingController();
  final _imageUrl = TextEditingController();
  final _registrationDeadline = TextEditingController();
  final _instructions = TextEditingController();
  bool _isSaving = false;

  String get _title => widget.event == null ? 'Add Event' : 'Edit Event';

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) return;
    _name.text = event['name']?.toString() ?? '';
    _date.text = _dateOnly(event['date']);
    _startTime.text = _timeOnly(event['start_time']);
    _endTime.text = _timeOnly(event['end_time']);
    _location.text = event['location']?.toString() ?? '';
    _area.text = event['area']?.toString() ?? '';
    _address.text = event['address']?.toString() ?? '';
    _category.text = event['category']?.toString() ?? '';
    _description.text = event['description']?.toString() ?? '';
    _volunteers.text = event['volunteers_needed']?.toString() ?? '';
    _roles.text = event['required_roles']?.toString() ?? '';
    _meetingPoint.text = event['meeting_point']?.toString() ?? '';
    _reporting.text = event['reporting_instructions']?.toString() ?? '';
    _contactPhone.text = event['contact_phone']?.toString() ?? '';
    _imageUrl.text = event['image_url']?.toString() ?? '';
    _registrationDeadline.text = _dateOnly(event['registration_deadline']);
    _instructions.text = event['instructions']?.toString() ?? '';
  }

  String _dateOnly(dynamic value) => value?.toString().split(' ').first ?? '';

  String _timeOnly(dynamic value) {
    final time = value?.toString() ?? '';
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  String _formattedDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(TextEditingController controller) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final existing = DateTime.tryParse(controller.text);
    final initial = existing != null && !existing.isBefore(today)
        ? existing
        : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
    );
    if (selected != null) controller.text = _formattedDate(selected);
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = parts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected != null) {
      controller.text =
          '${selected.hour.toString().padLeft(2, '0')}:'
          '${selected.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    final volunteers = int.tryParse(_volunteers.text.trim());
    if (_volunteers.text.trim().isNotEmpty &&
        (volunteers == null || volunteers <= 0)) {
      _showMessage('Volunteers needed must be a positive whole number');
      return;
    }

    setState(() => _isSaving = true);
    final status = publish ? 'published' : 'draft';
    try {
      final eventId = widget.event?['id'];
      if (eventId is num) {
        await ApiService.updateEvent(
          eventId: eventId.toInt(),
          details: _details(status, volunteers),
        );
      } else {
        await ApiService.createEvent(
          name: _name.text,
          date: _date.text,
          location: _location.text,
          description: _description.text,
          volunteersNeeded: volunteers,
          status: status,
          category: _category.text,
          startTime: _startTime.text,
          endTime: _endTime.text,
          area: _area.text,
          address: _address.text,
          requiredRoles: _roles.text,
          meetingPoint: _meetingPoint.text,
          reportingInstructions: _reporting.text,
          instructions: _instructions.text,
          contactPhone: _contactPhone.text,
          imageUrl: _imageUrl.text,
          registrationDeadline: _registrationDeadline.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish ? 'Event published successfully' : 'Event saved as draft',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _details(String status, int? volunteers) => {
    'name': _name.text.trim(),
    'date': _date.text.trim(),
    'start_time': '${_startTime.text.trim()}:00',
    'end_time': '${_endTime.text.trim()}:00',
    'location': _location.text.trim(),
    'area': _area.text.trim(),
    'address': _address.text.trim(),
    'category': _category.text.trim(),
    'description': _description.text.trim(),
    'volunteers_needed': volunteers,
    'required_roles': _roles.text.trim(),
    'meeting_point': _meetingPoint.text.trim(),
    'reporting_instructions': _reporting.text.trim(),
    'contact_phone': _contactPhone.text.trim(),
    'image_url': _imageUrl.text.trim(),
    'registration_deadline': _registrationDeadline.text.trim(),
    'instructions': _instructions.text.trim(),
    'status': status,
  };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: readOnly ? const Icon(Icons.arrow_drop_down) : null,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  void dispose() {
    for (final controller in [
      _name,
      _date,
      _startTime,
      _endTime,
      _location,
      _area,
      _address,
      _category,
      _description,
      _volunteers,
      _roles,
      _meetingPoint,
      _reporting,
      _contactPhone,
      _imageUrl,
      _registrationDeadline,
      _instructions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(
            _name,
            'Event name *',
            icon: Icons.event,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an event name'
                : null,
          ),
          _field(
            _description,
            'Event description',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
          _field(_category, 'Category', icon: Icons.category_outlined),
          Row(
            children: [
              Expanded(
                child: _field(
                  _date,
                  'Event date *',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () => _pickDate(_date),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Choose a date' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _startTime,
                  'Start time *',
                  icon: Icons.access_time,
                  readOnly: true,
                  onTap: () => _pickTime(_startTime),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Choose a start time'
                      : null,
                ),
              ),
            ],
          ),
          _field(
            _endTime,
            'End time *',
            icon: Icons.schedule,
            readOnly: true,
            onTap: () => _pickTime(_endTime),
            validator: (value) =>
                value == null || value.isEmpty ? 'Choose an end time' : null,
          ),
          _field(
            _location,
            'Location *',
            icon: Icons.location_on_outlined,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a location'
                : null,
          ),
          _field(_area, 'Area or pincode', icon: Icons.map_outlined),
          _field(
            _address,
            'Full address',
            icon: Icons.pin_drop_outlined,
            maxLines: 2,
          ),
          _field(
            _volunteers,
            'Number of volunteers required',
            icon: Icons.groups_outlined,
            keyboardType: TextInputType.number,
          ),
          _field(
            _roles,
            'Volunteer roles or responsibilities',
            icon: Icons.assignment_outlined,
            maxLines: 2,
          ),
          _field(_meetingPoint, 'Meeting point', icon: Icons.place_outlined),
          _field(
            _reporting,
            'Reporting instructions',
            icon: Icons.directions_outlined,
            maxLines: 2,
          ),
          _field(
            _contactPhone,
            'Event contact phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _field(
            _imageUrl,
            'Event poster image URL',
            icon: Icons.image_outlined,
            keyboardType: TextInputType.url,
          ),
          _field(
            _registrationDeadline,
            'Registration deadline',
            icon: Icons.event_available_outlined,
            readOnly: true,
            onTap: () => _pickDate(_registrationDeadline),
          ),
          _field(
            _instructions,
            'Additional instructions',
            icon: Icons.info_outline,
            maxLines: 3,
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Events must be published at least 5 full days before they begin. You can save a draft and publish it later.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _save(publish: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('SAVE DRAFT'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => _save(publish: true),
            icon: const Icon(Icons.publish_outlined),
            label: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('PUBLISH EVENT'),
          ),
        ],
      ),
    ),
  );
}
